# waybar for the niri desktop (tuna). themed from rice.theme.colors so the
# bar follows the active variant; the eorzea module mirrors sketchybar/plugins/eorzea.sh
# (same unix*3600/175 math) so both bars agree on ET. started by its systemd user unit
# via graphical-session.target, not niri spawn-at-startup (see niri.nix).
{
  config,
  lib,
  pkgs,
  ...
}:
let
  c = config.rice.theme.colors;

  # 1 ET day = 70 real minutes, ET seconds = unix * 3600/175
  eorzea = pkgs.writeShellScript "waybar-eorzea" ''
    ET=$(( $(date +%s) * 3600 / 175 ))
    EH=$((ET / 3600 % 24)); EM=$((ET / 60 % 60))
    if [ "$EH" -ge 6 ] && [ "$EH" -lt 18 ]; then ICON=""; else ICON=""; fi
    printf '%s %02d:%02d ET\n' "$ICON" "$EH" "$EM"
  '';
in
{
  programs.waybar = {
    enable = true;
    systemd.enable = true;

    settings.mainBar = {
      layer = "top";
      position = "top";
      height = 34;
      margin-top = 6;
      margin-left = 8;
      margin-right = 8;
      spacing = 6;

      modules-left = [
        "niri/workspaces"
        "niri/window"
      ];
      modules-center = [ "clock" ];
      modules-right = [
        "custom/eorzea"
        "cpu"
        "memory"
        "network"
        "pulseaudio"
        "tray"
      ];

      "niri/workspaces".format = "{index}";
      "niri/window".max-length = 48;
      clock = {
        format = "{:%H:%M}";
        format-alt = "{:%a %d %b}";
        tooltip-format = "<tt><small>{calendar}</small></tt>";
      };
      "custom/eorzea" = {
        exec = "${eorzea}";
        interval = 20;
        tooltip = false;
      };
      cpu = {
        format = " {usage}%";
        interval = 3;
      };
      memory = {
        format = " {percentage}%";
        interval = 5;
      };
      network = {
        format-wifi = "  {bandwidthDownBytes}";
        format-ethernet = " {bandwidthDownBytes}";
        format-disconnected = "睊";
        interval = 3;
        tooltip-format = "{ifname}: {ipaddr}";
      };
      pulseaudio = {
        format = "{icon} {volume}%";
        format-muted = " muted";
        format-icons.default = [
          ""
          ""
          ""
        ];
        on-click = "${pkgs.pavucontrol}/bin/pavucontrol";
      };
      tray.spacing = 8;
    };

    style = ''
      * {
        font-family: "JetBrainsMono Nerd Font", "Symbols Nerd Font";
        font-size: 13px;
        font-weight: 600;
        min-height: 0;
      }
      window#waybar {
        background: transparent;
        color: ${c.text};
      }
      .modules-left, .modules-center, .modules-right { margin: 0 4px; }

      #workspaces, #window, #clock, #custom-eorzea, #cpu, #memory,
      #network, #pulseaudio, #tray {
        background: ${c.surface0};
        border-radius: 8px;
        padding: 2px 10px;
        margin: 4px 2px;
      }

      #workspaces button {
        color: ${c.subtext0};
        padding: 0 6px;
        border-radius: 6px;
      }
      #workspaces button.active {
        color: ${c.crust};
        background: ${c.mauve};
      }
      #workspaces button.urgent { color: ${c.red}; }

      #clock { color: ${c.blue}; }
      #custom-eorzea { color: ${c.subtext0}; }
      #cpu { color: ${c.peach}; }
      #memory { color: ${c.green}; }
      #network { color: ${c.sky}; }
      #pulseaudio { color: ${c.sky}; }
      #window { color: ${c.lavender}; }
    '';
  };
}
