"use strict";

// Tabgrouper background (MV2 event page). The source of truth for the tab model,
// the debounced classifier, the native-host link, and the RAM actions. The
// sidebar is a pure view: it asks for state and sends commands, nothing more.
//
// Threat model is mild but real: tab titles + URLs are attacker-controlled
// strings. We never eval them, never build DOM from them here (the sidebar
// renders via textContent), and the API key never enters this process -- the
// native host holds it and only ever receives {id,title,url} metadata.

const HOST_NAME = "re.vmfunc.tabgrouper";

// storage.local keys (one concern each, so a corrupt value can't sink the rest)
const KEY_SETTINGS = "settings";
const KEY_URL_CACHE = "urlCache"; // normalizedUrl -> groupName, the token-saver
const KEY_SAVED = "savedGroups"; // closed groups kept for restore
const KEY_COLORS = "groupColors"; // groupName -> palette hex
const KEY_COLLAPSED = "collapsed"; // [groupName] currently collapsed/discarded

const DEFAULT_SETTINGS = {
  mode: "free", // "free" = model invents names | "hybrid" = prefer seedBuckets
  seedBuckets: [],
  autoClassify: true,
  debounceMs: 2500,
  maxGroups: 8,
};

// Rosé Pine accents, cycled as groups appear. No magic literals downstream.
const PALETTE = ["#c4a7e7", "#9ccfd8", "#f6c177", "#ebbcba", "#31748f", "#eb6f92", "#a3be8c", "#f5c2e7"];

const UNGROUPED = "__ungrouped__"; // sentinel group name for not-yet-sorted tabs
const HOST_TIMEOUT_MS = 30000;
const MAX_SAVED_GROUPS = 200; // GC bound on the restore store
const RECLASSIFY_COALESCE_MS = 150; // collapse a burst of tab events into one pass

// ---------------------------------------------------------------------------
// In-memory state. Persisted slices are reloaded on startup (event page may be
// torn down and respawned, so init() is idempotent and re-reads storage).
// ---------------------------------------------------------------------------
const state = {
  tabs: new Map(), // tabId -> {id,title,url,windowId,active,discarded,favIconUrl,groupName|null}
  urlCache: Object.create(null),
  saved: [],
  colors: Object.create(null),
  collapsed: new Set(),
  settings: { ...DEFAULT_SETTINGS },
  classifying: false,
  rerunQueued: false,
  hostError: null,
  lastClassifiedAt: 0,
};

const sidebarPorts = new Set();
let hostPort = null;
let reqCounter = 0;
const pending = new Map(); // request id -> {resolve,reject,timer}
let debounceTimer = null;
let coalesceTimer = null;

// ---------------------------------------------------------------------------
// storage helpers (every read defends against undefined / wrong-type values)
// ---------------------------------------------------------------------------
async function loadState() {
  const got = await browser.storage.local.get([
    KEY_SETTINGS,
    KEY_URL_CACHE,
    KEY_SAVED,
    KEY_COLORS,
    KEY_COLLAPSED,
  ]);
  state.settings = { ...DEFAULT_SETTINGS, ...(got[KEY_SETTINGS] || {}) };
  state.urlCache = got[KEY_URL_CACHE] && typeof got[KEY_URL_CACHE] === "object" ? got[KEY_URL_CACHE] : Object.create(null);
  state.saved = Array.isArray(got[KEY_SAVED]) ? got[KEY_SAVED] : [];
  state.colors = got[KEY_COLORS] && typeof got[KEY_COLORS] === "object" ? got[KEY_COLORS] : Object.create(null);
  state.collapsed = new Set(Array.isArray(got[KEY_COLLAPSED]) ? got[KEY_COLLAPSED] : []);
}

async function persist(key, value) {
  try {
    await browser.storage.local.set({ [key]: value });
  } catch (err) {
    // quota or disk error -- surface it, never throw into an event handler
    console.error("tabgrouper: storage.set failed", key, err);
    state.hostError = `storage error: ${err && err.message ? err.message : err}`;
    broadcast();
  }
}

