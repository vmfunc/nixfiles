# postActivation steps with no nix-darwin option: activateSettings -u flushes the
# system.defaults written by defaults.nix without a logout; the quarantine strip
# pairs with the chromium cask in homebrew.nix.
{ username, ... }:
{
  system.activationScripts.postActivation.text = ''
    echo "applying system defaults for ${username}..."
    /System/Library/PrivateFrameworks/SystemAdministration.framework/Resources/activateSettings -u || true

    # brew chromium isn't notarized; strip quarantine or gatekeeper says "damaged"
    if [ -d "/Applications/Chromium.app" ]; then
      echo "clearing Gatekeeper quarantine on Chromium..."
      /usr/bin/xattr -dr com.apple.quarantine "/Applications/Chromium.app" 2>/dev/null || true
    fi
  '';
}
