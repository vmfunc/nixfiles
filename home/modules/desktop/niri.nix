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
  lock = "${pkgs.swaylock-effects}/bin/swaylock";
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

  # region-select -> annotate -> save. grim pipes raw png to satty over stdin; the
  # dir is made in-script so a fresh box does not lose the first shot to a missing dir.
  screenshot = pkgs.writeShellScript "niri-screenshot" ''
    dir="$HOME/Pictures"
    ${pkgs.coreutils}/bin/mkdir -p "$dir"
    ${pkgs.grim}/bin/grim -g "$(${pkgs.slurp}/bin/slurp)" - \
      | ${pkgs.satty}/bin/satty --filename - \
          --output-filename "$dir/screenshot-$(${pkgs.coreutils}/bin/date +%Y%m%d-%H%M%S).png"
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
  powerMenu = pkgs.writeShellScript "niri-power" ''
    choice=$(printf 'lock\nlogout\nsuspend\nreboot\nshutdown' \
      | ${menu} --dmenu --prompt 'power ')
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
    ${keysScript}/bin/keys | ${menu} --dmenu --prompt 'keys  '
  '';
in
{
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

      "Print".action = spawn "${screenshot}";

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

  # idle -> lock at 5m, and lock before the box sleeps so it never resumes unlocked.
  services.swayidle = {
    enable = true;
    timeouts = [
      {
        timeout = 300;
        command = "${lock} -f";
      }
    ];
    # events is an attrset keyed by event name (the list form is deprecated).
    events.before-sleep = "${lock} -f";
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
    wl-clipboard
    pavucontrol
    brightnessctl
    # pkgs-qualified: the `playerctl` let binding above shadows the name with a
    # store-path string for the binds, so `with pkgs` would otherwise pick up the string.
    pkgs.playerctl
    keysScript # the `keys` cheatsheet command
  ];
}
