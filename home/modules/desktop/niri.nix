# niri (scrollable-tiling wayland compositor) for the linux desktop (tuna), imported
# only from home/profiles/desktop-linux.nix. colors come from rice.theme.colors so a
# theme.nix variant swap moves the borders with it; the wallpaper is the SAME vendored
# file wallpaper.nix hands to osascript on darwin, given to swww here.
# cross-file deps: waybar.nix ships the bar (its own systemd user unit, NOT spawned
# here); clipse.nix runs the clipboard listener (systemd on linux); theme.nix owns
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
    focus-workspace
    ;

  term = "${pkgs.wezterm}/bin/wezterm";
  menu = "${pkgs.fuzzel}/bin/fuzzel";
  lock = "${pkgs.swaylock-effects}/bin/swaylock";
  wpctl = "${pkgs.wireplumber}/bin/wpctl";
  brightnessctl = "${pkgs.brightnessctl}/bin/brightnessctl";
  playerctl = "${pkgs.playerctl}/bin/playerctl";

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
  # action, only the relative move-column-to-workspace-down/up. so Mod+Shift+J/K
  # (move-window-down/up) covers reordering; there is no Mod+Shift+N here.
  workspaceBinds = lib.listToAttrs (
    lib.map (n: {
      name = "Mod+${toString n}";
      value.action = focus-workspace n;
    }) (lib.range 1 9)
  );
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
    # does the same for firefox/zen.
    environment = {
      NIXOS_OZONE_WL = "1";
      MOZ_ENABLE_WAYLAND = "1";
      ELECTRON_OZONE_PLATFORM_HINT = "auto";
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
    ];

    # TODO(deploy): pin the Framework Desktop's output (mode/scale) once the connector
    # name is known from `niri msg outputs`; niri auto-detects a sane mode until then.

    # waybar is NOT spawned here: waybar.nix already starts it via its systemd user unit
    # on graphical-session.target, so a launch here would run two bars. swww-daemon comes
    # up first, then the image setter polls its socket; mako handles notifications.
    spawn-at-startup = [
      { command = [ "${pkgs.awww}/bin/awww-daemon" ]; }
      { command = [ "${setWallpaper}" ]; }
      { command = [ "${pkgs.mako}/bin/mako" ]; }
    ];

    binds = {
      "Mod+Return".action = spawn term;
      # launcher on Mod+Space AND Ctrl+Space (both, per azzie); Mod+D kept as a third alias.
      "Mod+Space".action = spawn menu;
      "Ctrl+Space".action = spawn menu;
      "Mod+D".action = spawn menu;
      "Mod+Q".action = close-window;

      # niri is column/scroll based: h/l walk columns, j/k walk windows inside a column;
      # add Shift to carry the focused window instead of just moving focus. arrow keys are
      # bound on top of hjkl (both work) with the exact same actions.
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
      "Mod+Shift+Down".action = move-window-down;
      "Mod+Shift+Up".action = move-window-up;

      # Mod+L is focus-column-right, so lock rides Mod+Alt+L to keep the "L" mnemonic
      # without clobbering it.
      "Mod+Alt+L".action = spawn lock "-f";

      "Print".action = spawn "${screenshot}";

      # media keys: pipewire volume via wpctl, backlight via brightnessctl, transport
      # via playerctl. bare keysyms (no Mod) so the laptop/media row just works.
      "XF86AudioRaiseVolume".action = spawn wpctl "set-volume" "@DEFAULT_AUDIO_SINK@" "5%+";
      "XF86AudioLowerVolume".action = spawn wpctl "set-volume" "@DEFAULT_AUDIO_SINK@" "5%-";
      "XF86AudioMute".action = spawn wpctl "set-mute" "@DEFAULT_AUDIO_SINK@" "toggle";
      "XF86MonBrightnessUp".action = spawn brightnessctl "set" "5%+";
      "XF86MonBrightnessDown".action = spawn brightnessctl "set" "5%-";
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

  # niri companions: notifications, wallpaper, lock, screenshots, wayland clipboard
  # bridge, audio/brightness/media controls. the launcher (fuzzel) is installed by
  # fuzzel.nix via programs.fuzzel.enable, so it is NOT listed here (avoid a duplicate);
  # the `menu` store-path ref above still resolves to that same package. wezterm is base;
  # wpctl comes from the system pipewire stack, referenced by store path in the binds.
  home.packages = with pkgs; [
    mako
    awww
    swaylock-effects
    grim
    slurp
    satty
    wl-clipboard
    pavucontrol
    # pkgs-qualified: the let bindings above shadow these names with store-path
    # strings for the binds, so `with pkgs` would otherwise pick up the strings.
    pkgs.brightnessctl
    pkgs.playerctl
  ];
}
