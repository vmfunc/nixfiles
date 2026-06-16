"use strict";

// Pure view. Receives state snapshots over the "sidebar" port and renders them;
// sends commands back. Every piece of tab-supplied text goes in via textContent,
// never innerHTML -- titles and URLs are attacker-controlled.

const port = browser.runtime.connect({ name: "sidebar" });

const els = {
  status: document.getElementById("status"),
  groups: document.getElementById("groups"),
  saved: document.getElementById("saved"),
  savedSection: document.getElementById("saved-section"),
  savedCount: document.getElementById("saved-count"),
  reclassify: document.getElementById("reclassify"),
  settings: document.getElementById("settings"),
};

function el(tag, opts = {}, children = []) {
  const node = document.createElement(tag);
  if (opts.class) node.className = opts.class;
  if (opts.text !== undefined) node.textContent = opts.text;
  if (opts.title) node.title = opts.title;
  if (opts.style) node.setAttribute("style", opts.style);
  for (const child of children) if (child) node.appendChild(child);
  return node;
}

function send(msg) {
  try {
    port.postMessage(msg);
  } catch (err) {
    console.error("tabgrouper sidebar: post failed", err);
  }
}

function relTime(ts) {
  const d = Math.max(0, Date.now() - ts);
  const m = Math.floor(d / 60000);
  if (m < 1) return "just now";
  if (m < 60) return `${m}m ago`;
  const h = Math.floor(m / 60);
  if (h < 24) return `${h}h ago`;
  return `${Math.floor(h / 24)}d ago`;
}

function renderStatus(status) {
  els.status.classList.toggle("error", !!status.hostError);
  els.reclassify.classList.toggle("spinning", !!status.classifying);
  if (status.hostError) {
    els.status.textContent = status.hostError;
  } else if (status.classifying) {
    els.status.textContent = "sorting tabs…";
  } else if (status.lastClassifiedAt) {
    els.status.textContent = `sorted ${relTime(status.lastClassifiedAt)}`;
  } else {
    els.status.textContent = "";
  }
}

function tabRow(tab) {
  const fav = el("img", { class: "favicon" });
  if (tab.favIconUrl) {
    fav.src = tab.favIconUrl;
    fav.addEventListener("error", () => (fav.style.visibility = "hidden"));
  } else {
    fav.style.visibility = "hidden";
  }
  const row = el(
    "div",
    { class: "tab" + (tab.active ? " active" : "") + (tab.discarded ? " discarded" : ""), title: tab.url },
    [fav, el("span", { class: "tab-title", text: tab.title || tab.url })]
  );
  row.addEventListener("click", () => send({ type: "activateTab", tabId: tab.id }));
  return row;
}

function groupBlock(group) {
  const chevron = el("span", { class: "chevron", text: "▼" });
  const dot = el("span", { class: "dot", style: `background:${group.color}` });
  const name = el("span", { class: "group-name", text: group.name });
  const count = el("span", { class: "count", text: String(group.tabs.length) });

  const collapseBtn = el("button", {
    text: group.collapsed ? "⊕" : "⊘",
    title: group.collapsed ? "Expand" : "Collapse (free RAM, keep tabs)",
  });
  collapseBtn.addEventListener("click", (e) => {
    e.stopPropagation();
    send({ type: group.collapsed ? "expandGroup" : "collapseGroup", name: group.name });
  });

  const closeBtn = el("button", { text: "✕", title: "Close group (save + free RAM, reopen later)" });
  closeBtn.addEventListener("click", (e) => {
    e.stopPropagation();
    send({ type: "closeGroup", name: group.name });
  });

  const header = el("div", { class: "group-header" }, [
    chevron,
    dot,
    name,
    count,
    el("div", { class: "group-actions" }, [collapseBtn, closeBtn]),
  ]);
  header.addEventListener("click", () =>
    send({ type: group.collapsed ? "expandGroup" : "collapseGroup", name: group.name })
  );

  const list = el("div", { class: "tablist" }, group.tabs.map(tabRow));
  return el("div", { class: "group" + (group.collapsed ? " collapsed" : "") }, [header, list]);
}

function ungroupedBlock(tabs) {
  const header = el("div", { class: "group-header" }, [
    el("span", { class: "chevron", text: "▼" }),
    el("span", { class: "dot", style: "background:#6e6a86" }),
    el("span", { class: "group-name muted", text: "ungrouped" }),
    el("span", { class: "count", text: String(tabs.length) }),
  ]);
  const list = el("div", { class: "tablist" }, tabs.map(tabRow));
  return el("div", { class: "group" }, [header, list]);
}

function savedItem(g) {
  const dot = el("span", { class: "dot", style: `background:${g.color}` });
  const name = el("span", { class: "group-name", text: g.name });
  const when = el("span", { class: "saved-when", text: `${g.count} · ${relTime(g.savedAt)}` });
  const restore = el("button", { text: "reopen", title: "Reopen these tabs" });
  restore.addEventListener("click", () => send({ type: "restore", savedId: g.id }));
  const del = el("button", { text: "✕", title: "Forget this saved group" });
  del.addEventListener("click", () => send({ type: "deleteSaved", savedId: g.id }));
  return el("div", { class: "saved-item" }, [
    dot,
    name,
    when,
    el("div", { class: "group-actions" }, [restore, del]),
  ]);
}

function render(s) {
  renderStatus(s.status);

  els.groups.replaceChildren();
  if (s.groups.length === 0 && s.ungrouped.length === 0) {
    els.groups.appendChild(el("div", { class: "empty", text: "no tabs yet" }));
  } else {
    for (const g of s.groups) els.groups.appendChild(groupBlock(g));
    if (s.ungrouped.length) els.groups.appendChild(ungroupedBlock(s.ungrouped));
  }

  els.saved.replaceChildren();
  if (s.saved.length) {
    els.savedSection.classList.remove("hidden");
    els.savedCount.textContent = `(${s.saved.length})`;
    for (const g of s.saved) els.saved.appendChild(savedItem(g));
  } else {
    els.savedSection.classList.add("hidden");
  }
}

port.onMessage.addListener((msg) => {
  if (msg && msg.type === "state") render(msg.state);
});

els.reclassify.addEventListener("click", () => send({ type: "reclassify" }));
els.settings.addEventListener("click", () => browser.runtime.openOptionsPage());

send({ type: "getState" });
