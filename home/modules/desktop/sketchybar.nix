{ pkgs, lib, ... }:
lib.mkIf pkgs.stdenv.hostPlatform.isDarwin {
  xdg.configFile = {
    "sketchybar/sketchybarrc" = {
      source = ../../../sketchybar/sketchybarrc;
      executable = true;
    };
    "sketchybar/colors.sh" = {
      source = ../../../sketchybar/colors.sh;
      executable = true;
    };
    "sketchybar/icon_map.sh" = {
      source = "${pkgs.sketchybar-app-font}/bin/icon_map.sh";
      executable = true;
    };
    "sketchybar/plugins" = {
      source = ../../../sketchybar/plugins;
      recursive = true;
    };
  };
}
