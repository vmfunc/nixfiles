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
      # no openzfs: kext panics macOS 26 (SPTM)
    ];
  };
}
