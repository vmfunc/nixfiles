# switch-rpc: Discord rich presence while `just switch` runs. the wrapper lives
# in pkgs/switch-rpc; the justfile switch recipe execs through it ONLY when it
# is on PATH, so a host that has never activated still bootstraps bare. this
# module is that PATH gate: it installs the wrapper with the client id baked in
# (no shell-integration dependency, works from any shell).
#
# cross-file deps: pkgs/switch-rpc (wrapper + fail-open rationale), justfile
# (the switch recipe), home/profiles/base.nix (imports + enables this).
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.rice.switchRpc;
in
{
  options.rice.switchRpc = {
    enable = lib.mkEnableOption "Discord rich presence around `just switch`";
    clientId = lib.mkOption {
      type = lib.types.str;
      default = "";
      example = "1390000000000000000";
      description = ''
        Discord application client id for the presence handshake. NOT a secret
        (it is a public application id), same rationale as
        rice.nowPlayingRpc.clientId. while empty the wrapper still runs the
        rebuild, just without presence (fail-open). the activity renders as
        "Playing <that application's name>", so name the app accordingly.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [ (pkgs.switch-rpc.override { inherit (cfg) clientId; }) ];
  };
}
