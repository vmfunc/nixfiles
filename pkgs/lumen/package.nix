# lumen: music-reactive desktop wallpaper (Metal flow-field + ScreenCaptureKit audio).
#
# shipped as a real .app bundle, NOT a bare binary, on purpose: ScreenCaptureKit needs
# the Screen Recording TCC grant, and a bare binary can only ever inherit that from a
# parent that already holds it (a terminal), so it works by hand but a launchd agent
# silently denies. a bundle has its own code identity, so macOS can prompt for it once
# (`open -a Lumen`) and persist the grant, and the launchd instance inherits it by
# identity. ad-hoc signed, so the cdhash changes each build => one re-grant per update.
{
  lib,
  stdenv,
  apple-sdk_15,
  darwinMinVersionHook,
}:
stdenv.mkDerivation {
  pname = "lumen";
  version = "0.1.0";
  src = ./.;

  buildInputs = [
    apple-sdk_15
    # SCStream audio + excludesCurrentProcessAudio are macos 13+; pin the target so it
    # does not fall back to the stdenv default
    (darwinMinVersionHook "13.0")
  ];

  buildPhase = ''
    runHook preBuild
    $CC -O2 -Wall -fobjc-arc ./main.m -o lumen \
      -DLUMEN_SHADER_PATH="\"$out/Applications/Lumen.app/Contents/Resources/shader.metal\"" \
      -framework AppKit -framework Foundation -framework Accelerate \
      -framework Metal -framework MetalKit -framework QuartzCore \
      -framework CoreGraphics -framework CoreMedia -framework ScreenCaptureKit
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    app="$out/Applications/Lumen.app"
    mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
    install -Dm755 lumen "$app/Contents/MacOS/lumen"
    install -Dm644 shader.metal "$app/Contents/Resources/shader.metal"

    # body kept flat at the base indent so the nix indented-string strip leaves it clean
    cat > "$app/Contents/Info.plist" <<'PLIST'
    <?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
    <plist version="1.0">
    <dict>
    <key>CFBundleIdentifier</key><string>re.vmfunc.lumen</string>
    <key>CFBundleName</key><string>Lumen</string>
    <key>CFBundleExecutable</key><string>lumen</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>0.1.0</string>
    <key>CFBundleVersion</key><string>0.1.0</string>
    <key>LSMinimumSystemVersion</key><string>13.0</string>
    <key>LSUIElement</key><true/>
    <key>NSScreenCaptureUsageDescription</key>
    <string>Lumen reads system audio levels to animate the desktop wallpaper.</string>
    </dict>
    </plist>
    PLIST

    # the darwin stdenv fixup ad-hoc signs the inner Mach-O; combined with the Info.plist
    # bundle id that gives TCC a stable identity to prompt against within this build.

    # expose the inner binary on PATH for the one-time foreground grant and debugging
    mkdir -p "$out/bin"
    ln -s "$app/Contents/MacOS/lumen" "$out/bin/lumen"
    runHook postInstall
  '';

  meta = {
    description = "music-reactive metal flow-field desktop wallpaper";
    platforms = lib.platforms.darwin;
    mainProgram = "lumen";
  };
}
