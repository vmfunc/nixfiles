# lumen: music-reactive desktop wallpaper (Metal flow-field + ScreenCaptureKit audio).
# bare Mach-O binary, no .app bundle: launchd runs it as an accessory GUI agent and
# the screen-recording TCC grant attaches to the binary itself, exactly like `record`.
# the shader lives beside the binary in the store and is compiled at runtime, so its
# path is baked in at build time.
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
    # SCStream audio + excludesCurrentProcessAudio are macos 13+; pin the target so
    # it does not fall back to the stdenv default
    (darwinMinVersionHook "13.0")
  ];

  buildPhase = ''
    runHook preBuild
    $CC -O2 -Wall -fobjc-arc ./main.m -o lumen \
      -DLUMEN_SHADER_PATH="\"$out/share/lumen/shader.metal\"" \
      -framework AppKit -framework Foundation -framework Accelerate \
      -framework Metal -framework MetalKit -framework QuartzCore \
      -framework CoreGraphics -framework CoreMedia -framework ScreenCaptureKit
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    install -Dm755 lumen "$out/bin/lumen"
    install -Dm644 shader.metal "$out/share/lumen/shader.metal"
    runHook postInstall
  '';

  meta = {
    description = "music-reactive metal flow-field desktop wallpaper";
    platforms = lib.platforms.darwin;
    mainProgram = "lumen";
  };
}
