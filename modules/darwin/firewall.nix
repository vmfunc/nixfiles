# system.defaults.alf.* is broken on macOS 15.1+/26 (nix-darwin#1243), drive socketfilterfw directly
{ lib, pkgs, ... }:
{
  # mkAfter: no hard dep, just deterministic ordering after activation.nix's defaults flush
  system.activationScripts.postActivation.text = lib.mkAfter ''
    fw=/usr/libexec/ApplicationFirewall/socketfilterfw
    grep=${pkgs.gnugrep}/bin/grep
    if [ -x "$fw" ]; then
      "$fw" --getglobalstate | "$grep" -q "enabled" || "$fw" --setglobalstate on || true
      # macOS 26 prints "stealth mode is on", older printed "enabled"; match both
      "$fw" --getstealthmode | "$grep" -Eq "enabled|is on" || "$fw" --setstealthmode on || true
      "$fw" --setloggingmode on >/dev/null 2>&1 || true
    fi
  '';
}
