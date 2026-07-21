# switch-rpc: wraps a command (the justfile `switch` recipe) in a Discord rich
# presence for the duration of the rebuild. FAIL-OPEN: any Discord-side failure
# degrades to running the command bare; full rationale in switch_rpc.py.
# autostart is not a thing here (it is a one-shot wrapper, not a daemon); the
# PATH wiring + client id live in home/modules/cli/switch-rpc.nix.
{
  lib,
  stdenvNoCC,
  python3,
  makeWrapper,
  # public Discord application id baked into the wrapper (NOT a secret, same
  # rationale as rice.nowPlayingRpc.clientId). baked rather than exported by a
  # shell so the presence works from ANY shell that can see the binary;
  # SWITCH_RPC_CLIENT_ID in the environment still wins for ad-hoc testing.
  clientId ? "",
}:
let
  pythonEnv = python3.withPackages (ps: [ ps.pypresence ]);
in
stdenvNoCC.mkDerivation {
  pname = "switch-rpc";
  version = "0.1.0";

  src = ./.;
  nativeBuildInputs = [ makeWrapper ];

  installPhase = ''
    runHook preInstall
    install -Dm644 switch_rpc.py "$out/libexec/switch_rpc.py"
    makeWrapper "${pythonEnv}/bin/python3" "$out/bin/switch-rpc" \
      --add-flags "$out/libexec/switch_rpc.py" \
      ${lib.optionalString (
        clientId != ""
      ) "--set-default SWITCH_RPC_CLIENT_ID ${lib.escapeShellArg clientId}"}
    runHook postInstall
  '';

  meta = {
    description = "Discord rich presence around `just switch` (fail-open command wrapper).";
    # pure python + pypresence; the wrapped command decides the platform.
    platforms = lib.platforms.darwin ++ lib.platforms.linux;
    mainProgram = "switch-rpc";
  };
}
