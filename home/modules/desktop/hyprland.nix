{
  config,
  lib,
  pkgs,
  ...
}:
let
  c = config.rice.theme.colors;
  hex = name: "rgb(${lib.removePrefix "#" c.${name}})";
  term = "${pkgs.wezterm}/bin/wezterm";
  menu = "${pkgs.wofi}/bin/wofi --show drun";

  # shared lain wallpaper (same file wallpaper.nix hands to osascript on darwin).
  # swww-daemon is started below, but `swww img` fails if it races the socket, so
  # poll `swww query` until the daemon answers, then set the image once.
  setWallpaper = pkgs.writeShellScript "set-wallpaper" ''
    until ${pkgs.swww}/bin/swww query >/dev/null 2>&1; do sleep 0.2; done
    exec ${pkgs.swww}/bin/swww img ${./wallpaper.jpg}
  '';
in
{
  wayland.windowManager.hyprland = {
    enable = true;
    settings = {
      "$mod" = "SUPER";

      exec-once = [
        "${pkgs.swww}/bin/swww-daemon"
        "${setWallpaper}"
        "waybar"
      ];

      monitor = [ ",preferred,auto,1.0" ];

      input = {
        kb_layout = "us";
        follow_mouse = 1;
        touchpad.natural_scroll = true;
      };

      general = {
        gaps_in = 6;
        gaps_out = 10;
        border_size = 2;
        "col.active_border" = hex "mauve";
        "col.inactive_border" = hex "surface0";
        layout = "dwindle";
      };

      decoration = {
        rounding = 10;
        blur = {
          enabled = true;
          size = 6;
          passes = 2;
        };
        shadow = {
          enabled = true;
          range = 12;
          color = hex "crust";
        };
      };

      animations = {
        enabled = true;
        bezier = "ease, 0.25, 0.1, 0.25, 1.0";
        animation = [
          "windows, 1, 4, ease"
          "workspaces, 1, 4, ease"
          "fade, 1, 6, ease"
        ];
      };

      bind = [
        "$mod, Return, exec, ${term}"
        "$mod, Space, exec, ${menu}"
        "$mod SHIFT, Q, killactive,"
        "$mod, F, fullscreen, 0"
        "$mod SHIFT, Space, togglefloating,"
        "$mod, M, exec, ${term} start -- ${pkgs.ncspot}/bin/ncspot"

        "$mod, H, movefocus, l"
        "$mod, J, movefocus, d"
        "$mod, K, movefocus, u"
        "$mod, L, movefocus, r"

        "$mod SHIFT, H, movewindow, l"
        "$mod SHIFT, J, movewindow, d"
        "$mod SHIFT, K, movewindow, u"
        "$mod SHIFT, L, movewindow, r"
      ]
      ++ (builtins.concatMap (n: [
        "$mod, ${toString n}, workspace, ${toString n}"
        "$mod SHIFT, ${toString n}, movetoworkspace, ${toString n}"
      ]) (lib.range 1 9));

      bindm = [
        "$mod, mouse:272, movewindow"
        "$mod, mouse:273, resizewindow"
      ];

      binde = [
        ", XF86AudioRaiseVolume, exec, ${pkgs.wireplumber}/bin/wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+"
        ", XF86AudioLowerVolume, exec, ${pkgs.wireplumber}/bin/wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"
      ];
      bindl = [
        ", XF86AudioMute, exec, ${pkgs.wireplumber}/bin/wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"
      ];
    };
  };
}
