# waybar for the niri desktop (tuna). this is the LINUX twin of the mac's sketchybar
# (sketchybar/sketchybarrc): the same lain status-console, a flat near-black hairline
# strip pinned to the top edge, NO floating pills, FIELD:value readouts in the copland-os
# register (dimmed all-caps field label + accent value). colors come from rice.theme.colors
# so a theme.nix variant swap moves the bar with it. the eorzea module mirrors
# sketchybar/plugins/eorzea.sh (same unix*3600/175 math, same day=yellow/night=mauve) so
# both machines agree on ET. started by its systemd user unit via graphical-session.target,
# NOT niri spawn-at-startup (see niri.nix).
# cross-file deps: theme.nix owns rice.theme.colors; niri.nix owns the compositor + spawns.
{
  config,
  pkgs,
  ...
}:
let
  c = config.rice.theme.colors;

  # console register: a dimmed all-caps FIELD label + an accent VALUE, two-toned in one
  # pango span pair exactly like sketchybar's icon(field)/label(value) split. waybar renders
  # every module `format` through pango markup, so the built-in modules get the split too.
  field = label: "<span color='${c.subtext0}'>${label}</span>";
  value = color: v: "<span color='${color}'>${v}</span>";

  # 1 ET day = 70 real minutes, so ET-seconds = unix * 3600/175. day (6..18) is yellow,
  # night is mauve, matching sketchybar/plugins/eorzea.sh so the two bars never disagree.
  eorzea = pkgs.writeShellScript "waybar-eorzea" ''
    ET=$(( $(date +%s) * 3600 / 175 ))
    EH=$((ET / 3600 % 24)); EM=$((ET / 60 % 60))
    if [ "$EH" -ge 6 ] && [ "$EH" -lt 18 ]; then COL='${c.yellow}'; else COL='${c.mauve}'; fi
    printf "<span color='${c.subtext0}'>ET:</span> <span color='%s'>%02d:%02d</span>\n" "$COL" "$EH" "$EM"
  '';
in
{
  programs.waybar = {
    enable = true;
    systemd.enable = true;

    settings.mainBar = {
      layer = "top";
      position = "top";
      height = 26;
      # flat strip, no float: spacing lives in per-module padding, not gaps between pills.
      spacing = 0;

      # left: workspace tape + focused-window readout, mirroring sketchybar's
      # space.* tape -> sep.app "::" -> front_app "APP:<name>".
      modules-left = [
        "niri/workspaces"
        "custom/sep"
        "niri/window"
      ];
      modules-center = [ "clock" ];
      # right: the same console field stack as sketchybarrc, same order.
      modules-right = [
        "cpu"
        "memory"
        "network"
        "pulseaudio"
        "custom/eorzea"
        "tray"
      ];

      "niri/workspaces".format = "{index}";

      # the "::" divider between the tape and the app readout (sketchybar sep.app).
      "custom/sep" = {
        format = "::";
        tooltip = false;
      };

      # APP:<focused title>, the mac's front_app readout. {title} is markup-substituted
      # into the accent value slot; max-length keeps a long title from eating the bar.
      "niri/window" = {
        max-length = 48;
        format = "${field "APP:"} ${value c.mauve "{title}"}";
      };

      clock = {
        format = "${field "TIME:"} ${value c.text "{:%a %d %b %H:%M}"}";
        format-alt = "${field "TIME:"} ${value c.text "{:%H:%M:%S}"}";
        tooltip-format = "<tt><small>{calendar}</small></tt>";
      };

      cpu = {
        format = "${field "CPU:"} ${value c.mauve "{usage}%"}";
        interval = 3;
      };

      memory = {
        format = "${field "MEM:"} ${value c.green "{percentage}%"}";
        interval = 5;
      };

      network = {
        format-wifi = "${field "NET:"} ${value c.mauve "{bandwidthDownBytes}"}";
        format-ethernet = "${field "NET:"} ${value c.mauve "{bandwidthDownBytes}"}";
        format-disconnected = "${field "NET:"} ${value c.subtext0 "DOWN"}";
        interval = 3;
        tooltip-format = "{ifname}: {ipaddr}";
      };

      pulseaudio = {
        format = "${field "VOL:"} ${value c.mauve "{volume}%"}";
        format-muted = "${field "VOL:"} ${value c.subtext0 "MUTE"}";
        on-click = "${pkgs.pavucontrol}/bin/pavucontrol";
      };

      "custom/eorzea" = {
        exec = "${eorzea}";
        interval = 20;
        tooltip = false;
      };

      tray.spacing = 8;
    };

    style = ''
      * {
        font-family: "JetBrainsMono Nerd Font", "Symbols Nerd Font";
        font-size: 12px;
        font-weight: 700;
        min-height: 0;
      }

      /* flat lain hairline strip: near-black crust at ~0.94 like sketchybar's BAR_COLOR
         (0xf0 crust), pinned to the top edge, no float, no rounding, no per-module pills.
         a 1px surface line gives it a CRT scanline edge over a dark wallpaper. */
      window#waybar {
        background: alpha(${c.crust}, 0.94);
        color: ${c.text};
        border-bottom: 1px solid ${c.surface1};
      }

      /* every readout is transparent and flat: the console look comes from the two-tone
         FIELD:value markup, not from a pill. padding is the only spacing (spacing=0). */
      #workspaces, #window, #clock, #cpu, #memory, #network,
      #pulseaudio, #custom-eorzea, #custom-sep, #tray {
        background: transparent;
        border-radius: 0;
        padding: 0 8px;
        margin: 0;
      }

      /* workspace tape: bare numerals, brightness encodes state (dimmed vs lit accent),
         no animated pill fill, just a lit-vs-dim glyph like a terminal readout. */
      #workspaces button {
        color: ${c.subtext0};
        background: transparent;
        border-radius: 0;
        padding: 0 5px;
        margin: 0;
      }
      #workspaces button.active,
      #workspaces button.focused {
        color: ${c.mauve};
      }
      #workspaces button.urgent {
        color: ${c.red};
      }

      /* dim bracket divider, matching sketchybar sep.app drawn in a surface tone. */
      #custom-sep {
        color: ${c.surface2};
        padding: 0 4px;
      }

      #tray {
        padding: 0 6px;
      }
    '';
  };
}
