# the tv-off close animation from burn-my-windows, kwin 6 port only. upstream
# ships each effect as a prebuilt kpackage tarball per release (the kwin
# effects are js + glsl, no compilation, so this is NOT abi-locked to a kwin
# version the way compiled effects are). installed via home.packages, kwin
# finds it through XDG_DATA_DIRS; enabled by desktop/plasma.nix
# (kwinrc [Plugins] kwin6_effect_tvEnabled).
{ stdenvNoCC, fetchurl }:
stdenvNoCC.mkDerivation {
  pname = "burn-my-windows-tv";
  version = "48";

  src = fetchurl {
    url = "https://github.com/Schneegans/Burn-My-Windows/releases/download/v48/kwin6_effect_tv.tar.gz";
    hash = "sha256-+sNEDBnk/3RqT+WNtHx684c81StNxYACiFS1ch3Z8mw=";
  };

  # the tarball is the kpackage's bare payload (metadata.json + contents/), no
  # top-level dir, so name the two members explicitly: sourceRoot "." would
  # also sweep stdenv's own build-dir droppings (env-vars) into the store.
  sourceRoot = ".";

  installPhase = ''
    runHook preInstall
    mkdir -p "$out/share/kwin/effects/kwin6_effect_tv"
    cp -r contents metadata.json "$out/share/kwin/effects/kwin6_effect_tv/"
    runHook postInstall
  '';

  meta = {
    description = "burn-my-windows tv-off window close effect for kwin 6";
    homepage = "https://github.com/Schneegans/Burn-My-Windows";
  };
}
