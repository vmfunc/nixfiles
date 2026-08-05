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

  // how long a mount may sit iframe-less before we call it dead and rebuild.
  // client.js loads async, so a freshly-born mount legitimately has no iframe
  // for a moment; rebuilding sooner would thrash and never let it finish.
  var GISCUS_SETTLE_MS = 4000;

  function mountGiscus(root) {
    if (GISCUS.repoId.indexOf("REPLACE") === 0) return; // not configured yet
    var slug = currentSlug();
    var mount = document.getElementById("plush-comments");

    // self-heal: Publish re-renders the note content and can detach the iframe
    // client.js already built. rebuild when the note changed, or when a settled
    // mount lost (or never grew) its iframe. the label alone is not a thread.
    if (mount) {
      var stale = mount.getAttribute("data-slug") !== slug;
      var dead =
        !mount.querySelector("iframe") &&
        Date.now() - Number(mount.getAttribute("data-born")) > GISCUS_SETTLE_MS;
      if (!stale && !dead) return;
      mount.remove();
    }
    if (muted(slug)) return;

    mount = document.createElement("div");
    mount.id = "plush-comments";
    mount.setAttribute("data-slug", slug);
    mount.setAttribute("data-born", String(Date.now()));

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

    // append to the preview view itself, AFTER the section Publish re-renders,
    // so a content swap does not take the thread down with it.
    root.appendChild(mount);
  }

  // the github sign-in returns to this page with ?giscus=<token>, and client.js
  // only reads it at its own execution time. Publish's router rewrites the url
  // when it boots, so by then the token can be gone and sign-in loops forever.
  // catch it ourselves, exactly as client.js would: stash the session, clean the
  // url, and drop any already-signed-out mount so it rebuilds with the session.
  function captureGiscusSession() {
    var url;
    try {
      url = new URL(location.href);
    } catch (e) {
      return;
    }
    var token = url.searchParams.get("giscus");
    if (!token) return;
    try {
      localStorage.setItem("giscus-session", JSON.stringify(token));
    } catch (e) {}
    url.searchParams.delete("giscus");
    url.hash = "";
    history.replaceState(void 0, document.title, url.toString());
    var mount = document.getElementById("plush-comments");
    if (mount) mount.remove();
  }

  function run() {
    var root = document.querySelector(".markdown-preview-view") || document.body;
    if (!root) return;
    captureGiscusSession();
    enhanceCodeBlocks(root);
    fixExternalLinks(root);
    mountGiscus(root);
  }

  // grab the oauth return token at parse time, before Publish's router can
  // rewrite the url out from under us; run() re-checks on every dom tick too.
  captureGiscusSession();

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
