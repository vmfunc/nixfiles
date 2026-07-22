# niri (scrollable-tiling wayland compositor) for the linux desktop (tuna), imported
# only from home/profiles/desktop-linux.nix. colors come from rice.theme.colors so a
# theme.nix variant swap moves the borders with it; the wallpaper is the SAME vendored
# file wallpaper.nix hands to osascript on darwin, given to swww here.
# cross-file deps: waybar.nix ships the bar (its own systemd user unit, NOT spawned
# here); mako.nix owns the notification config/package (the daemon is spawned below);
# clipse.nix runs the clipboard listener (systemd on linux); theme.nix owns
# rice.theme.colors. niri's typed KDL settings come from the niri-flake hm module.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  c = config.rice.theme.colors;
  inherit (config.lib.niri.actions)
    spawn
    close-window
    focus-column-left
    focus-column-right
    focus-window-down
    focus-window-up
    move-column-left
    move-column-right
    move-window-down
    move-window-up
    move-column-to-workspace-down
    move-column-to-workspace-up
    focus-workspace
    focus-workspace-down
    focus-workspace-up
    set-column-width
    set-window-height
    switch-preset-column-width
    maximize-column
    fullscreen-window
    ;

  term = "${pkgs.wezterm}/bin/wezterm";
  menu = "${pkgs.fuzzel}/bin/fuzzel";
  # lock screen: grim grabs the frame (niri supports it; swaylock-effects' own
  # --screenshots does NOT capture on niri, which is what left a blank fill),
  # imagemagick softens it (mild downscale + a light blur + swaylock upscales), so
  # the desktop stays recognizable through the lock, not hidden behind a heavy blur.
  # tune: lower -scale / higher -blur = blurrier; -scale 100% -blur 0 = ~transparent.
  # swaylock shows it with the ring styling from swaylock.nix. trap cleans the temp
  # frame on unlock; a grim miss (before-sleep, screen already off) falls back to
  # swaylock's near-black config color. callers pass -f, harmlessly ignored.
  lockScript = pkgs.writeShellScript "niri-lock" ''
    img="$(${pkgs.coreutils}/bin/mktemp --suffix=.png)"
    trap '${pkgs.coreutils}/bin/rm -f "$img"' EXIT
    if ${pkgs.grim}/bin/grim "$img" 2>/dev/null && [ -s "$img" ]; then
      ${pkgs.imagemagick}/bin/magick "$img" -scale 55% -blur 0x1.2 "$img"
      ${pkgs.swaylock-effects}/bin/swaylock -f -i "$img"
    else
      ${pkgs.swaylock-effects}/bin/swaylock -f
    fi
  '';
  lock = "${lockScript}";
  playerctl = "${pkgs.playerctl}/bin/playerctl";
  # swayosd-client REPLACES the raw wpctl/brightnessctl volume+brightness calls so each
  # media-key press pops the on-screen bar (swayosd.nix runs the server + themes it).
  swayosd = "${pkgs.swayosd}/bin/swayosd-client";
  # clipse TUI in a fresh wezterm window (clipse.nix runs the history listener); the
  # window is floated by a window-rule keyed on its title (set below in the spawn).
  clipse = "${pkgs.clipse}/bin/clipse";

  # shared lain wallpaper (same file wallpaper.nix hands to osascript on darwin).
  # swww-daemon is started below, but `swww img` fails if it races the socket, so
  # poll `swww query` until the daemon answers, then set the image once.
  setWallpaper = pkgs.writeShellScript "set-wallpaper" ''
    until ${pkgs.awww}/bin/awww query >/dev/null 2>&1; do sleep 0.2; done
    exec ${pkgs.awww}/bin/awww img ${./wallpaper.jpg}
  '';

  # region -> grim -> gokapi -> shareable link on the clipboard. NO annotation UI
  # (azzie's call: the satty window between shot and link was friction, satty is
  # gone from the flow entirely). slurp cancel (escape) aborts the whole thing.
  # the raw png also lands in ~/Pictures so a shot never depends on the upload;
  # the HOTLINK url (direct image, embeds inline in chat) is what gets copied,
  # UrlDownload the fallback for non-hotlinkable types. the api key is sops-only
  # (public mirror); a failed upload keeps the file and shouts, never silent.
  gokapiKey = config.sops.secrets."gokapi-api-key".path;
  screenshot = pkgs.writeShellScript "niri-screenshot" ''
    dir="$HOME/Pictures"
    ${pkgs.coreutils}/bin/mkdir -p "$dir"
    out="$dir/screenshot-$(${pkgs.coreutils}/bin/date +%Y%m%d-%H%M%S).png"
    region="$(${pkgs.slurp}/bin/slurp)" || exit 0
    ${pkgs.grim}/bin/grim -g "$region" "$out" || exit 0
    resp="$(${pkgs.curl}/bin/curl -sf --max-time 30 \
      -H "apikey: $(${pkgs.coreutils}/bin/cat ${gokapiKey})" \
      -F "file=@$out" -F "isUnlimitedDownload=true" -F "isUnlimitedTime=true" \
      https://f.collar.sh/api/files/add)" || resp=""
    url="$(printf '%s' "$resp" | ${pkgs.jq}/bin/jq -r '.FileInfo.UrlHotlink // .FileInfo.UrlDownload // empty')"
    if [ -n "$url" ]; then
      printf '%s' "$url" | ${pkgs.wl-clipboard}/bin/wl-copy
      ${pkgs.libnotify}/bin/notify-send -a screenshot 'screenshot' "link copied: $url"
    else
      ${pkgs.libnotify}/bin/notify-send -u critical -a screenshot 'screenshot' "upload failed; kept $out"
    fi
  '';

  # Mod+M -> type "♪ artist - title <link>" into the FOCUSED window over the
  # virtual-keyboard protocol (wtype). senpai's custom shortcuts can only insert
  # static text, so the dynamic now-playing line lives here, one level up, which
  # also makes it work in vesktop/signal/anywhere. it types but does NOT press
  # enter: sending stays her call, so the line can be edited or abandoned. the
  # link rides along only when the player exposes an http(s) url (spotify-player
  # does; a local mpv file would be a useless file:// path, so it is dropped).
  npType = pkgs.writeShellScript "niri-np" ''
    np="$(${playerctl} metadata --format '{{artist}} - {{title}}' 2>/dev/null)" || exit 0
    [ -n "$np" ] || exit 0
    url="$(${playerctl} metadata xesam:url 2>/dev/null || true)"
    case "$url" in
      http*) np="$np $url" ;;
    esac
    # wait for the physical Mod+M to be RELEASED before typing: virtual keys
    # combine with a still-held super, so every space in a track title became
    # Mod+Space and spawned a launcher each (azzie got a screenful of fuzzel).
    ${pkgs.coreutils}/bin/sleep 0.6
    ${pkgs.wtype}/bin/wtype "*now playing* $np"
    # wtype uploads a custom keymap for its virtual keyboard (needed for unicode)
    # and niri lets it stick to the SEAT after wtype exits, leaving the physical
    # keyboard resolving through it (delete typed letters; it was bad). reloading
    # the config re-applies input.keyboard.xkb and restores the real keymap, so
    # the script cleans up after itself every run.
    exec ${config.programs.niri.package}/bin/niri msg action load-config-file
  '';

  # Mod+1..9 focus a workspace. niri workspaces are dynamic (a per-monitor
  # vertical strip), and this niri build exposes no "move column to workspace N"
  # action, only the relative move-column-to-workspace-down/up (bound on
  # Mod+Ctrl+J/K below). so there is no Mod+Shift+N here.
  workspaceBinds = lib.listToAttrs (
    lib.map (n: {
      name = "Mod+${toString n}";
      value.action = focus-workspace n;
    }) (lib.range 1 9)
  );

  # fuzzel-driven power menu (lock/logout/suspend/reboot/shutdown). power actions
  # go through logind/polkit, which allows an active local session without a
  # password. logout quits niri, dropping back to the greeter.
  # dmenu overlays pass --placeholder "" because fuzzel.nix sets the app-search
  # placeholder ("search the wired") globally, and it would ghost into these too.
  powerMenu = pkgs.writeShellScript "niri-power" ''
    choice=$(printf 'lock\nlogout\nsuspend\nreboot\nshutdown' \
      | ${menu} --dmenu --prompt 'power ' --placeholder "")
    case "$choice" in
      lock)     exec ${lock} -f ;;
      logout)   exec ${config.programs.niri.package}/bin/niri msg action quit ;;
      suspend)  exec ${pkgs.systemd}/bin/systemctl suspend ;;
      reboot)   exec ${pkgs.systemd}/bin/systemctl reboot ;;
      shutdown) exec ${pkgs.systemd}/bin/systemctl poweroff ;;
    esac
  '';

  # `keys`: a self-updating keybind cheatsheet parsed from the LIVE niri config
  # (so it always reflects the current binds, nothing hardcoded). strips the nix
  # store-path noise off spawn targets. run bare in a terminal, or Mod+Slash pops
  # it in a searchable fuzzel overlay.
  keysScript = pkgs.writeShellScriptBin "keys" ''
    cfg="''${XDG_CONFIG_HOME:-$HOME/.config}/niri/config.kdl"
    ${pkgs.gnused}/bin/sed -n '/^binds {/,/^}/p' "$cfg" \
      | ${pkgs.gnused}/bin/sed -E \
          -e '/^binds \{/d' -e '/^\}/d' \
          -e 's/^[[:space:]]+//' \
          -e 's#/nix/store/[a-z0-9]{32}-[^" ]*/bin/##g' \
          -e 's#/nix/store/[a-z0-9]{32}-##g' \
          -e 's/"//g' \
          -e 's/[[:space:]]*;?[[:space:]]*\}[[:space:]]*$//' \
          -e 's/[[:space:]]*\{[[:space:]]*/\t/' \
      | ${pkgs.gawk}/bin/awk -F'\t' '{printf "%-26s %s\n", $1, $2}' \
      | ${pkgs.coreutils}/bin/sort
  '';
  keysOverlay = pkgs.writeShellScript "niri-keys" ''
    ${keysScript}/bin/keys | ${menu} --dmenu --prompt 'keys  ' --placeholder ""
  '';

  # launchpad folders, console form: a two-stage fuzzel drawer on Mod+A. stage 1
  # lists xdg main categories as folders with app counts, stage 2 the apps inside
  # the pick; escape at stage 2 returns to the folders instead of bailing. entries
  # come from the .desktop files on XDG_DATA_DIRS (first id in path order wins,
  # the xdg precedence rule) and launch by id through gtk-launch so Exec field
  # codes and dbus activation are handled right, not a raw Exec= line.
  appDrawer = pkgs.writeShellScript "niri-apps" ''
        index="$(${pkgs.coreutils}/bin/mktemp)"
        trap '${pkgs.coreutils}/bin/rm -f "$index"' EXIT

        # id \t name \t categories, deduped by id in xdg precedence order
        {
          IFS=:
          for d in ''${XDG_DATA_HOME:-$HOME/.local/share}:''${XDG_DATA_DIRS:-/usr/local/share:/usr/share}; do
            for f in "$d"/applications/*.desktop; do
              [ -e "$f" ] && printf '%s\t%s\n' "''${f##*/}" "$f"
            done
          done
        } | ${pkgs.gawk}/bin/awk -F'\t' '!seen[$1]++' \
          | while IFS=$'\t' read -r id f; do
              ${pkgs.gawk}/bin/awk -v id="$id" '
                /^\[Desktop Entry\]/ { s = 1; next }
                /^\[/ { s = 0 }
                s && /^Name=/ && name == "" { name = substr($0, 6) }
                s && /^(NoDisplay|Hidden)=true/ { skip = 1 }
                s && /^Categories=/ { cats = substr($0, 12) }
                END { if (!skip && name != "") printf "%s\t%s\t%s\n", id, name, cats }
              ' "$f"
            done > "$index"

        # folder -> the xdg main categories it collects (freedesktop menu spec names)
        folders='media:AudioVideo;Audio;Video
    dev:Development
    games:Game
    graphics:Graphics
    net:Network
    office:Office
    settings:Settings
    system:System
    tools:Utility'

        in_folder() { # $1 = ;-joined category spec -> "name \t id" lines
          ${pkgs.gawk}/bin/awk -F'\t' -v spec="$1" '
            BEGIN { n = split(spec, want, ";") }
            {
              for (i = 1; i <= n; i++)
                if (index(";" $3 ";", ";" want[i] ";")) { printf "%s\t%s\n", $2, $1; next }
            }' "$index"
        }

        while :; do
          drawer="$(
            printf '%s\n' "$folders" | while IFS=: read -r label spec; do
              n="$(in_folder "$spec" | ${pkgs.coreutils}/bin/wc -l)"
              [ "$n" -gt 0 ] && printf '%-10s%4d\n' "$label" "$n"
            done
          )"
          [ -n "$drawer" ] || exit 0
          choice="$(printf '%s\n' "$drawer" | ${menu} --dmenu --prompt 'apps ' --placeholder "")"
          [ -n "$choice" ] || exit 0
          label="''${choice%% *}"
          spec="$(printf '%s\n' "$folders" | ${pkgs.gnused}/bin/sed -n "s/^$label://p")"
          # per-folder cache: fuzzel floats the most-picked apps of THIS folder up
          pick="$(in_folder "$spec" | ${pkgs.coreutils}/bin/sort -f \
            | ${pkgs.coreutils}/bin/cut -f1 \
            | ${menu} --dmenu --prompt "$label " --placeholder "" \
                --cache "''${XDG_CACHE_HOME:-$HOME/.cache}/fuzzel-apps-$label")"
          [ -n "$pick" ] || continue
          id="$(in_folder "$spec" | ${pkgs.gawk}/bin/awk -F'\t' -v n="$pick" '$1 == n { print $2; exit }')"
          # scope-wrapped for parity with fuzzel.nix launch-prefix (cgroup hygiene);
          # dbus-activated apps land in their own unit either way.
          exec ${pkgs.systemd}/bin/systemd-run --user --scope --collect --quiet -- \
            ${pkgs.gtk3}/bin/gtk-launch "''${id%.desktop}"
        done
  '';

  # Mod+P -> a bare fuzzel input line (--prompt-only: no list, no stdin) piped
  # straight into `plan add next`, so a todo gets captured mid-anything without
  # surfacing a terminal. mako toasts the hand-off; escape / empty input no-ops.
  planAdd = pkgs.writeShellScript "niri-plan-add" ''
    task="$(${menu} --dmenu --prompt-only 'plan  ' < /dev/null)"
    [ -n "$task" ] || exit 0
    if ${pkgs.plan}/bin/plan add next "$task"; then
      ${pkgs.libnotify}/bin/notify-send -a plan 'plan' "next: $task"
    else
      ${pkgs.libnotify}/bin/notify-send -u critical -a plan 'plan' 'add failed'
    fi
  '';

  # the unicode emoji-test table rendered to "<emoji>  <name>" lines at build
  # time, so the picker below never parses at runtime and never phones home
  # (the bemoji route downloads this same file imperatively on first run).
  emojiData =
    pkgs.runCommand "fuzzel-emoji-list" { }
      "${pkgs.gnused}/bin/sed -n 's/^.*; fully-qualified *# \\(\\S*\\) E[0-9.]* \\(.*\\)$/\\1  \\2/p' ${pkgs.unicode-emoji}/share/unicode/emoji/emoji-test.txt > $out";

  # Mod+Period -> emoji picker (the win+. muscle memory). the pick lands on the
  # wayland clipboard rather than being typed: wtype needs the virtual-keyboard
  # protocol and misfires on non-latin focus states, a paste never does. its own
  # cache file floats the usual suspects to the top.
  emojiPicker = pkgs.writeShellScript "niri-emoji" ''
    pick="$(${menu} --dmenu --prompt 'emoji  ' --placeholder "" \
      --cache "''${XDG_CACHE_HOME:-$HOME/.cache}/fuzzel-emoji" < ${emojiData})"
    [ -n "$pick" ] || exit 0
    printf '%s' "''${pick%% *}" | ${pkgs.wl-clipboard}/bin/wl-copy
  '';
