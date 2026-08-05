/* ============================================================================
   publish.js :: vmfunc.ink
   Obsidian Publish runs this once; SPA navigation swaps the note in place without
   a reload, so everything hangs off a MutationObserver and is idempotent (guarded
   by data-plush-* flags) instead of firing on DOMContentLoaded.

   does three things:
     1. copy buttons on every code block
     2. external links open in a new tab, safely (noopener)
     3. giscus comment thread, per note, mounted under the content

   giscus: ids below are the real ones for vmfunc/vmfunc.ink-comments
   (Announcements category). threads render once the giscus app
   (github.com/apps/giscus) is installed on that repo.
   ========================================================================== */
(function () {
  "use strict";

  var GISCUS = {
    repo: "vmfunc/vmfunc.ink-comments",
    repoId: "R_kgDOTuT0WA",
    category: "Announcements",
    categoryId: "DIC_kwDOTuT0WM4DCsuS",
    // pages whose path starts with any of these get no comment thread
    mute: ["home", "welcome", "start-here", "now", "recently", "moc-"],
  };

  function enhanceCodeBlocks(root) {
    var pres = root.querySelectorAll("pre:not([data-plush-copy])");
    pres.forEach(function (pre) {
      pre.setAttribute("data-plush-copy", "1");
      var code = pre.querySelector("code");
      if (!code) return;
      var btn = document.createElement("button");
      btn.className = "plush-copy";
      btn.type = "button";
      btn.textContent = "copy";
      btn.addEventListener("click", function () {
        navigator.clipboard.writeText(code.innerText).then(function () {
          btn.textContent = "copied";
          btn.classList.add("copied");
          setTimeout(function () {
            btn.textContent = "copy";
            btn.classList.remove("copied");
          }, 1400);
        });
      });
      pre.appendChild(btn);
    });
  }

  function fixExternalLinks(root) {
    var links = root.querySelectorAll('a.external-link:not([data-plush-ext])');
    links.forEach(function (a) {
      a.setAttribute("data-plush-ext", "1");
      a.setAttribute("target", "_blank");
      a.setAttribute("rel", "noopener noreferrer");
    });
  }

  function currentSlug() {
    // Publish exposes the active file path; fall back to the URL path
    try {
      if (window.app && window.app.currentFilepath) return window.app.currentFilepath;
    } catch (e) {}
    return decodeURIComponent(location.pathname.replace(/^\/+|\/+$/g, ""));
  }

  function muted(slug) {
    var s = (slug || "").toLowerCase();
    return GISCUS.mute.some(function (p) {
      return s === p || s.indexOf("/" + p) !== -1 || s.indexOf(p) === 0;
    });
  }

  function mountGiscus(root) {
    if (GISCUS.repoId.indexOf("REPLACE") === 0) return; // not configured yet
    var container = root.querySelector(".markdown-preview-section") || root;
    if (!container || container.querySelector("#plush-comments")) return;
    var slug = currentSlug();
    if (muted(slug)) return;

    var mount = document.createElement("div");
    mount.id = "plush-comments";
    container.appendChild(mount);

    var s = document.createElement("script");
    s.src = "https://giscus.app/client.js";
    s.setAttribute("data-repo", GISCUS.repo);
    s.setAttribute("data-repo-id", GISCUS.repoId);
    s.setAttribute("data-category", GISCUS.category);
    s.setAttribute("data-category-id", GISCUS.categoryId);
    s.setAttribute("data-mapping", "pathname");
    s.setAttribute("data-strict", "1");
    s.setAttribute("data-reactions-enabled", "1");
    s.setAttribute("data-emit-metadata", "0");
    s.setAttribute("data-input-position", "top");
    s.setAttribute("data-theme", "dark_dimmed");
    s.setAttribute("data-lang", "en");
    s.crossOrigin = "anonymous";
    s.async = true;
    mount.appendChild(s);
  }

  function run() {
    var root = document.querySelector(".markdown-preview-view") || document.body;
    if (!root) return;
    enhanceCodeBlocks(root);
    fixExternalLinks(root);
    mountGiscus(root);
  }

  // initial + on every SPA note swap
  var scheduled = false;
  var obs = new MutationObserver(function () {
    if (scheduled) return;
    scheduled = true;
    setTimeout(function () {
      scheduled = false;
      run();
    }, 120);
  });
  obs.observe(document.body, { childList: true, subtree: true });
  run();
})();