// ---------------------------------------------------------------------------
// URL handling. Cache key drops the fragment (and the volatile query for a few
// known noisy hosts) so the same page isn't reclassified on every #anchor jump.
// ---------------------------------------------------------------------------
function isClassifiable(url) {
  return typeof url === "string" && (url.startsWith("http://") || url.startsWith("https://"));
}

function normalizeUrl(url) {
  try {
    const u = new URL(url);
    u.hash = "";
    return u.toString();
  } catch {
    return url;
  }
}

function colorFor(name) {
  if (name === UNGROUPED) return "#6e6a86";
  if (!state.colors[name]) {
    const used = new Set(Object.values(state.colors));
    const free = PALETTE.find((c) => !used.has(c)) || PALETTE[Object.keys(state.colors).length % PALETTE.length];
    state.colors[name] = free;
    persist(KEY_COLORS, state.colors);
  }
  return state.colors[name];
}

// ---------------------------------------------------------------------------
// Tab model
// ---------------------------------------------------------------------------
function rememberTab(tab) {
  if (tab.id === undefined || tab.id === browser.tabs.TAB_ID_NONE) return;
  const prev = state.tabs.get(tab.id);
  // Assignment policy: keep the group while the URL is unchanged; on navigation
  // re-derive from the cache, and if the new URL is uncached, drop to null so the
  // classifier picks it up again (otherwise a navigated tab keeps a stale group
  // and classifyNow skips it because it "already has" one).
  let groupName;
  if (prev && prev.url === tab.url) {
    groupName = prev.groupName;
  } else if (isClassifiable(tab.url)) {
    groupName = state.urlCache[normalizeUrl(tab.url)] || null;
  } else {
    groupName = null;
  }
  state.tabs.set(tab.id, {
    id: tab.id,
    title: tab.title || tab.url || "",
    url: tab.url || "",
    windowId: tab.windowId,
    active: !!tab.active,
    discarded: !!tab.discarded,
    favIconUrl: tab.favIconUrl || "",
    groupName,
  });
}

async function refreshTabs() {
  const tabs = await browser.tabs.query({});
  state.tabs.clear();
  for (const tab of tabs) rememberTab(tab);
}

// Build the view the sidebar renders. Groups are ordered by size desc, then name.
function buildGroups() {
  const groups = new Map(); // name -> [tab,...]
  for (const tab of state.tabs.values()) {
    const name = tab.groupName || UNGROUPED;
    if (!groups.has(name)) groups.set(name, []);
    groups.get(name).push(tab);
  }
  const named = [];
  let ungrouped = [];
  for (const [name, tabs] of groups) {
    tabs.sort((a, b) => a.title.localeCompare(b.title));
    if (name === UNGROUPED) {
      ungrouped = tabs;
      continue;
    }
    named.push({ name, color: colorFor(name), collapsed: state.collapsed.has(name), tabs });
  }
  named.sort((a, b) => b.tabs.length - a.tabs.length || a.name.localeCompare(b.name));
  return { named, ungrouped };
}

function snapshot() {
  const { named, ungrouped } = buildGroups();
  return {
    groups: named,
    ungrouped,
    saved: state.saved.map((g) => ({ id: g.id, name: g.name, color: g.color, savedAt: g.savedAt, count: g.tabs.length })),
    settings: state.settings,
    status: {
      classifying: state.classifying,
      hostError: state.hostError,
      lastClassifiedAt: state.lastClassifiedAt,
    },
  };
}

function broadcast() {
  const msg = { type: "state", state: snapshot() };
  for (const port of sidebarPorts) {
    try {
      port.postMessage(msg);
    } catch {
      sidebarPorts.delete(port);
    }
  }
}

