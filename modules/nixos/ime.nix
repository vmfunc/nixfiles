# japanese input, gated behind rice.ime.enable (default off). fcitx5 + mozc
# (google japanese). WHY system-layer and not a home package: i18n.inputMethod
# wires the IME env vars (GTK_IM_MODULE/QT_IM_MODULE/XMODIFIERS) into the session
# and the fcitx5 wayland input-method protocol; a home package alone would install
# the binary but nothing would route keystrokes through it. deps: none; enabled on
# tuna (JP PSO2 + JP tv + immersion). toggle input with the fcitx5 default hotkey
# (ctrl+space), configure engines with fcitx5-configtool.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.rice.ime;
in
{
  options.rice.ime.enable = lib.mkEnableOption "fcitx5 + mozc japanese input method";

  config = lib.mkIf cfg.enable {
    i18n.inputMethod = {
      enable = true;
      type = "fcitx5";
      fcitx5.addons = with pkgs; [
        # mozc-ut variant: bundles the UT dictionaries (neologd net-slang + memes,
        # jawiki, place/personal names, sudachi) so proper nouns, otaku slang and
        # net vocab actually convert. plain fcitx5-mozc if you want the vanilla dict.
        fcitx5-mozc-ut
        fcitx5-gtk # gtk client so gtk apps (zen, gimp, nautilus) get the IME
        kdePackages.fcitx5-configtool # GUI to arrange engines + hotkeys
      ];
      # niri is wayland: prefer the wayland text-input protocol, and let fcitx5
      # own the frontend rather than exporting the legacy X modules everywhere.
      fcitx5.waylandFrontend = true;
    };
  };
}
