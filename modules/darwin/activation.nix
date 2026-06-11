{ username, ... }:
{
  system.activationScripts.postActivation.text = ''
    echo "applying system defaults for ${username}..."
    sudo -u ${username} /System/Library/CoreServices/menuextra/textinput.menu >/dev/null 2>&1 || true
    /System/Library/PrivateFrameworks/SystemAdministration.framework/Resources/activateSettings -u || true

    # brew chromium isn't notarized; strip quarantine or gatekeeper says "damaged"
    if [ -d "/Applications/Chromium.app" ]; then
      echo "clearing Gatekeeper quarantine on Chromium..."
      /usr/bin/xattr -dr com.apple.quarantine "/Applications/Chromium.app" 2>/dev/null || true
    fi
  '';
}