// ---------------------------------------------------------------------------
// Native host link. One persistent port; requests correlated by id so an async
// classify can't be confused with a ping. A dead host sets hostError and the
// next call transparently reconnects.
// ---------------------------------------------------------------------------
function ensureHostPort() {
  if (hostPort) return hostPort;
  try {
    hostPort = browser.runtime.connectNative(HOST_NAME);
  } catch (err) {
    state.hostError = `cannot start classifier host: ${err && err.message ? err.message : err}`;
    hostPort = null;
    return null;
  }
  hostPort.onMessage.addListener((msg) => {
    if (msg && msg.id !== undefined && pending.has(msg.id)) {
      const p = pending.get(msg.id);
      pending.delete(msg.id);
      clearTimeout(p.timer);
      p.resolve(msg);
    }
  });
  hostPort.onDisconnect.addListener(() => {
    const err = (hostPort && hostPort.error && hostPort.error.message) || "classifier host disconnected";
    hostPort = null;
    for (const [, p] of pending) {
      clearTimeout(p.timer);
      p.reject(new Error(err));
    }
    pending.clear();
  });
  return hostPort;
}

function callHost(message) {
  return new Promise((resolve, reject) => {
    const port = ensureHostPort();
    if (!port) {
      reject(new Error(state.hostError || "no host"));
      return;
    }
    const id = ++reqCounter;
    const timer = setTimeout(() => {
      pending.delete(id);
      reject(new Error("classifier host timed out"));
    }, HOST_TIMEOUT_MS);
    pending.set(id, { resolve, reject, timer });
    try {
      port.postMessage({ ...message, id });
    } catch (err) {
      clearTimeout(timer);
      pending.delete(id);
      reject(err);
    }
  });
}

// ---------------------------------------------------------------------------
// Classification
// ---------------------------------------------------------------------------
function currentGroupNames() {
  const names = new Set();
  for (const tab of state.tabs.values()) if (tab.groupName) names.add(tab.groupName);
  return [...names];
}

function scheduleClassify() {
  if (!state.settings.autoClassify) return;
  clearTimeout(debounceTimer);
  debounceTimer = setTimeout(() => classifyNow(false), state.settings.debounceMs);
}

async function classifyNow(force) {
  if (state.classifying) {
    state.rerunQueued = true;
    return;
  }
  const open = [...state.tabs.values()].filter((t) => isClassifiable(t.url));
  // Only spend tokens on tabs we have not already placed (unless forced).
  const toClassify = force ? open : open.filter((t) => !t.groupName);
  if (toClassify.length === 0) {
    broadcast();
    return;
  }

  state.classifying = true;
  state.hostError = null;
  broadcast();
  try {
    const reply = await callHost({
      type: "classify",
      mode: state.settings.mode,
      seed_buckets: state.settings.seedBuckets,
      max_groups: state.settings.maxGroups,
      current_groups: currentGroupNames(),
      tabs: toClassify.map((t) => ({ tab_id: String(t.id), title: t.title, url: t.url })),
    });
    if (reply.type === "error") throw new Error(reply.message || "classifier error");
    applyAssignments(Array.isArray(reply.assignments) ? reply.assignments : []);
    state.lastClassifiedAt = Date.now();
  } catch (err) {
    state.hostError = err && err.message ? err.message : String(err);
  } finally {
    state.classifying = false;
    broadcast();
    if (state.rerunQueued) {
      state.rerunQueued = false;
      scheduleClassify();
    }
  }
}

function applyAssignments(assignments) {
  for (const a of assignments) {
    if (!a || a.tab_id === undefined || !a.group_name) continue;
    const name = String(a.group_name).trim().slice(0, 40);
    if (!name) continue;
    const id = Number(a.tab_id);
    const tab = state.tabs.get(id);
    if (!tab || !isClassifiable(tab.url)) continue;
    tab.groupName = name;
    state.urlCache[normalizeUrl(tab.url)] = name;
    colorFor(name);
  }
  persist(KEY_URL_CACHE, state.urlCache);
}

