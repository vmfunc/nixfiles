# zen-tabgrouper

Claude sorts your open Zen tabs into named groups, live, as you browse. Then you
collapse a group (discard its tabs, free RAM, keep them in the strip) or close it
(save the URL list, free RAM fully, reopen later from the toolbar popup).

## Why it's shaped this way

Three findings from the research pass drive the design (see the design brief in
the workflow run; all adversarially verified):

- **Zen ships tab groups off** (`browser.tabs.groups.enabled=false`, the native
  machinery repurposed for pinned "folders"), but the pref re-enables cleanly. →
  the nix module drops a `user.js` that flips it back on, and groups render as
  Zen's **own native groups in the real (vertical) tab strip** via
  `browser.tabs.group()` + `browser.tabGroups.update()`. if the API is inert the
  background page surfaces that in the status instead of silently no-op'ing.
- **Native-messaging host dir is the Mozilla vendor dir**, not a `zen` one, even
  though `RemotingName=zen` (Gecko `nsXREDirProvider` hardcodes the vendor
  literal). macOS `~/Library/Application Support/Mozilla/NativeMessagingHosts/`,
  Linux `~/.mozilla/native-messaging-hosts/`.
- **Zen enforces extension signing** (compiled-in `MOZ_REQUIRE_SIGNING`; the
  `about:config` toggle is inert). Unsigned loads only temporarily (web-ext /
  about:debugging). Permanent install needs a `web-ext sign --channel unlisted`
  XPI.

## Components

| Piece | What it is |
|---|---|
| `ext/` | the MV2 event-page extension. `background.js` is the source of truth (tab model, debounced classifier, native-host link, RAM actions) and materialises groups natively in the tab strip; the toolbar popup (`popup/`) is a small control panel (reclassify / collapse / close / restore), not a tab list. |
| `host/tabgrouper_host.py` | python-stdlib native-messaging host. **Holds the API key** (read from a file) and makes the Claude Haiku call. The browser only ever sends `{id,title,url}` and gets back `{id,group}`. |
| `package.nix` | builds the unsigned `.xpi`, exposes `passthru.host` (key-holding wrapper), `passthru.extDir` (for web-ext), and the `geckoId`/`hostName`. |
| `../../home/modules/desktop/zen-tabgrouper.nix` | the home-manager module: sops key → 0600 path, native-messaging manifest → Mozilla dir, host launcher, dev tooling, optional signed-XPI sideload. Cross-platform (darwin + NixOS). |

Key never enters the browser. Model `claude-haiku-4-5-20251001`, forced
`assign_groups` tool for clean JSON. ~$0.004 per ~20-tab classify; debounced +
url-cached so it doesn't reclassify or burn tokens.

## Go-live checklist

1. **Real API key into sops** (replaces the placeholder):
   ```
   sops secrets/anthropic.yaml      # set anthropic-api-key: sk-ant-...
   ```
2. **Load it in Zen (the empirical preflight, M0).** No signing needed:
   ```
   zen-tabgrouper-dev               # web-ext run against /Applications/Zen.app, hot-reloads ext/
   ```
   or in Zen: `about:debugging` → This Zen → Load Temporary Add-on → pick
   `ext/manifest.json`. Confirm: the toolbar popup opens, its status line isn't
   "classifier offline" (→ native messaging resolved), and hitting ↻ produces
   named groups in the tab strip (→ live Haiku classify works; needs the module's
   `user.js` pref, a bare temporary load leaves the groups API inert).
3. **Permanent declarative install** (once you have AMO signing creds):
   ```
   web-ext sign --channel unlisted --source-dir ext \
     --api-key $AMO_JWT_ISSUER --api-secret $AMO_JWT_SECRET
   ```
   then point the module at the signed XPI + your profile:
   ```nix
   rice.zenTabgrouper.signedXpi   = ./tabgrouper@vmfunc.re.xpi;   # or a store path
   rice.zenTabgrouper.profilePath = "Library/Application Support/zen/Profiles/c6bgtaur.Default (release)";
   ```
4. `darwin-rebuild switch` (gated on the App Management TCC grant) lands the
   manifest, the key, and the dev tools, once `rice.zenTabgrouper.enable` is back
   on for the macs. it is currently `false` there (`home/profiles/desktop-darwin.nix`):
   the dev build's background page repaints the GPU while idle, so it stays off
   until packaged as a signed XPI.

## Verifying the native-messaging path on the live machine

If the sidebar says the host won't start:
```
ls -l ~/Library/Application\ Support/Mozilla/NativeMessagingHosts/re.vmfunc.tabgrouper.json
sudo fs_usage -w -f filesys | grep -i NativeMessagingHosts   # watch which dir Zen actually stats
```
The manifest `name`, its filename stem, and the extension's `connectNative()`
arg must all be byte-identical: `re.vmfunc.tabgrouper`.

## Settings

Sidebar ⚙ → grouping mode (**free** = Claude invents names, default; **hybrid** =
prefer your seed buckets, add new when needed), auto-classify toggle, debounce,
max groups.
