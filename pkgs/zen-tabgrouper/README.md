# zen-tabgrouper

Claude sorts your open Zen tabs into named groups, live, as you browse. Then you
collapse a group (discard its tabs, free RAM, keep them in the strip) or close it
(save the URL list, free RAM fully, reopen later from the sidebar).

## Why it's shaped this way

Three findings from the research pass drive the design (see the design brief in
the workflow run; all adversarially verified):

- **Zen killed tab groups.** It ships `browser.tabs.groups.enabled=false` and
  repurposed the native group machinery for pinned "folders". `tabs.group()` /
  `tabGroups.*` are present-but-inert on Zen. → groups render in our **own
  `sidebar_action` panel** (with a `browser_action` popup as a fallback in case
  Zen doesn't surface extension sidebars), never in the tab strip.
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
| `ext/` | the MV2 event-page extension. `background.js` is the source of truth (tab model, debounced classifier, native-host link, RAM actions); the sidebar is a pure view. |
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
   `ext/manifest.json`. Confirm: the sidebar/toolbar panel lists your tabs, the
   status line isn't "classifier offline" (→ native messaging resolved), and
   hitting ↻ produces named groups (→ live Haiku classify works).
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
   manifest, the key, and the dev tools.

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
