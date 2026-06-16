"use strict";

// Options write straight to storage.local; the background page reacts via
// storage.onChanged, so there's no separate message channel to keep in sync.

const KEY_SETTINGS = "settings";
const DEFAULTS = { mode: "free", seedBuckets: [], autoClassify: true, debounceMs: 2500, maxGroups: 8 };

const ui = {
  mode: document.getElementById("mode"),
  seedField: document.getElementById("seed-field"),
  seed: document.getElementById("seed"),
  auto: document.getElementById("auto"),
  debounce: document.getElementById("debounce"),
  maxgroups: document.getElementById("maxgroups"),
  save: document.getElementById("save"),
  saved: document.getElementById("saved"),
};

function syncSeedVisibility() {
  ui.seedField.classList.toggle("hidden", ui.mode.value !== "hybrid");
}

function parseBuckets(text) {
  return text
    .split(/[\n,]/)
    .map((s) => s.trim())
    .filter(Boolean)
    .slice(0, 20);
}

async function load() {
  const got = await browser.storage.local.get(KEY_SETTINGS);
  const s = { ...DEFAULTS, ...(got[KEY_SETTINGS] || {}) };
  ui.mode.value = s.mode === "hybrid" ? "hybrid" : "free";
  ui.seed.value = (Array.isArray(s.seedBuckets) ? s.seedBuckets : []).join(", ");
  ui.auto.checked = s.autoClassify !== false;
  ui.debounce.value = s.debounceMs;
  ui.maxgroups.value = s.maxGroups;
  syncSeedVisibility();
}

async function save() {
  const settings = {
    mode: ui.mode.value === "hybrid" ? "hybrid" : "free",
    seedBuckets: parseBuckets(ui.seed.value),
    autoClassify: ui.auto.checked,
    debounceMs: Math.min(60000, Math.max(500, Number(ui.debounce.value) || DEFAULTS.debounceMs)),
    maxGroups: Math.min(20, Math.max(2, Number(ui.maxgroups.value) || DEFAULTS.maxGroups)),
  };
  await browser.storage.local.set({ [KEY_SETTINGS]: settings });
  ui.saved.textContent = "saved ✓";
  setTimeout(() => (ui.saved.textContent = ""), 1500);
}

ui.mode.addEventListener("change", syncSeedVisibility);
ui.save.addEventListener("click", save);
load();
