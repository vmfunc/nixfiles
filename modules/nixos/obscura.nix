# obscura vpn for the linux boxes (rice.obscura.*), default OFF, switched on per
# host. upstream ships deb/rpm/pacman only, no nixpkgs package and no nixos
# module, but their client repo IS a flake (inputs.obscura) exposing the two
# linux binaries: `obscura` (cli + the `obscura service` daemon, one binary) and
# `obscura-gui` (gtk4/webkit shell over the same service). the unit below mirrors
# upstream's linux/common/obscura.service, nix-ified: StateDirectory instead of
# packaging-time mkdir, and the group from users.groups instead of sysusers.
# THREAT MODEL: the daemon runs as root (tun + routes); the /run/obscura.sock
# control socket is group-gated (the binary chowns it to `obscura`, UMask 0007
# keeps it 0660), so cli/gui work unprivileged via group membership. /var/lib/
# obscura holds the account token, hence 0750 root:obscura, not world-readable.
{
  config,
  lib,
  pkgs,
  inputs,
  username,
  ...
}:
let
  cfg = config.rice.obscura;
  obscuraPkgs = inputs.obscura.packages.${pkgs.stdenv.hostPlatform.system};
  cli = obscuraPkgs.rust-cli-bin;
  gui = obscuraPkgs.rust-gui-bin;

  # upstream's desktop entry + icons, re-pointed at the store path: the flake
  # only builds bare binaries, the launcher glue lives in their linux/common.
  guiLauncher = pkgs.runCommand "obscura-gui-launcher" { } ''
    install -Dm644 ${inputs.obscura}/linux/common/net.obscura.vpn.gui.desktop \
      $out/share/applications/net.obscura.vpn.gui.desktop
    substituteInPlace $out/share/applications/net.obscura.vpn.gui.desktop \
      --replace-fail "Exec=obscura-gui" "Exec=${lib.getExe gui}"
    install -Dm644 ${inputs.obscura}/linux/common/icons/net.obscura.vpn.gui-128.png \
      $out/share/icons/hicolor/128x128/apps/net.obscura.vpn.gui.png
    install -Dm644 ${inputs.obscura}/linux/common/icons/net.obscura.vpn.gui-256.png \
      $out/share/icons/hicolor/256x256/apps/net.obscura.vpn.gui.png
  '';
in
{
  options.rice.obscura.enable = lib.mkEnableOption "obscura vpn (service + cli + gui)";

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [
      cli
      gui
      guiLauncher
    ];

    # socket access group; the daemon resolves this name at runtime to chown
    # /run/obscura.sock, so it must exist even though nothing runs as it.
    users.groups.obscura = { };
    users.users.${username}.extraGroups = [ "obscura" ];

    systemd.services.obscura = {
      description = "Obscura VPN";
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];
      # upstream: retry forever with stepped backoff, never rate-limit into a
      # dead vpn on flaky travel wifi (which is exactly where this box lives).
      startLimitIntervalSec = 0;
      serviceConfig = {
        Type = "notify";
        ExecStart = "${lib.getExe cli} service";
        # upstream keeps live fds across restarts so an upgrade/crash does not
        # drop the tunnel.
        FileDescriptorStoreMax = 8;
        Group = "obscura";
        UMask = "0007";
        Restart = "always";
        RestartSec = 1;
        RestartSteps = 5;
        RestartMaxDelaySec = 30;
        StateDirectory = "obscura";
        StateDirectoryMode = "0750";
      };
    };
  };
}
