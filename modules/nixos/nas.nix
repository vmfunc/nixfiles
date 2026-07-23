# nas: auto-mount the home NAS (UniFi UNAS Pro at 192.168.1.89, SMB only:
# afp/nfs/rsync are all closed on it, verified by portscan 2026-07-23) and
# optionally keep ~/workspace two-way synced onto its `workspace` share.
#
# why systemd automounts and not otter's poll-and-mount agent: tuna is a fixed
# desktop on the home LAN, not a roaming laptop. x-systemd.automount mounts a
# share lazily on first access and idles it back off, and soft+nofail keep a
# dead NAS from hanging io or boot, so otter's reachability polling is
# unnecessary here.
#
# cross-file deps:
#   - secrets/smb.yaml (sops): the share password, rendered into a root-only
#     mount.cifs credentials file via sops.templates. never in the nix store.
#   - modules/nixos/default.nix wires the SYSTEM sops-nix module + age key this
#     leans on (mounts are kernel-side, home-level sops cannot serve them).
#   - enabled per-host (hosts/tuna).
{
  config,
  lib,
  pkgs,
  username,
  ...
}:
let
  cfg = config.rice.nas;
  workspaceMount = "${cfg.mountBase}/workspace";
  home = "/home/${username}";

  # unison, not rsync: "sync" here means two-way (edits on either side land on
  # the other, deletes propagate). -prefer newer resolves conflicts by mtime;
  # unison's default confirmbigdel aborts the batch if a whole root vanishes,
  # so a half-dead mount can never bulk-delete the local tree. -perms 0 +
  # -dontchmod because cifs has no real unix perms to agree on.
  syncScript = pkgs.writeShellScript "nas-workspace-sync" ''
    set -eu
    # RequiresMountsFor already pulled the automount in; re-check anyway so a
    # racing unmount can never sync against an empty mountpoint dir
    ${pkgs.util-linux}/bin/mountpoint -q ${workspaceMount} || exit 0
    exec ${pkgs.unison}/bin/unison ${home}/workspace ${workspaceMount} \
      -batch -auto -ui text \
      -prefer newer -times \
      -perms 0 -dontchmod \
      -fastcheck true
  '';
in
{
  options.rice.nas = {
    enable = lib.mkEnableOption "auto-mount the home NAS SMB shares via systemd automounts";

    server = lib.mkOption {
      type = lib.types.str;
      default = "192.168.1.89";
      description = "Home NAS host/IP.";
    };

    username = lib.mkOption {
      type = lib.types.str;
      default = "quaver";
      description = "SMB username for the shares.";
    };

    shares = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      # every user share the NAS exports (enumerated live 2026-07-23).
      # Personal-Drive is deliberately absent: that volume belongs to the UniFi
      # Drive app, which manages it itself.
      default = [
        "quaver"
        "shared"
        "archives"
        "re"
        "workspace"
      ];
      description = "Share names to mount under mountBase.";
    };

    mountBase = lib.mkOption {
      type = lib.types.str;
      default = "/mnt/nas";
      description = "Parent dir the shares mount under (also symlinked as ~/nas).";
    };

    workspaceSync = {
      enable = lib.mkEnableOption "two-way sync of ~/workspace onto the NAS workspace share";

      interval = lib.mkOption {
        type = lib.types.str;
        default = "15m";
        description = "How long after one sync finishes the next one starts.";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    sops.secrets."smb-password" = {
      sopsFile = ../../secrets/smb.yaml;
      key = "password";
    };
    # mount.cifs wants username=/password= lines in a file; the placeholder
    # keeps the password out of the store (rendered root-only at runtime).
    sops.templates."smb-credentials".content = ''
      username=${cfg.username}
      password=${config.sops.placeholder."smb-password"}
    '';

    # mount.cifs itself, and smbclient for poking at the NAS by hand
    environment.systemPackages = [
      pkgs.cifs-utils
      pkgs.samba
    ];

    fileSystems = builtins.listToAttrs (
      map (share: {
        name = "${cfg.mountBase}/${share}";
        value = {
          device = "//${cfg.server}/${share}";
          fsType = "cifs";
          options = [
            "credentials=${config.sops.templates."smb-credentials".path}"
            # files surface as the desktop user, not root
            "uid=${username}"
            "gid=users"
            "vers=3.1.1"
            "iocharset=utf8"
            # client-side symlink emulation: workspace checkouts carry nix
            # `result` links a plain cifs mount cannot create
            "mfsymlinks"
            # error out instead of hanging io forever if the nas drops
            "soft"
            # lazy-mount on first access, idle off, never block boot
            "noauto"
            "nofail"
            "_netdev"
            "x-systemd.automount"
            "x-systemd.idle-timeout=10min"
            "x-systemd.mount-timeout=10s"
          ];
        };
      }) cfg.shares
    );

    # one `cd` from home: ~/nas -> /mnt/nas
    systemd.tmpfiles.rules = [ "L ${home}/nas - - - - ${cfg.mountBase}" ];

    systemd.services.nas-workspace-sync = lib.mkIf cfg.workspaceSync.enable {
      description = "two-way sync of ~/workspace onto the NAS workspace share";
      # pulls the automount in; nas down -> mount fails -> this fails quietly
      # and the timer just tries again next tick
      unitConfig.RequiresMountsFor = [ workspaceMount ];
      serviceConfig = {
        Type = "oneshot";
        User = username;
        ExecStart = syncScript;
        # background churn: never compete with an interactive build or a game
        Nice = 10;
        IOSchedulingClass = "idle";
      };
    };
    systemd.timers.nas-workspace-sync = lib.mkIf cfg.workspaceSync.enable {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnBootSec = "3min";
        OnUnitInactiveSec = cfg.workspaceSync.interval;
        RandomizedDelaySec = "30s";
      };
    };
  };
}
