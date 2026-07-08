# nowplaying-rpc autostart, LINUX leg (tuna): MPRIS -> Discord rich presence.
# the darwin twin (home/modules/desktop/nowplaying-rpc.nix) owns the launchd agent
# and reads the macOS Now Playing surface; this one runs the SAME daemon as a
# systemd user unit on graphical-session.target and lets the daemon poll MPRIS via
# playerctl instead (the OS switch lives in pkgs/nowplaying-rpc/nowplaying_rpc.py).
#
# two separate modules, not one cross-platform file, because the option TREE differs
# (excludeBundleIds is a macOS bundle-id concept with no MPRIS analogue) and the two
# supervisors are disjoint (launchd vs systemd). they are never imported together:
# desktop-darwin.nix imports the darwin one, desktop-linux.nix imports this one, so
# each is the sole owner of rice.nowPlayingRpc within its platform's import set. the
# config block is still gated on !isDarwin as a belt-and-braces guard.
#
# FAIL-CLOSED: like the darwin twin, the daemon needs a Discord application client
# id and refuses to start without one, so the unit is only enabled once
# rice.nowPlayingRpc.clientId is set. the local IPC socket comes from whatever
# Discord client is running (Vesktop's bundled arRPC).
#
# cross-file deps: pkgs/nowplaying-rpc owns the daemon + the playerctl leg;
# desktop-linux.nix imports this module and sets rice.nowPlayingRpc.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.rice.nowPlayingRpc;
  isDarwin = pkgs.stdenv.hostPlatform.isDarwin;
in
{
  options.rice.nowPlayingRpc = {
    enable = lib.mkEnableOption "Now Playing -> Discord rich presence daemon";
    clientId = lib.mkOption {
      type = lib.types.str;
      default = "";
      example = "1390000000000000000";
      description = ''
        Discord application client id used for the rich-presence handshake. NOT a
        secret (it is a public application id), so it lives in the clear here, not
        in sops. the daemon stays inert while this is empty. the activity shows as
        "Listening to <that application's name>".
      '';
    };
    uploadArtwork = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        For tracks with no public catalog cover (SoundCloud uploads, ...), host the
        player-provided art bytes on litterbox (an ephemeral third-party file host,
        1h auto-expiry) so Discord can show it. PRIVACY: this leaks cover art +
        listening timing to that host. off by default; opt in deliberately.

        NOTE: on linux the playerctl leg does not currently extract raw art bytes
        from MPRIS, so this only affects the catalog-lookup fallback path; it is
        kept for option-tree parity with the darwin twin.
      '';
    };
  };

  config = lib.mkIf (!isDarwin && cfg.enable && cfg.clientId != "") {
    systemd.user.services.nowplaying-rpc = {
      Unit = {
        Description = "Now Playing (MPRIS) -> Discord rich presence";
        PartOf = [ "graphical-session.target" ];
        After = [ "graphical-session.target" ];
      };
      Service = {
        # playerctl must be on PATH: the daemon shells out to it by bare name.
        ExecStart = "${lib.getExe pkgs.nowplaying-rpc}";
        Environment = [
          "NOWPLAYING_RPC_CLIENT_ID=${cfg.clientId}"
          "NOWPLAYING_RPC_UPLOAD_ARTWORK=${if cfg.uploadArtwork then "1" else "0"}"
          "PATH=${lib.makeBinPath [ pkgs.playerctl ]}"
        ];
        # long-lived daemon with its own internal connect-retry loop; Restart is the
        # outer backstop for a hard crash or a Discord restart, same as the mac's
        # KeepAlive. a short delay avoids a hot loop if it dies immediately.
        Restart = "always";
        RestartSec = 5;
      };
      Install.WantedBy = [ "graphical-session.target" ];
    };
  };
}
