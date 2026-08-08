# obsidian-publish: the reproducible layer under vmfunc.ink + the plush editor rice.
#
# the vault itself is Sync-owned (see obsidian.nix: "only ever mkdir, never
# write"), so this module does NOT manage vault content on every rebuild. it
# ships two things instead:
#
#   1. `vault-scaffold`  a command that seeds a FRESH box: copies the canonical
#      publish.css / publish.js / wired-extras.css into place ONLY IF ABSENT, so
#      it never clobbers an edit Sync just carried in from the phone. re-runnable.
#   2. the community-plugin set, fetched + pinned from GitHub, installed into
#      .obsidian/plugins and enabled in community-plugins.json (also copy-if-absent).
#
# assets live next to this file in ./vault-assets and are the git source of
# truth; edit them there and re-run `vault-scaffold --force` to push an update.
#
# imported by profiles/desktop-linux.nix, gated on `rice.notes.publish.enable`.
# on a fresh box: rebuild, then run `vault-scaffold` once.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.rice.notes.publish;
  vault = config.rice.notes.vault;

  # --- community plugins -----------------------------------------------------
  # each: the community id (the .obsidian/plugins dir name obsidian expects), the
  # GitHub repo, the pinned release tag, and SRI hashes of that tag's three
  # release assets. bump = new tag + all three hashes together.
  # DataviewJS is not a plugin; it's a toggle inside the already-installed
  # dataview plugin (Settings -> Dataview -> Enable JavaScript queries).
  # Mermaid needs nothing: it's native to obsidian.
  plugins = [
    {
      id = "obsidian-style-settings";
      repo = "mgmeyers/obsidian-style-settings";
      tag = "1.0.9";
      main = "sha256-GCirqs2rTFV4twWmJcWFswUS+O+tTHz8WhjnDMNVdGg=";
      manifest = "sha256-nP/cIM8qoTVIIOAFC2lLD5tXZEbj1dRKNq6LAYflv7g=";
      styles = "sha256-7nk30r5QZTqJzLMK5fBXKyNQfVt/EyjQBScaNjB1v9g=";
    }
    {
      id = "obsidian-icon-folder";
      repo = "FlorianWoelki/obsidian-iconize";
      tag = "2.14.7";
      main = "sha256-raCwCXBlVsmBAflTpqh/XK/TABCF31k9O+KO7uohggE=";
      manifest = "sha256-9SShjWnpkKJEFzo1lWgcOaILy8ncGLWa9R5FZg/vXKI=";
      styles = "sha256-Vv/rg0n0r5fauKFPytywAZ07N7EW16NKoh6VjphFWok=";
    }
    {
      id = "table-editor-obsidian";
      repo = "tgrosinger/advanced-tables-obsidian";
      tag = "0.23.2";
      main = "sha256-z13U3b3evvaMyZzZOog+M4lcfxI9BLxdEQbqbjOLp5E=";
      manifest = "sha256-aYtPd0ReB9iH8zRQ6vUzoo4Jm3tIP2QvqIM2L/vY/+k=";
      styles = "sha256-I/ow128Rf9PRYkxMLm3e2r+AmSOZawU0iV+CVOpqOfc=";
    }
    {
      id = "editing-toolbar";
      repo = "PKM-er/obsidian-editing-toolbar";
      tag = "4.0.11";
      main = "sha256-xohf5zeqdA0uj9OCVltKiWe7BEAHxp/1exdHq5TZTm8=";
      manifest = "sha256-defKed//UIQek45oiVnNoTOUFt6YQJ0DiqWjrzRbSTM=";
      styles = "sha256-hR1I6AASu0fuJvR4io+Lt00ivWa7AplhoTMVfsVt8LM=";
    }
    {
      id = "cmdr";
      repo = "phibr0/obsidian-commander";
      tag = "0.5.7";
      main = "sha256-YK9vY3nz9+6W4O77pWttzNUXUbhZzKwLrGHqE+f5AKI=";
      manifest = "sha256-TagZhW+tHCW71uc3VaSP0P4B3vzHmgSeXDkZqA4Vkj8=";
      styles = "sha256-yfVdirK0ypqCTDryKbpuef2/grWx1eFrkMcpc3kZkDA=";
    }
    {
      id = "obsidian-kanban";
      repo = "mgmeyers/obsidian-kanban";
      tag = "2.0.51";
      main = "sha256-p+O9TPJfm39TqEHETOmQ2w7195VOvKsXrm3KgDEMOaw=";
      manifest = "sha256-JJdnhwl+rUZ5aeAUo1ZU56gOTbSal3aJpIr636FeGFQ=";
      styles = "sha256-7PbdMfFyfEQczm9UeUsNORbc//yH+he4VceboEqF2ac=";
    }
    {
      # darakah's original repo is deleted from github; seanlowe's fork is the
      # community-listed successor and ships under its own plugin id.
      id = "timelines-revamped";
      repo = "seanlowe/obsidian-timelines";
      tag = "2.4.0";
      main = "sha256-U6qThNwc0qYL/zhfxo4+5Cf6PjEh2rBybq2/AWTy7rw=";
      manifest = "sha256-eej4fAweFL+kYeK0F9aebvXZwo/e2lzfxzzOyE6nqGo=";
      styles = "sha256-NWDMjuLd2Irw7V+4MBd+B2B7+AuYLJIc+eB22V0UWYc=";
    }
    {
      id = "breadcrumbs";
      repo = "SkepticMystic/breadcrumbs";
      tag = "4.21.10";
      main = "sha256-uUHfym6rU0LQb/z47t1r0Zu28hf3NMpXgQaDSv+iJDw=";
      manifest = "sha256-j+zBtGCzZZMsjO8Zw3btP8SPyzXZ3LA8KR2RCFJOEv4=";
      styles = "sha256-Z03kV7RTiVpZ40JGbDePUnLSZZAL+ei21Q2JLMN9XGA=";
    }
    {
      id = "pdf-plus";
      repo = "RyotaUshio/obsidian-pdf-plus";
      tag = "0.40.31";
      main = "sha256-P9OVygFf+BLfikjnXaDsenq1pvWUBtN1RwiYsfcqrJM=";
      manifest = "sha256-3KUBZbdDFs2yt2ySCEN0mXvnlJ0hazHvzswrgv9KCGw=";
      styles = "sha256-TZRNbqeqWB/c2DZ8nYqwnzfFqMWU4zZUd5X3ny7eQGY=";
    }
    {
      id = "code-styler";
      repo = "mayurankv/obsidian-code-styler";
      tag = "1.1.7";
      main = "sha256-eGTmkKQgGnIAcN5Z+85F7KzLw6OP25vaMMPxDT09zP8=";
      manifest = "sha256-WNz5+TEYiN4ngAc6k4vIBVIAD0UufiYOXtLQIuK4n4w=";
      styles = "sha256-L2V2zgZ9z0mUvB0q+iHx9okTmpeXAgijjE7J2ajRSd4=";
    }
    {
      id = "number-headings-obsidian";
      repo = "onlyafly/number-headings-obsidian";
      tag = "1.16.0";
      main = "sha256-6tGpneVYGjFgzBfC+yq15EQ1Bb+c1yJHy/A0In8VJgA=";
      manifest = "sha256-tP/aIQ3WbD4/kIV3FIbyxzTt9/4m9eDtA3LPjoYKqf0=";
      styles = "sha256-fHTZMHNGIH/DiuESaoAwsuUqVkBqLcguMPHucSlubpo=";
    }
    {
      # the work-clock capture funnel (vault: moc-work). the iphone shortcuts
      # and the work-out/work-log commands (notes/work-clock.nix) all write
      # frontmatter through its URIs. 2.0.0 ships no styles.css.
      id = "obsidian-advanced-uri";
      repo = "Vinzent03/obsidian-advanced-uri";
      tag = "2.0.0";
      main = "sha256-QoFnWlxWI2LYJ78zD3r32SgnYVFxSunt4YzxLXBVb68=";
      manifest = "sha256-Dz07v/rHGSiM60RuDkC54OzzhZuaSpYQbXLvbthqzG8=";
    }
    {
      # the second capture funnel, the iphone-shortcuts x-callback side alongside
      # advanced-uri. ships no styles.css.
      id = "actions-uri";
      repo = "czottmann/obsidian-actions-uri";
      tag = "1.9.0";
      main = "sha256-XxMLBUNaTrJALSYaSIDTEONfKzfpuHcqANEE5GB9ZRI=";
      manifest = "sha256-3r2ssZDAbQ9CJUrO/dmhagaRtkkbk2iXaUd0mNXrOLs=";
    }
    {
      # folder-aware command toolbars, the mobile command surface (daily -> work
      # in/out, shopping -> add item, papers -> clip).
      id = "note-toolbar";
      repo = "chrisgurney/obsidian-note-toolbar";
      tag = "1.34.13";
      main = "sha256-MMeS13YaLrlI5tn4g6BRKpG6fbWSjkjCQz/K03voIEY=";
      manifest = "sha256-LJzlTV78nx8jLIYNEq/BuvBnnfJ4TnZ7mct4A487eCM=";
      styles = "sha256-D7Ks4u8vS95eSXX6cpQwcuTPUlFKDufwM8aLKioKFYA=";
    }
    {
      # regex -> css class, for auto-badging CVE-\d+, 0x addresses, register
      # names in rose pine (styling lives in a vault snippet).
      id = "regex-mark";
      repo = "Mara-Li/obsidian-regex-mark";
      tag = "1.11.1";
      main = "sha256-rvBpiQsNBjm0TlegBuXUuD4Qauea2Cusv1wI7K9RKUI=";
      manifest = "sha256-aIOY3JMrSIodGogMaTUOvFCDfwwv3ZOZdEkRT5Pxr+Q=";
      styles = "sha256-k8PKYKwBMYGQdc9lQDhzwHRNocMCdX40UAS6F6woTEM=";
    }
    {
      # one-hotkey capture + macro engine, the engine behind the inbox pipeline;
      # advanced-uri/actions-uri can trigger its choices from the phone.
      # needs obsidian >= 1.13 (the overlay bump in overlays/default.nix).
      id = "quickadd";
      repo = "chhoumann/quickadd";
      tag = "2.21.0";
      main = "sha256-hjYZiu8pzWS1Pe8b+SG6713fgwcMinfFRXySdmF6ga0=";
      manifest = "sha256-C6m0I7tH7ineIIVPkAbEgG93UIXXubWC4J+M1LrO0jE=";
      styles = "sha256-cp2DYvxsUYYzwSyq4ce7UFGp6+mq9iz+OfuJUAL+BLc=";
    }
    {
      # staggers plugin load so vault-open stays instant on the phone as the
      # plugin set grows. the enabler for the rest of the glow-up.
      id = "lazy-plugins";
      repo = "alangrainger/obsidian-lazy-plugins";
      tag = "1.0.24";
      main = "sha256-s+i8Yehz7buh8d6U9HlJqvMDqzFXkFmjeDgz6oWhE0c=";
      manifest = "sha256-mCwKXtQmkGs1+sGTPekM1OekETZmBI1zm9l7F/QMzRw=";
      styles = "sha256-qkonIXjRJNyMIF134SbOcLXUuOXOC7Idc3ibJijYyvE=";
    }
  ];

  pluginAsset =
    repo: tag: name: hash:
    pkgs.fetchurl {
      url = "https://github.com/${repo}/releases/download/${tag}/${name}";
      inherit hash;
    };

  # one dir per plugin, laid out exactly as .obsidian/plugins expects.
  # styles.css is optional: not every release ships one (advanced-uri).
  pluginFarm = pkgs.linkFarm "obsidian-community-plugins" (
    map (p: {
      name = p.id;
      path = pkgs.linkFarm p.id (
        [
          {
            name = "main.js";
            path = pluginAsset p.repo p.tag "main.js" p.main;
          }
          {
            name = "manifest.json";
            path = pluginAsset p.repo p.tag "manifest.json" p.manifest;
          }
        ]
        ++ lib.optional (p ? styles) {
          name = "styles.css";
          path = pluginAsset p.repo p.tag "styles.css" p.styles;
        }
      );
    }) plugins
  );

  # the plugins to enable on top of what the vault already has
  enabledIds = map (p: p.id) plugins;
  alreadyEnabled = [
    "obsidian-excalidraw-plugin"
    "dataview"
    "obsidian-tasks-plugin"
    "templater-obsidian"
    "calendar"
    "omnisearch"
    "obsidian-auto-link-title"
  ];
  communityPluginsJson = builtins.toJSON (alreadyEnabled ++ enabledIds);

  assets = ./vault-assets;

  scaffold = pkgs.writeShellApplication {
    name = "vault-scaffold";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.jq
    ];
    text = ''
      vault=${lib.escapeShellArg vault}
      force=0
      [ "''${1:-}" = "--force" ] && force=1

      # --check: report drift between the vault's live scaffolded assets and the
      # nix source of truth. Sync keeps no history, so an edit made live (e.g. a
      # publish.css tweak from the phone) silently diverges; this surfaces it so
      # it can be backported before a --force clobbers it.
      if [ "''${1:-}" = "--check" ]; then
        echo "drift check (live vault vs nix source of truth):"
        rc=0
        check() { # check <src> <dst> <label>
          if [ ! -e "$2" ]; then echo "  MISSING  $3"; rc=1
          elif cmp -s "$1" "$2"; then echo "  ok       $3"
          else echo "  DRIFT    $3 ($2)"; rc=1; fi
        }
        check ${assets}/publish.css      "$vault/publish.css"                        publish.css
        check ${assets}/publish.js       "$vault/publish.js"                         publish.js
        check ${assets}/wired-extras.css "$vault/.obsidian/snippets/wired-extras.css" wired-extras.css
        check ${assets}/rice-extras.css  "$vault/.obsidian/snippets/rice-extras.css"  rice-extras.css
        [ "$rc" = 0 ] && echo "no drift." || echo "drift found; backport the live edit into vault-assets, or --force to overwrite it."
        exit $rc
      fi

      seed() { # seed <src> <dst>
        if [ "$force" = 1 ] || [ ! -e "$2" ]; then
          install -Dm644 "$1" "$2"
          echo "  seeded $2"
        else
          echo "  kept   $2 (exists; --force to overwrite)"
        fi
      }

      echo "scaffolding vault at $vault"
      seed ${assets}/publish.css      "$vault/publish.css"
      seed ${assets}/publish.js       "$vault/publish.js"
      seed ${assets}/wired-extras.css "$vault/.obsidian/snippets/wired-extras.css"
      seed ${assets}/rice-extras.css  "$vault/.obsidian/snippets/rice-extras.css"

      # community plugins: install the pinned set (copy-if-absent, per file, so a
      # newer version obsidian self-updated stays put unless --force)
      for dir in ${pluginFarm}/*/; do
        id=$(basename "$dir")
        for f in "$dir"*; do
          seed "$f" "$vault/.obsidian/plugins/$id/''${f##*/}"
        done
      done

      # enable the community plugin list (copy-if-absent so a manual toggle wins)
      cpj="$vault/.obsidian/community-plugins.json"
      if [ "$force" = 1 ] || [ ! -e "$cpj" ]; then
        printf '%s\n' ${lib.escapeShellArg communityPluginsJson} | jq '.' > "$cpj"
        echo "  wrote  $cpj"
      else
        echo "  kept   $cpj"
      fi

      echo "done. in obsidian: Settings -> Appearance -> CSS snippets, reload;"
      echo "then Community plugins: turn restricted mode off (one-time) so the"
      echo "seeded set actually loads. DataviewJS: Settings -> Dataview -> enable JS."
    '';
  };

  # vault-recent: regenerate the marked block in recently.md from the vault's own
  # mtimes (Publish runs no dataview, so the "what's new" feed can't be a live
  # query). deterministic + writes only on change, so all synced hosts converge
  # on the same block and re-runs are quiet no-ops. the real logic is the tracked
  # script next to this file; this just puts it on PATH with its deps.
  vault-recent = pkgs.writeShellApplication {
    name = "vault-recent";
    runtimeInputs = with pkgs; [
      coreutils
      findutils
      gnugrep
      gnused
      gawk
      bash
    ];
    text = ''
      exec ${pkgs.bash}/bin/bash ${assets}/vault-recent.sh "''${1:-${vault}}"
    '';
  };

  # vault-leaklint: pre-publish opsec check. flags wikilinks from published notes
  # into private ones (work/, shopping/, publish:false), which Publish would leak
  # as dim title-bearing links, plus stray %hidden markers. read-only; the logic
  # is the tracked script next to this file.
  vault-leaklint = pkgs.writeShellApplication {
    name = "vault-leaklint";
    runtimeInputs = with pkgs; [
      coreutils
      findutils
      gnugrep
      gnused
      bash
    ];
    text = ''
      exec ${pkgs.bash}/bin/bash ${assets}/vault-leaklint.sh "''${1:-${vault}}"
    '';
  };
