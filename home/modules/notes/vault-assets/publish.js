/* ============================================================================
   publish.js :: vmfunc.ink
   Obsidian Publish runs this once; SPA navigation swaps the note in place without
   a reload, so everything hangs off a MutationObserver and is idempotent (guarded
   by data-plush-* flags) instead of firing on DOMContentLoaded.

   what it does:
     1. copy buttons on every code block
     2. external links open in a new tab, safely (noopener)
     3. giscus comment thread, per note, mounted under the content
     4. global fuzzy search (ctrl/cmd+K, "/", or the floating button) over the
        site's own metadata cache: titles, headings, tags, aliases, paths
     5. reading progress bar + back-to-top
     6. image lightbox (click any content image)
     7. copyable anchor links on headings

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

  /* ------------------------------------------------------------ search ---- */
  // the index comes from the site's own metadata cache (the endpoint the graph
  // uses). it lists only PUBLISHED notes and needs the visitor's password
  // cookie, so search exposes nothing the visitor can't already read.
  var SEARCH = { index: null, state: "idle", results: [], sel: 0 };

  function cacheUrl() {
    var si = window.siteInfo || {};
    if (!si.uid || !si.host) return null;
    return "https://" + si.host + "/cache/" + si.uid;
  }

  function normalizeCache(json) {
    // shape-liberal: the cache maps "path.md" -> app-style metadata, but keep
    // working if it ever arrives wrapped or slightly different
    var files = json && typeof json === "object" ? json : {};
    if (files.cache && typeof files.cache === "object") files = files.cache;
    var out = [];
    Object.keys(files).forEach(function (path) {
      if (!/\.md$/i.test(path)) return;
      var meta = files[path] || {};
      var fm = meta.frontmatter || {};
      var slug = path.replace(/\.md$/i, "");
      var tags = []
        .concat(meta.tags || [])
        .map(function (t) {
          return typeof t === "string" ? t : t && t.tag;
        })
        .concat(typeof fm.tags === "string" ? fm.tags.split(/[,\s]+/) : fm.tags || [])
        .filter(Boolean)
        .map(function (t) {
          return String(t).replace(/^#/, "").toLowerCase();
        });
      var aliases = (typeof fm.aliases === "string" ? [fm.aliases] : fm.aliases || []).map(String);
      var headings = (meta.headings || [])
        .map(function (h) {
          return typeof h === "string" ? h : h && h.heading;
        })
        .filter(Boolean);
      out.push({
        slug: slug,
        title: slug.split("/").pop(),
        folder: slug.indexOf("/") !== -1 ? slug.slice(0, slug.lastIndexOf("/")) : "",
        headings: headings,
        tags: tags,
        aliases: aliases,
      });
    });
    return out;
  }

  function loadSearchIndex(then) {
    if (SEARCH.index || SEARCH.state === "loading") return;
    var url = cacheUrl();
    if (!url) {
      SEARCH.state = "unavailable";
      then();
      return;
    }
    SEARCH.state = "loading";
    fetch(url, { credentials: "include" })
      .then(function (r) {
        if (!r.ok) throw new Error("cache " + r.status);
        return r.json();
      })
      .then(function (json) {
        SEARCH.index = normalizeCache(json);
        SEARCH.state = "ready";
        then();
      })
      .catch(function () {
        SEARCH.state = "unavailable";
        then();
      });
  }

  function scoreText(q, text) {
    if (!text) return 0;
    var t = String(text).toLowerCase();
    if (t === q) return 100;
    if (t.indexOf(q) === 0) return 80;
    if (t.indexOf(q) !== -1) return 60;
    var i = 0;
    for (var c = 0; c < t.length && i < q.length; c++) if (t[c] === q[i]) i++;
    return i === q.length ? 30 : 0;
  }

  function searchQuery(query) {
    var q = query.trim().toLowerCase();
    if (!q || !SEARCH.index) return [];
    var scored = [];
    SEARCH.index.forEach(function (e) {
      var s = scoreText(q, e.title);
      var heading = null;
      e.aliases.forEach(function (a) {
        s = Math.max(s, scoreText(q, a) * 0.95);
      });
      e.tags.forEach(function (t) {
        s = Math.max(s, scoreText(q, t) * 0.8);
      });
      e.headings.forEach(function (h) {
        var hs = scoreText(q, h) * 0.7;
        if (hs > s) {
          s = hs;
          heading = h;
        }
      });
      s = Math.max(s, scoreText(q, e.slug) * 0.5);
      if (s > 0) scored.push({ e: e, s: s, heading: heading });
    });
    scored.sort(function (a, b) {
      return b.s - a.s || a.e.slug.localeCompare(b.e.slug);
    });
    return scored.slice(0, 20);
  }

  function navigateTo(slug, heading) {
    // absolute against the real origin: the Publish shell carries
    // <base href="https://publish.obsidian.md">, so a relative href would
    // resolve onto that host and 404
    var href = location.origin + "/" + slug.split("/").map(encodeURIComponent).join("/");
    if (heading) href += "#" + encodeURIComponent(heading);
    // synthesize a real anchor click so Publish's SPA router handles it; if it
    // doesn't, the browser just navigates, which is equally correct
    var a = document.createElement("a");
    a.href = href;
    a.style.display = "none";
    document.body.appendChild(a);
    a.click();
    a.remove();
  }

  function buildSearchUi() {
    var overlay = document.createElement("div");
    overlay.id = "plush-search";
    overlay.setAttribute("hidden", "");
    overlay.innerHTML =
      '<div class="plush-search-panel" role="dialog" aria-label="site search">' +
      '<input class="plush-search-input" type="text" placeholder="search the wired..." ' +
      'autocomplete="off" autocorrect="off" autocapitalize="off" spellcheck="false">' +
      '<ul class="plush-search-results"></ul>' +
      '<div class="plush-search-foot">' +
      "<span><kbd>↑↓</kbd> move</span><span><kbd>↵</kbd> open</span>" +
      "<span><kbd>⇧↵</kbd> random</span><span><kbd>esc</kbd> close</span>" +
      "</div></div>";
    document.body.appendChild(overlay);

    var input = overlay.querySelector(".plush-search-input");
    var list = overlay.querySelector(".plush-search-results");

    function close() {
      overlay.setAttribute("hidden", "");
    }

    function render() {
      if (SEARCH.state === "loading") {
        list.innerHTML = '<li class="plush-search-empty">warming up…</li>';
        return;
      }
      if (SEARCH.state === "unavailable") {
        list.innerHTML = '<li class="plush-search-empty">search is unavailable right now</li>';
        return;
      }
      if (!input.value.trim()) {
        list.innerHTML = '<li class="plush-search-empty">type to search notes, headings, tags…</li>';
        return;
      }
      if (!SEARCH.results.length) {
        list.innerHTML = '<li class="plush-search-empty">nothing in the wired for that</li>';
        return;
      }
      list.innerHTML = "";
      SEARCH.results.forEach(function (r, i) {
        var li = document.createElement("li");
        li.className = "plush-search-hit" + (i === SEARCH.sel ? " selected" : "");
        var title = document.createElement("b");
        title.textContent = r.e.title;
        li.appendChild(title);
        if (r.heading) {
          var h = document.createElement("span");
          h.className = "hit-heading";
          h.textContent = "→ " + r.heading;
          li.appendChild(h);
        }
        var path = document.createElement("small");
        path.textContent = r.e.folder || "/";
        li.appendChild(path);
        li.addEventListener("mouseenter", function () {
          SEARCH.sel = i;
          render();
        });
        li.addEventListener("click", function () {
          close();
          navigateTo(r.e.slug, r.heading);
        });
        list.appendChild(li);
      });
      var selected = list.querySelector(".selected");
      if (selected && selected.scrollIntoView) selected.scrollIntoView({ block: "nearest" });
    }

    function refresh() {
      SEARCH.results = searchQuery(input.value);
      if (SEARCH.sel >= SEARCH.results.length) SEARCH.sel = 0;
      render();
    }

    function openRandom() {
      if (!SEARCH.index || !SEARCH.index.length) return;
      var pick = SEARCH.index[Math.floor(Math.random() * SEARCH.index.length)];
      close();
      navigateTo(pick.slug, null);
    }

    input.addEventListener("input", function () {
      SEARCH.sel = 0;
      refresh();
    });
    input.addEventListener("keydown", function (ev) {
      if (ev.key === "ArrowDown") {
        ev.preventDefault();
        SEARCH.sel = Math.min(SEARCH.sel + 1, SEARCH.results.length - 1);
        render();
      } else if (ev.key === "ArrowUp") {
        ev.preventDefault();
        SEARCH.sel = Math.max(SEARCH.sel - 1, 0);
        render();
      } else if (ev.key === "Enter" && ev.shiftKey) {
        ev.preventDefault();
        openRandom();
      } else if (ev.key === "Enter") {
        ev.preventDefault();
        var r = SEARCH.results[SEARCH.sel];
        if (r) {
          close();
          navigateTo(r.e.slug, r.heading);
        }
      }
    });
    overlay.addEventListener("mousedown", function (ev) {
      if (ev.target === overlay) close();
    });

    return {
      open: function () {
        overlay.removeAttribute("hidden");
        input.focus();
        input.select();
        loadSearchIndex(refresh);
        refresh();
      },
      close: close,
      isOpen: function () {
        return !overlay.hasAttribute("hidden");
      },
    };
  }

  function isTypingTarget(el) {
    if (!el) return false;
    if (el.isContentEditable) return true;
    var tag = (el.tagName || "").toLowerCase();
    return tag === "input" || tag === "textarea" || tag === "select";
  }

  function initSearch() {
    var ui = buildSearchUi();

    document.addEventListener("keydown", function (ev) {
      if (ev.key === "Escape" && ui.isOpen()) {
        ev.preventDefault();
        ui.close();
        return;
      }
      var hotkey =
        ((ev.ctrlKey || ev.metaKey) && !ev.shiftKey && !ev.altKey && (ev.key || "").toLowerCase() === "k") ||
        (ev.key === "/" && !ev.ctrlKey && !ev.metaKey && !ev.altKey && !isTypingTarget(ev.target));
      if (hotkey && !ui.isOpen()) {
        ev.preventDefault();
        ui.open();
      }
    });

    var fab = document.createElement("button");
    fab.className = "plush-fab plush-fab-search";
    fab.type = "button";
    fab.title = "search (ctrl+k)";
    fab.textContent = "⌕";
    fab.addEventListener("click", ui.open);
    fabStack().appendChild(fab);
  }

  /* ------------------------------------------- scroll ux + lightbox ---- */
  var fabStackEl = null;
  function fabStack() {
    if (!fabStackEl) {
      fabStackEl = document.createElement("div");
      fabStackEl.className = "plush-fab-stack";
      document.body.appendChild(fabStackEl);
    }
    return fabStackEl;
  }

  // one capture-phase scroll handler feeds both the progress bar and the
  // back-to-top button; Publish scrolls an inner container, not the window
  var SCROLL_TOP_SHOW_PX = 600;

  function scroller() {
    return document.querySelector(".markdown-preview-view") || document.scrollingElement;
  }

  function initScrollUx() {
    var bar = document.createElement("div");
    bar.id = "plush-progress";
    document.body.appendChild(bar);

    var top = document.createElement("button");
    top.className = "plush-fab plush-fab-top";
    top.type = "button";
    top.title = "back to top";
    top.textContent = "↑";
    top.setAttribute("hidden", "");
    top.addEventListener("click", function () {
      var el = scroller();
      if (el && el.scrollTo) el.scrollTo({ top: 0, behavior: "smooth" });
      window.scrollTo({ top: 0, behavior: "smooth" });
    });
    fabStack().appendChild(top);

    var pending = false;
    function update() {
      pending = false;
      var el = scroller();
      if (!el) return;
      var max = el.scrollHeight - el.clientHeight;
      var y = el.scrollTop || 0;
      bar.style.width = max > 0 ? Math.min(100, (y / max) * 100) + "%" : "0";
      if (y > SCROLL_TOP_SHOW_PX) top.removeAttribute("hidden");
      else top.setAttribute("hidden", "");
    }
    function onScroll() {
      if (pending) return;
      pending = true;
      requestAnimationFrame(update);
    }
    document.addEventListener("scroll", onScroll, { capture: true, passive: true });
    window.addEventListener("resize", onScroll);
  }

  function initLightbox() {
    var overlay = document.createElement("div");
    overlay.id = "plush-lightbox";
    overlay.setAttribute("hidden", "");
    var img = document.createElement("img");
    overlay.appendChild(img);
    document.body.appendChild(overlay);

    function close() {
      overlay.setAttribute("hidden", "");
      img.src = "";
    }
    overlay.addEventListener("click", close);
    document.addEventListener("keydown", function (ev) {
      if (ev.key === "Escape" && !overlay.hasAttribute("hidden")) {
        ev.preventDefault();
        close();
      }
    });
    document.addEventListener("click", function (ev) {
      var t = ev.target;
      if (!(t instanceof HTMLImageElement)) return;
      if (!t.closest(".markdown-preview-view")) return;
      if (t.closest("a") || t.closest("#plush-lightbox")) return;
      ev.preventDefault();
      img.src = t.currentSrc || t.src;
      img.alt = t.alt || "";
      overlay.removeAttribute("hidden");
    });
  }

  function enhanceHeadings(root) {
    var hs = root.querySelectorAll(
      ".markdown-preview-section h1:not([data-plush-anchor]), .markdown-preview-section h2:not([data-plush-anchor]), .markdown-preview-section h3:not([data-plush-anchor]), .markdown-preview-section h4:not([data-plush-anchor]), .markdown-preview-section h5:not([data-plush-anchor]), .markdown-preview-section h6:not([data-plush-anchor])",
    );
    hs.forEach(function (h) {
      h.setAttribute("data-plush-anchor", "1");
      var text = h.textContent.trim();
      var btn = document.createElement("button");
      btn.className = "plush-anchor";
      btn.type = "button";
      btn.title = "copy link to this heading";
      btn.textContent = "⟢";
      btn.addEventListener("click", function () {
        var url = location.origin + location.pathname + "#" + encodeURIComponent(text);
        navigator.clipboard.writeText(url).then(function () {
          btn.classList.add("copied");
          setTimeout(function () {
            btn.classList.remove("copied");
          }, 1200);
        });
      });
      h.appendChild(btn);
    });
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
    enhanceHeadings(root);
    mountGiscus(root);
  }

  // grab the oauth return token at parse time, before Publish's router can
  // rewrite the url out from under us; run() re-checks on every dom tick too.
  captureGiscusSession();

  // singletons: built once per page load, never per SPA swap
  initSearch();
  initScrollUx();
  initLightbox();

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
