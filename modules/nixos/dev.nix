# dev runtimes, gated behind rice.dev.enable (default off). the container stack
# (docker daemon + compose v2) plus the node/npm runtime that tuna was missing,
# so docker-compose projects (e.g. ~/workspace/scry: web/api/worker/postgres/
# redis) actually boot. python3 already ships in the base system; bun is a home
# package. deps: username (docker group membership) threaded from mkNixos.
{
  config,
  lib,
  pkgs,
  username,
  ...
}:
let
  cfg = config.rice.dev;
in
{
  options.rice.dev.enable = lib.mkEnableOption "container runtime (docker + compose) and node/npm dev toolchain";

  config = lib.mkIf cfg.enable {
    # rootful docker with the compose v2 plugin (the `docker compose` subcommand,
    # not the legacy standalone `docker-compose`). autoPrune keeps the strix-halo
    # nvme from silting up with dead layers on a box that rebuilds stacks often.
    virtualisation.docker = {
      enable = true;
      autoPrune = {
        enable = true;
        dates = "weekly";
      };
    };

    # docker socket is root-owned; the group grants non-sudo `docker` access. this
    # is the standard trade (docker group == root-equivalent), acceptable on a
    # single-user box already behind key-only ssh + passwordless wheel.
    users.users.${username}.extraGroups = [ "docker" ];

    environment.systemPackages = with pkgs; [
      docker-compose
      nodejs
      # node ships npm; pnpm/yarn via corepack are enabled per-project, not global.
    ];
  };
}
