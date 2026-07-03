{ ... }:
{
  homebrew = {
    enable = true;
    onActivation = {
      autoUpdate = false;
      upgrade = false;
      # deliberate non-default: "zap" would delete hand-installed brews nix knows nothing about
      cleanup = "none";
    };
    taps = [ "dimentium/autoraise" ];
    brews = [
      # TODO(deploy): brew trust dimentium/autoraise (once per machine)
      "dimentium/autoraise/autoraise"
      "media-control"
    ];
    casks = [
      "mullvadvpn"
      "zen"
      # not notarized; gatekeeper quarantine stripped in modules/darwin/activation.nix
      "chromium"
      "ledger-live"
      "android-studio"
      # UniFi Endpoint (Ubiquiti UniFi Identity): one-click WiFi/VPN to the home
      # network without entering creds. cask name is unifi-identity-endpoint.
      "unifi-identity-endpoint"
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