in
{
  options.rice.notes.publish = {
    enable = lib.mkEnableOption "obsidian publish assets + plugin scaffold";
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      {
        home.packages = [
          scaffold
          vault-recent
          vault-leaklint
        ];

        # note: we intentionally do NOT run scaffold in home.activation, because the
        # vault is Sync-owned. run `vault-scaffold` by hand on a fresh box.
      }

      # the self-updating feed: a user timer refreshes recently.md every ~30 min.
      # linux-only (the vault package + these hosts are linux; macs get obsidian via
      # brew and can run `vault-recent` by hand). RandomizedDelaySec spreads the
      # write so two synced boxes don't race on the same block.
      (lib.mkIf pkgs.stdenv.hostPlatform.isLinux {
        systemd.user.services.vault-recent = {
          Unit.Description = "regenerate the vmfunc.ink recently.md feed";
          Service = {
            Type = "oneshot";
            ExecStart = "${vault-recent}/bin/vault-recent";
          };
        };
        systemd.user.timers.vault-recent = {
          Unit.Description = "refresh recently.md every 30 minutes";
          Timer = {
            OnCalendar = "*:0/30";
            Persistent = true;
            RandomizedDelaySec = "5m";
          };
          Install.WantedBy = [ "timers.target" ];
        };
      })
    ]
  );
}
