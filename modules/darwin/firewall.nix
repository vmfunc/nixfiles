# system.defaults.alf.* is broken on macOS 15.1+/26 (nix-darwin#1243), drive socketfilterfw directly
{ lib, ... }:
{
  system.activationScripts.postActivation.text = lib.mkAfter ''
    fw=/usr/libexec/ApplicationFirewall/socketfilterfw
    if [ -x "$fw" ]; then
      "$fw" --getglobalstate | grep -q "enabled" || "$fw" --setglobalstate on
      "$fw" --getstealthmode | grep -q "enabled" || "$fw" --setstealthmode on
      "$fw" --setloggingmode on >/dev/null 2>&1 || true
    fi
  '';
}