// ---------------------------------------------------------------------------
// RAM actions
// ---------------------------------------------------------------------------
function membersOf(groupName) {
  return [...state.tabs.values()].filter((t) => t.groupName === groupName);
}

// COLLAPSE (the default lightweight action): unload the group's tabs to free
// memory but keep them in the strip. The active tab can't be discarded; it is
// skipped and the rest still unload.
async function collapseGroup(groupName) {
  const members = membersOf(groupName);
  const ids = members.filter((t) => !t.active).map((t) => t.id);
  state.collapsed.add(groupName);
  await persist(KEY_COLLAPSED, [...state.collapsed]);
  if (ids.length) {
    try {
      await browser.tabs.discard(ids);
    } catch (err) {
      console.error("tabgrouper: discard failed", err);
    }
  }
  await refreshTabs();
  broadcast();
}

async function expandGroup(groupName) {
  state.collapsed.delete(groupName);
  await persist(KEY_COLLAPSED, [...state.collapsed]);
  broadcast();
}

// CLOSE (fully free RAM + keep for later): persist the URL list BEFORE removing
// any tab. Zen's window-sync can scramble/lose tabs mid-operation, so a save
// that lands after the remove would be unrecoverable. Persist first, always.
async function closeGroup(groupName) {
  const members = membersOf(groupName);
  if (members.length === 0) return;
  const record = {
    id: crypto.randomUUID(),
    name: groupName,
    color: colorFor(groupName),
    savedAt: Date.now(),
    tabs: members.map((t) => ({ title: t.title, url: t.url })),
  };
  state.saved.unshift(record);
  if (state.saved.length > MAX_SAVED_GROUPS) state.saved.length = MAX_SAVED_GROUPS;
  await persist(KEY_SAVED, state.saved); // <-- invariant: save before remove
  state.collapsed.delete(groupName);
  await persist(KEY_COLLAPSED, [...state.collapsed]);
  try {
    await browser.tabs.remove(members.map((t) => t.id));
  } catch (err) {
    console.error("tabgrouper: remove failed", err);
  }
  await refreshTabs();
  broadcast();
}

// RESTORE: recreate the tabs as already-discarded so reopening 20 tabs doesn't
// stampede 20 page loads. They reload lazily when the user clicks one.
async function restoreSaved(savedId) {
  const idx = state.saved.findIndex((g) => g.id === savedId);
  if (idx < 0) return;
  const record = state.saved[idx];
  for (const t of record.tabs) {
    if (!isClassifiable(t.url)) continue;
    try {
      const created = await browser.tabs.create({ url: t.url, discarded: true, active: false });
      state.urlCache[normalizeUrl(t.url)] = record.name;
      if (created && created.id !== undefined) {
        rememberTab({ ...created, title: t.title });
        const tab = state.tabs.get(created.id);
        if (tab) tab.groupName = record.name;
      }
    } catch (err) {
      // Gecko may reject discarded-create; fall back to a background, then unload.
      try {
        const created = await browser.tabs.create({ url: t.url, active: false });
        if (created && created.id !== undefined) {
          await browser.tabs.discard(created.id);
          state.urlCache[normalizeUrl(t.url)] = record.name;
          rememberTab({ ...created, title: t.title });
          const tab = state.tabs.get(created.id);
          if (tab) tab.groupName = record.name;
        }
      } catch (err2) {
        console.error("tabgrouper: restore create failed", err2);
      }
    }
  }
  colorFor(record.name);
  state.saved.splice(idx, 1);
  await persist(KEY_SAVED, state.saved);
  await persist(KEY_URL_CACHE, state.urlCache);
  await refreshTabs();
  broadcast();
}

async function deleteSaved(savedId) {
  const before = state.saved.length;
  state.saved = state.saved.filter((g) => g.id !== savedId);
  if (state.saved.length !== before) await persist(KEY_SAVED, state.saved);
  broadcast();
}

