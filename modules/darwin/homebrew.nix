{ ... }:
{
  homebrew = {
    enable = true;
    onActivation = {
      autoUpdate = false;
      upgrade = false;
      cleanup = "none";
    };
    taps = [ "dimentium/autoraise" ];
    brews = [
      # one-time per machine: brew trust dimentium/autoraise
      "dimentium/autoraise/autoraise"
      "media-control"
    ];
    casks = [
      "mullvadvpn"
      "zen"
      "chromium"
      "ledger-live"
      "android-studio"
      # NB: NO binary-ninja cask. homebrew only ships `binary-ninja-free`, a separate
      # binary that can't take a license key. the COMMERCIAL build is a manual download
      # from her account (binary.ninja > login > download), installed to /Applications by
      # hand. nix can't manage it; only the theme is declarative (binary-ninja.nix).
      # the Lain CRT terminal; nixpkgs won't build ghostty on darwin, so brew it and let
      # home-manager manage its config (home/modules/terminal/ghostty.nix, package = null).
      "ghostty"
      # apple music -> discord rich presence; autostart + rationale in
      # home/modules/desktop/music-presence.nix
      "music-presence"
      # no openzfs: kext panics macOS 26 (SPTM)
    ];
  };
}
