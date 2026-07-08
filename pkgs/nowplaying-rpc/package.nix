# nowplaying-rpc: now-playing track info -> Discord rich presence (with iTunes
# cover art). the Discord IPC half is cross-platform; the metadata source forks by
# OS inside nowplaying_rpc.py: macOS reads the system Now Playing surface via the
# `media-control` brew (covers browser SoundCloud, Apple Music, Spotify, ...),
# linux polls MPRIS via `playerctl`. full rationale + the client-id requirement
# are in nowplaying_rpc.py; autostart in home/modules/desktop/nowplaying-rpc.nix
# (darwin launchd) and nowplaying-rpc-linux.nix (systemd user unit).
#
# neither metadata backend is a build input: media-control is a homebrew binary
# (modules/darwin/homebrew.nix), playerctl is put on PATH by the linux systemd
# unit. both are resolved at runtime, so only pypresence (Discord IPC) comes from
# nixpkgs and the derivation stays platform-agnostic.
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
    description = "Now Playing -> Discord rich presence with album art (macOS + linux).";
    # darwin (media-control) + linux (playerctl/MPRIS); the derivation itself is
    # pure python + pypresence, so both platforms build identically.
    platforms = lib.platforms.darwin ++ lib.platforms.linux;
    mainProgram = "nowplaying-rpc";
  };
}