// ---------------------------------------------------------------------------
// Settings
// ---------------------------------------------------------------------------
async function setSettings(next) {
  state.settings = { ...state.settings, ...next };
  // sanitize the numbers; hostile/garbled values shouldn't wedge the debouncer
  state.settings.debounceMs = Math.min(60000, Math.max(500, Number(state.settings.debounceMs) || DEFAULT_SETTINGS.debounceMs));
  state.settings.maxGroups = Math.min(20, Math.max(2, Number(state.settings.maxGroups) || DEFAULT_SETTINGS.maxGroups));
  if (!Array.isArray(state.settings.seedBuckets)) state.settings.seedBuckets = [];
  if (state.settings.mode !== "hybrid") state.settings.mode = "free";
  await persist(KEY_SETTINGS, state.settings);
  broadcast();
}

// ---------------------------------------------------------------------------
// Event wiring
// ---------------------------------------------------------------------------
function onTabChanged() {
  clearTimeout(coalesceTimer);
  coalesceTimer = setTimeout(async () => {
    await refreshTabs();
    broadcast();
    scheduleClassify();
  }, RECLASSIFY_COALESCE_MS);
}

browser.tabs.onCreated.addListener(onTabChanged);
browser.tabs.onRemoved.addListener(onTabChanged);
browser.tabs.onAttached.addListener(onTabChanged);
browser.tabs.onDetached.addListener(onTabChanged);
browser.tabs.onActivated.addListener(onTabChanged);
browser.tabs.onUpdated.addListener((tabId, changeInfo) => {
  // Only react to changes that affect classification or the view.
  if (changeInfo.url || changeInfo.title || changeInfo.status === "complete" || changeInfo.discarded !== undefined || changeInfo.favIconUrl) {
    onTabChanged();
  }
});

browser.runtime.onConnect.addListener((port) => {
  if (port.name !== "sidebar") return;
  sidebarPorts.add(port);
  port.onMessage.addListener((msg) => handleSidebarMessage(msg));
  port.onDisconnect.addListener(() => sidebarPorts.delete(port));
  port.postMessage({ type: "state", state: snapshot() });
});

async function handleSidebarMessage(msg) {
  if (!msg || !msg.type) return;
  switch (msg.type) {
    case "getState":
      broadcast();
      break;
    case "reclassify":
      classifyNow(true);
      break;
    case "collapseGroup":
      await collapseGroup(msg.name);
      break;
    case "expandGroup":
      await expandGroup(msg.name);
      break;
    case "closeGroup":
      await closeGroup(msg.name);
      break;
    case "restore":
      await restoreSaved(msg.savedId);
      break;
    case "deleteSaved":
      await deleteSaved(msg.savedId);
      break;
    case "activateTab":
      try {
        const tab = state.tabs.get(Number(msg.tabId));
        if (tab) {
          await browser.tabs.update(tab.id, { active: true });
          await browser.windows.update(tab.windowId, { focused: true });
        }
      } catch (err) {
        console.error("tabgrouper: activate failed", err);
      }
      break;
    case "setSettings":
      await setSettings(msg.settings || {});
      break;
    default:
      break;
  }
}

// React to settings edited from the options page (separate context).
browser.storage.onChanged.addListener((changes, area) => {
  if (area === "local" && changes[KEY_SETTINGS]) {
    state.settings = { ...DEFAULT_SETTINGS, ...(changes[KEY_SETTINGS].newValue || {}) };
    broadcast();
  }
});

// ---------------------------------------------------------------------------
// Startup
// ---------------------------------------------------------------------------
async function init() {
  await loadState();
  await refreshTabs();
  broadcast();
  // Probe the host early so the sidebar can show "classifier offline" honestly.
  try {
    const pong = await callHost({ type: "ping" });
    if (pong && pong.type === "pong" && pong.has_key === false) {
      state.hostError = "classifier host has no API key (sops secret not deployed?)";
    }
  } catch (err) {
    state.hostError = err && err.message ? err.message : String(err);
  }
  broadcast();
  if (state.settings.autoClassify) classifyNow(false);
}

init();
