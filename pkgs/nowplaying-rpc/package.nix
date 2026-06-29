# nowplaying-rpc: macOS Now Playing -> Discord rich presence (with iTunes cover
# art). reads the system-wide now-playing surface via the `media-control` brew, so
# it covers browser audio (SoundCloud in Zen), Apple Music, Spotify, everything,
# not just Apple Music like music-presence. full rationale + the client-id
# requirement are in nowplaying_rpc.py; autostart in
# home/modules/desktop/nowplaying-rpc.nix.
#
# media-control is intentionally NOT a build input: it is a homebrew binary
# (modules/darwin/homebrew.nix), resolved at runtime by absolute path inside the
# script. only pypresence (Discord IPC) comes from nixpkgs.
{
  lib,
  stdenvNoCC,
  python3,
  makeWrapper,
}:
let
  pythonEnv = python3.withPackages (ps: [ ps.pypresence ]);
in
stdenvNoCC.mkDerivation {
  pname = "nowplaying-rpc";
  version = "0.1.0";

  src = ./.;
  nativeBuildInputs = [ makeWrapper ];

  installPhase = ''
    runHook preInstall
    install -Dm644 nowplaying_rpc.py "$out/libexec/nowplaying_rpc.py"
    makeWrapper "${pythonEnv}/bin/python3" "$out/bin/nowplaying-rpc" \
      --add-flags "$out/libexec/nowplaying_rpc.py"
    runHook postInstall
  '';

  meta = {
    description = "macOS Now Playing -> Discord rich presence with album art.";
    platforms = lib.platforms.darwin;
    mainProgram = "nowplaying-rpc";
  };
}
