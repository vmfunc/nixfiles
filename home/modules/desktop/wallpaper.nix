{
  pkgs,
  lib,
  inputs,
  theme,
  config,
  ...
}:
let
  wallpaper = "${inputs.wallpapers}/${theme.wallpaperFile}";

  # tiny NSWorkspace helper. WHY not `osascript -> System Events`: that AppleEvent
  # needs Automation TCC and times out / fails when activation runs headless (over
  # SSH, and during the hourly auto-update). a process setting its OWN desktop via
  # NSWorkspace needs no permission, so a login agent applies it reliably.
  setWallpaper = pkgs.stdenv.mkDerivation {
    pname = "set-wallpaper";
    version = "1.0";
    dontUnpack = true;
    buildPhase = ''
      $CC -fobjc-arc -O2 -framework Cocoa ${./set-wallpaper.m} -o set-wallpaper
    '';
    installPhase = ''
      mkdir -p $out/bin
      cp set-wallpaper $out/bin/set-wallpaper
    '';
  };
in
lib.mkIf pkgs.stdenv.hostPlatform.isDarwin {
  # apply the desktop picture in the user's GUI session at login. RunAtLoad
  # one-shot (no KeepAlive); re-runs on each generation so a changed wallpaper
  # input is picked up, and re-running is harmless.
  launchd.agents.set-wallpaper = {
    enable = true;
    config = {
      ProgramArguments = [
        "${setWallpaper}/bin/set-wallpaper"
        wallpaper
      ];
      RunAtLoad = true;
      ProcessType = "Background";
      StandardErrorPath = "${config.home.homeDirectory}/Library/Logs/set-wallpaper.log";
      StandardOutPath = "${config.home.homeDirectory}/Library/Logs/set-wallpaper.log";
    };
  };
}
