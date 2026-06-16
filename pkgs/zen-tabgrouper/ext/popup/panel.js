"use strict";

// Toolbar popup: a small control panel over the native groups. Lists group NAMES
// (not tabs) with collapse/close, plus saved groups to restore. Group rendering
// happens in Zen's own tab strip, not here.

const port = browser.runtime.connect({ name: "popup" });

const els = {
  status: document.getElementById("status"),
  groups: document.getElementById("groups"),
  saved: document.getElementById("saved"),
  savedSection: document.getElementById("saved-section"),
  savedCount: document.getElementById("saved-count"),
  reclassify: document.getElementById("reclassify"),
  settings: document.getElementById("settings"),
};

// native group color name -> a Rosé Pine-ish swatch for the popup dot
const SWATCH = {
  blue: "#9ccfd8",
  purple: "#c4a7e7",
  cyan: "#9ccfd8",
  orange: "#f6c177",
  pink: "#eb6f92",
  green: "#a3be8c",
  yellow: "#f6c177",
  red: "#eb6f92",
};

function el(tag, opts = {}, children = []) {
  const node = document.createElement(tag);
  if (opts.class) node.className = opts.class;
  if (opts.text !== undefined) node.textContent = opts.text;
  if (opts.title) node.title = opts.title;
  if (opts.style) node.setAttribute("style", opts.style);
  for (const c of children) if (c) node.appendChild(c);
  return node;
}

function send(msg) {
  try {
    port.postMessage(msg);
  } catch (err) {
    console.error("tabgrouper popup: post failed", err);
  }
}

function relTime(ts) {
  const m = Math.floor(Math.max(0, Date.now() - ts) / 60000);
  if (m < 1) return "just now";
  if (m < 60) return `${m}m ago`;
  const h = Math.floor(m / 60);
  if (h < 24) return `${h}h ago`;
  return `${Math.floor(h / 24)}d ago`;
}

function renderStatus(s) {
  els.status.classList.toggle("error", !!s.error);
  els.reclassify.classList.toggle("spinning", !!s.classifying);
  if (s.error) els.status.textContent = s.error;
  else if (s.classifying) els.status.textContent = "sorting tabs…";
  else if (s.lastClassifiedAt) els.status.textContent = `sorted ${relTime(s.lastClassifiedAt)}`;
  else els.status.textContent = "";
}

function groupRow(g) {
  const dot = el("span", { class: "dot", style: `background:${SWATCH[g.color] || "#c4a7e7"}` });
  const name = el("span", { class: "name", text: g.name });
  const count = el("span", { class: "count", text: String(g.count) });
  const collapse = el("button", { text: "⊘", title: "Collapse (free RAM, keep tabs)" });
  collapse.addEventListener("click", () => send({ type: "collapseGroup", name: g.name }));
  const close = el("button", { text: "✕", title: "Close (save + free RAM, reopen later)" });
  close.addEventListener("click", () => send({ type: "closeGroup", name: g.name }));
  return el("div", { class: "row" }, [dot, name, count, el("div", { class: "btns" }, [collapse, close])]);
}

function savedRow(g) {
  const dot = el("span", { class: "dot", style: `background:${SWATCH[g.color] || "#c4a7e7"}` });
  const name = el("span", { class: "name", text: g.name });
  const when = el("span", { class: "saved-when", text: `${g.count} · ${relTime(g.savedAt)}` });
  const restore = el("button", { text: "reopen", title: "Reopen these tabs" });
  restore.addEventListener("click", () => send({ type: "restore", savedId: g.id }));
  const del = el("button", { text: "✕", title: "Forget this saved group" });
  del.addEventListener("click", () => send({ type: "deleteSaved", savedId: g.id }));
  return el("div", { class: "row" }, [dot, name, when, el("div", { class: "btns" }, [restore, del])]);
}

function render(s) {
  renderStatus(s.status);

  els.groups.replaceChildren();
  if (s.groups.length === 0) {
    els.groups.appendChild(el("div", { class: "empty", text: "no groups yet — hit ↻ to sort" }));
  } else {
    for (const g of s.groups) els.groups.appendChild(groupRow(g));
  }

  els.saved.replaceChildren();
  if (s.saved.length) {
    els.savedSection.classList.remove("hidden");
    els.savedCount.textContent = `(${s.saved.length})`;
    for (const g of s.saved) els.saved.appendChild(savedRow(g));
  } else {
    els.savedSection.classList.add("hidden");
  }
}

port.onMessage.addListener((msg) => {
  if (msg && msg.type === "state") render(msg.state);
});

els.reclassify.addEventListener("click", () => send({ type: "reclassify" }));
els.settings.addEventListener("click", () => send({ type: "openOptions" }));

send({ type: "getState" });