in
{
  # gokapi api key for the screenshot uploader above, declared in the owning
  # module (sops.nix supplies the age key wiring). ciphertext-only in the tree.
  sops.secrets."gokapi-api-key" = {
    sopsFile = ../../../secrets/gokapi.yaml;
  };

  # niri's file watcher misses home-manager's config.kdl symlink flip, so after
  # a `just switch` the OLD binds stay live until logout (bit azzie with the
  # screenshot rewrite: the bar updated, Mod+S did not). poke the running
  # session at activation; NIRI_SOCKET is inherited when switching from a
  # terminal inside the session, and a headless/ssh/bootstrap run no-ops.
  home.activation.reloadNiri = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    if [ -n "''${NIRI_SOCKET:-}" ]; then
      run ${config.programs.niri.package}/bin/niri msg action load-config-file || true
    fi
  '';

  programs.niri.settings = {
    input.keyboard.xkb.layout = "us";
    # caps lock -> escape (vim ergonomics; azzie asked)
    input.keyboard.xkb.options = "caps:escape";

    # session env, set HERE (not environment.sessionVariables, which a greetd ->
    # niri-session does not source) so niri and everything it spawns inherit it.
    # NIXOS_OZONE_WL puts electron/chromium (vesktop/element/signal/cinny) on
    # native wayland so prefer-no-csd removes their title bars; MOZ_ENABLE_WAYLAND
    # does the same for firefox/zen. the QT_* pair is qt.nix's payload replanted
    # here for the same greetd reason: qt.nix writes them to systemd/home session
    # vars a greetd -> niri-session never sources, so a niri-spawned qt app (e.g.
    # wireshark) would ignore the adwaita-dark theme without this.
    environment = {
      NIXOS_OZONE_WL = "1";
      MOZ_ENABLE_WAYLAND = "1";
      ELECTRON_OZONE_PLATFORM_HINT = "auto";
      QT_QPA_PLATFORMTHEME = "gtk3";
      QT_STYLE_OVERRIDE = "adwaita-dark";
      # niri is pure wayland, so X11-only apps (orca-slicer/bambu-studio force the
      # X11 backend and crash without a display; wireshark; some tools) need the
      # xwayland-satellite service below, which serves :0. set it here so every
      # niri-spawned app inherits it (the greetd session does not source profile env).
      DISPLAY = ":0";
    };

    # tuna is a tiling desktop: let niri draw the frames, no client-side titlebars.
    prefer-no-csd = true;

    layout = {
      gaps = 12;
      # border and focus-ring both draw a frame; running both double-frames every window
      # and reads busy. we drive the mauve frame from `border` (it hugs the rounded
      # geometry set in window-rules) and turn focus-ring OFF so they never stack.
      border = {
        enable = true;
        width = 2;
        active.color = c.mauve;
        inactive.color = c.surface1;
      };
      focus-ring.enable = false;
      # soft dark drop shadow for depth against the near-black wallpaper. offset down a
      # touch, wide + diffuse; the color carries its own alpha so it fades into the base.
      shadow = {
        enable = true;
        softness = 30;
        spread = 4;
        offset = {
          x = 0;
          y = 6;
        };
        color = "#00000073";
      };
    };

    # square corners with a clean outline border (azzie prefers square, not round).
    # no geometry-corner-radius / clip-to-geometry, so windows stay sharp; the mauve
    # frame from layout.border stays an outline (draw-border-with-background off), not
    # a filled backing. no `matches` == all windows.
    window-rules = [
      {
        draw-border-with-background = false;
      }
      # clipse is a clipboard picker: a small floating window, not a tiled column.
      # the Alt+C bind launches wezterm with --class clipse.float (its wayland app-id),
      # so match on that app-id and float + size it like a picker.
      {
        matches = [ { app-id = "^clipse\\.float$"; } ];
        open-floating = true;
        default-column-width.fixed = 720;
        default-window-height.fixed = 480;
      }
      # chat apps, sheer through the compositor (app-ids confirmed via `niri msg
      # windows`; matches entries OR together). on tuna this route covers vesktop
      # too, the quickCss transparency stays a mac thing (azzie's call: compositor
      # over in-app settings here). whole-surface alpha, text included, so it
      # cannot go anywhere near css-sheer values: below ~0.85 chat text goes
      # muddy over the wallpaper. tune here if wanted.
      {
        matches = [
          { app-id = "^signal$"; }
          { app-id = "^vesktop$"; }
        ];
        opacity = 0.9;
      }
    ];

    # the launcher never reaches a stream: fuzzel's layer surface (default
    # namespace "launcher") is blocked from the screencast portal obs captures
    # through, so app searches and the plan/emoji inputs stay off the recording.
    # "screencast" not "screen-capture" on purpose: grim screenshots of the rice
    # should still include the launcher, and our screenshot flow has no
    # frozen-overlay path that could leak it into a live cast.
    layer-rules = [
      {
        matches = [ { namespace = "^launcher$"; } ];
        block-out-from = "screencast";
      }
    ];

    # pin the Framework Desktop's display (AOC CU34G4H on DP-1): a 3440x1440 ultrawide
    # gaming panel that comes up at 60Hz on auto-detect but SUPPORTS 200Hz. lock the
    # native res at its top fixed refresh (200) so the box stops idling at 60. refresh
    # is a float in niri-flake's schema. scale 1.0: at 34" the 1x logical res is right,
    # no HiDPI. VRR is supported-but-off here (fixed 200 is the safe default); flip
    # variable-refresh-rate to "on-demand" or true if a game wants adaptive sync.
    outputs."DP-1" = {
      mode = {
        width = 3440;
        height = 1440;
        refresh = 200.000;
      };
      scale = 1.0;
    };

    # waybar is NOT spawned here: waybar.nix already starts it via its systemd user unit
    # on graphical-session.target, so a launch here would run two bars. swww-daemon comes
    # up first, then the image setter polls its socket. mako IS spawned here: mako.nix
    # owns its config/package via services.mako, but this hm rev ships no systemd unit
    # for it, so niri is the single process owner (dbus activation never fires, the
    # instance spawned here already holds org.freedesktop.Notifications).
    spawn-at-startup = [
      { command = [ "${pkgs.awww}/bin/awww-daemon" ]; }
      { command = [ "${setWallpaper}" ]; }
      { command = [ (lib.getExe config.services.mako.package) ]; }
    ];

    binds = {
      "Mod+Return".action = spawn term;
      # launcher on Mod+Space AND Ctrl+Space (both, per azzie); Mod+D kept as a third alias.
      "Mod+Space".action = spawn menu;
      "Ctrl+Space".action = spawn menu;
      "Mod+D".action = spawn menu;
      # category app drawer (launchpad folders in a fuzzel overlay, script above)
      "Mod+A".action = spawn "${appDrawer}";
      "Mod+Q".action = close-window;

      # niri is column/scroll based: h/l walk columns, j/k walk windows inside a column;
      # add Shift to carry the focused window instead of just moving focus. arrows mirror
      # hjkl EXCEPT Mod+Shift+Up/Down, which jump workspaces instead of moving the
      # window (azzie asked; Mod+Shift+J/K keeps the move-window role).
      "Mod+H".action = focus-column-left;
      "Mod+L".action = focus-column-right;
      "Mod+J".action = focus-window-down;
      "Mod+K".action = focus-window-up;
      "Mod+Left".action = focus-column-left;
      "Mod+Right".action = focus-column-right;
      "Mod+Down".action = focus-window-down;
      "Mod+Up".action = focus-window-up;
      "Mod+Shift+H".action = move-column-left;
      "Mod+Shift+L".action = move-column-right;
      "Mod+Shift+J".action = move-window-down;
      "Mod+Shift+K".action = move-window-up;
      "Mod+Shift+Left".action = move-column-left;
      "Mod+Shift+Right".action = move-column-right;
      "Mod+Shift+Down".action = focus-workspace-down;
      "Mod+Shift+Up".action = focus-workspace-up;

      # carry the focused column to the workspace above/below (niri's own default
      # chord for this); Ctrl+arrows mirror it like the other nav binds.
      "Mod+Ctrl+J".action = move-column-to-workspace-down;
      "Mod+Ctrl+K".action = move-column-to-workspace-up;
      "Mod+Ctrl+Down".action = move-column-to-workspace-down;
      "Mod+Ctrl+Up".action = move-column-to-workspace-up;

      # walk the workspace strip itself. Alt because Mod+Up/Down is window focus
      # and Mod+Ctrl+Up/Down carries the column; only J/K here, Mod+Alt+L is lock.
      "Mod+Alt+J".action = focus-workspace-down;
      "Mod+Alt+K".action = focus-workspace-up;
      "Mod+Alt+Down".action = focus-workspace-down;
      "Mod+Alt+Up".action = focus-workspace-up;

      # sizing: minus/equal nudge column width, +Shift nudges window height inside
      # the column. R cycles niri's preset widths, F maximizes, Shift+F fullscreens.
      "Mod+Minus".action = set-column-width "-10%";
      "Mod+Equal".action = set-column-width "+10%";
      "Mod+Shift+Minus".action = set-window-height "-10%";
      "Mod+Shift+Equal".action = set-window-height "+10%";
      "Mod+R".action = switch-preset-column-width;
      "Mod+F".action = maximize-column;
      "Mod+Shift+F".action = fullscreen-window;

      # Mod+L is focus-column-right, so lock rides Mod+Alt+L to keep the "L" mnemonic
      # without clobbering it.
      "Mod+Alt+L".action = spawn lock "-f";
      # power menu (lock/logout/suspend/reboot/shutdown)
      "Mod+Shift+E".action = spawn "${powerMenu}";
      # Mod+/ -> searchable keybind cheatsheet (parsed live from this config)
      "Mod+Slash".action = spawn "${keysOverlay}";
      # quick todo capture into ~/.plan (script above)
      "Mod+P".action = spawn "${planAdd}";
      # type the now-playing line + link into the focused window (script above)
      "Mod+M".action = spawn "${npType}";
      # emoji picker -> clipboard (script above)
      "Mod+Period".action = spawn "${emojiPicker}";

      # region screenshot -> satty annotate -> ~/Pictures, on both Print and Mod+S.
      "Print".action = spawn "${screenshot}";
      "Mod+S".action = spawn "${screenshot}";

      # clipboard history picker on Alt+C (the mac twin binds the same chord in
      # aerospace.nix). a fresh wezterm process tagged --class clipse.float so the
      # window-rule above floats + sizes it like a picker; clipse.nix runs the listener.
      "Alt+C".action = spawn term "start" "--always-new-process" "--class" "clipse.float" "--" clipse;

      # media keys: volume + brightness go through swayosd-client (NOT raw wpctl/
      # brightnessctl) so each press pops the on-screen bar; +5/-5 preserves the old
      # 5% steps exactly. transport stays on playerctl (the player app shows its own
      # feedback). bare keysyms (no Mod) so the laptop/media row just works.
      "XF86AudioRaiseVolume".action = spawn swayosd "--output-volume" "+5";
      "XF86AudioLowerVolume".action = spawn swayosd "--output-volume" "-5";
      "XF86AudioMute".action = spawn swayosd "--output-volume" "mute-toggle";
      "XF86MonBrightnessUp".action = spawn swayosd "--brightness" "+5";
      "XF86MonBrightnessDown".action = spawn swayosd "--brightness" "-5";
      "XF86AudioPlay".action = spawn playerctl "play-pause";
      "XF86AudioNext".action = spawn playerctl "next";
      "XF86AudioPrev".action = spawn playerctl "previous";
    }
    // workspaceBinds;
  };

  # NO idle auto-lock (azzie's call: locking is manual, Mod+Alt+L only). swayidle
  # stays enabled purely for the before-sleep hook, so a suspend still never
  # resumes to an unlocked session; that one is a security boundary, not an
  # idle-timer annoyance.
  services.swayidle = {
    enable = true;
    # events is an attrset keyed by event name (the list form is deprecated).
    events.before-sleep = "${lock} -f";
  };

  # xwayland-satellite: an X server on :0 for niri (pure wayland), so X11-only apps
  # can open (orca-slicer/bambu-studio force the X11 backend; without this they die
  # with a GObject NULL-instance crash). DISPLAY=:0 is set in the session env above.
  # Type=notify (supported since 0.4) holds dependents until Xwayland is actually up.
  systemd.user.services.xwayland-satellite = {
    Unit = {
      Description = "Xwayland outside niri (X11 app support)";
      BindsTo = [ "graphical-session.target" ];
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
    };
    Service = {
      Type = "notify";
      NotifyAccess = "all";
      ExecStart = "${pkgs.xwayland-satellite}/bin/xwayland-satellite :0";
      Restart = "on-failure";
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };

  # dark GTK shell so GTK apps and the cursor don't fall back to Adwaita-light on a
  # near-black desktop: adw-gtk3-dark for gtk3, papirus-dark icons (name shared with
  # fuzzel.nix's icon-theme), a white Bibata cursor for visibility over the dark bg.
  # prefer-dark is forced for gtk3/gtk4 so libadwaita apps also pick the dark variant.
  gtk = {
    enable = true;
    theme = {
      name = "adw-gtk3-dark";
      package = pkgs.adw-gtk3;
    };
    iconTheme = {
      name = "Papirus-Dark";
      package = pkgs.papirus-icon-theme;
    };
    gtk3.extraConfig.gtk-application-prefer-dark-theme = true;
    gtk4.extraConfig.gtk-application-prefer-dark-theme = true;
  };

  # home.pointerCursor drives the wayland/xcursor theme and, with gtk.enable, the GTK
  # cursor too, so we set it once here instead of also in gtk.cursorTheme.
  home.pointerCursor = {
    name = "Bibata-Modern-Ice";
    package = pkgs.bibata-cursors;
    size = 24;
    gtk.enable = true;
  };

  # niri companions: wallpaper, screenshots, wayland clipboard bridge, brightness/
  # media controls. fuzzel/mako/swaylock/swayosd install their own packages via their
  # modules (programs.fuzzel / services.mako / programs.swaylock / swayosd.nix), so
  # they are NOT listed here (avoid a duplicate); the store-path refs above still
  # resolve to those same packages. wezterm/clipse are base + clipse.nix; wpctl came
  # from the system pipewire stack but the media binds now go through swayosd-client.
  home.packages = with pkgs; [
    awww
    grim
    slurp
    satty
    imagemagick # the lock-screen blur wrapper above shells out to `magick`
    wl-clipboard
    pavucontrol
    brightnessctl
    # pkgs-qualified: the `playerctl` let binding above shadows the name with a
    # store-path string for the binds, so `with pkgs` would otherwise pick up the string.
    pkgs.playerctl
    keysScript # the `keys` cheatsheet command
  ];
}
