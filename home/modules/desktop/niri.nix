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

    # tuna is a tiling desktop: let niri draw the frames, no client-side titlebars.
    prefer-no-csd = true;

    layout = {
      gaps = 8;
      border = {
        width = 2;
        active.color = c.mauve;
        inactive.color = c.surface1;
      };
      focus-ring = {
        width = 2;
        active.color = c.mauve;
        inactive.color = c.surface1;
      };
    };

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
      "Mod+D".action = spawn menu;
      "Mod+Q".action = close-window;

      # niri is column/scroll based: h/l walk columns, j/k walk windows inside a column;
      # add Shift to carry the focused window instead of just moving focus.
      "Mod+H".action = focus-column-left;
      "Mod+L".action = focus-column-right;
      "Mod+J".action = focus-window-down;
      "Mod+K".action = focus-window-up;
      "Mod+Shift+H".action = move-column-left;
      "Mod+Shift+L".action = move-column-right;
      "Mod+Shift+J".action = move-window-down;
      "Mod+Shift+K".action = move-window-up;

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
    events = [
      {
        event = "before-sleep";
        command = "${lock} -f";
      }
    ];
  };

  # niri companions: launcher, notifications, wallpaper, lock, screenshots, wayland
  # clipboard bridge, audio/brightness/media controls. wezterm is base; wpctl comes
  # from the system pipewire stack, referenced by store path in the binds above.
  home.packages = with pkgs; [
    fuzzel
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
