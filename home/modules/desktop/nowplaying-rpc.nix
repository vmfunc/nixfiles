# nowplaying-rpc autostart: macOS Now Playing -> Discord rich presence.
# the daemon lives in pkgs/nowplaying-rpc; this module owns the rice.nowPlayingRpc
# option tree and the launchd agent that runs it at login.
#
# FAIL-CLOSED: the daemon needs a Discord application client id (the IPC handshake
# demands one) and refuses to start without it, so the agent is only enabled once
# rice.nowPlayingRpc.clientId is set. ships inert until azzie drops her id in,
# same discipline as the auto-update netrc gate. the local IPC socket comes from
# Vesktop's bundled arRPC (home/modules/desktop/vesktop.nix), like music-presence.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.rice.nowPlayingRpc;
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
    excludeBundleIds = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ "com.apple.Music" ];
      description = ''
        macOS bundle ids whose playback this daemon ignores, to avoid two tools
        fighting one presence. Apple Music is excluded by default because
        music-presence already owns it.
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
      '';
    };
  };

  config = lib.mkIf (cfg.enable && cfg.clientId != "") {
    launchd.agents.nowplaying-rpc = {
      enable = true;
      config = {
        ProgramArguments = [ (lib.getExe pkgs.nowplaying-rpc) ];
        EnvironmentVariables = {
          NOWPLAYING_RPC_CLIENT_ID = cfg.clientId;
          NOWPLAYING_RPC_EXCLUDE_BUNDLES = lib.concatStringsSep "," cfg.excludeBundleIds;
          NOWPLAYING_RPC_UPLOAD_ARTWORK = if cfg.uploadArtwork then "1" else "0";
        };
        # a real long-lived daemon (unlike the `open`-and-fork agents): keep it
        # alive so a crash or a Discord restart is recovered. it already retries
        # the connect loop internally, so KeepAlive is just the outer backstop.
        RunAtLoad = true;
        KeepAlive = true;
        StandardOutPath = "${config.home.homeDirectory}/Library/Logs/nowplaying-rpc.log";
        StandardErrorPath = "${config.home.homeDirectory}/Library/Logs/nowplaying-rpc.log";
      };
    };
  };
}
