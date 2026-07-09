# retro / old-school role, gated behind rice.retro.enable (default off). console
# + PC emulation, plus the old-net toys (CRT terminal, MUD + BBS clients) that
# fit the lain/copland rice. separate from rice.gaming on purpose: gaming is the
# steam/proton stack, this is the emulation + retro-computing corner, so either
# can be flipped without the other. deps: none beyond nixpkgs; enabled on tuna.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.rice.retro;
in
{
  options.rice.retro.enable = lib.mkEnableOption "console/PC emulation + retro-computing toys";

  config = lib.mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      # emulation. the `retroarch` attr is the with-cores build (unified frontend
      # for the 8/16-bit era + handhelds + PS1, libretro cores bundled), so the
      # standalones below are only the ones whose native build clearly beats the core.
      retroarch
      dolphin-emu # gamecube / wii
      pcsx2 # ps2
      ppsspp # psp
      melonds # nintendo ds
      # PC classics: scummvm runs the point-and-click adventures, dosbox-staging
      # is the maintained DOS box (better audio/scaling than upstream dosbox).
      scummvm
      dosbox-staging
      # japanese retro computing (the eroge/doujin/RPG heritage machines).
      # np2kai = PC-9801 (the platform that WAS japanese PC gaming); openmsx =
      # MSX (konami + doujin catalog). X68000 / FM-TOWNS have no nix package.
      np2kai
      openmsx

      # retro-computing / old-net. cool-retro-term is the CRT terminal (amber +
      # green built-in profiles match the copland/blood variants; a custom blood
      # profile is a GUI save, not a config file, its profile format is a baked
      # QML blob). blightmud = scriptable MUD client for the text-MUD era;
      # syncterm = telnet/ssh BBS terminal for the boards that are still up.
      cool-retro-term
      blightmud
      syncterm

      # the small-web / scene corner (the actual "Wired" protocols + demoscene
      # texture). amfora = gemini:// TUI browser, sacc = suckless gopher:// client,
      # ansilove renders .ans/.nfo BBS/scene art (pairs with syncterm downloads),
      # cbonsai = a slow-growing ambient terminal toy next to cmatrix/pipes-rs.
      amfora
      sacc
      ansilove
      cbonsai

      # doujin / retro game runtimes (the hikikomori library heritage). renpy runs
      # ren'py visual novels; onscripter runs the NScripter corpus (Tsukihime,
      # Umineko fan-releases, countless doujin VNs); easyrpg-player runs RPG Maker
      # 2000/2003 games. the games are downloaded, these are the engines that boot them.
      renpy
      onscripter
      easyrpg-player
    ];
  };
}
