# home-mounts: auto-mount the home NAS (UniFi Samba) SMB shares whenever this box is
# actually on the home network, and tear them down the moment it leaves.
#
# why a launchd agent and not /etc/fstab or autofs: this is the LAPTOP (otter), which
# roams. a static fstab/autofs entry beachballs Finder and any io to the mountpoint when
# the server is unreachable (coffee shop, tailnet-only). so instead we poll: probe the
# SMB port, mount if it answers, force-unmount ours if it doesn't. "at home" = the NAS is
# routable, which is the property we actually care about (survives SSID renames + VPN).
#
# cross-file deps:
#   - secrets/smb.yaml (sops): the share password, decrypted at activation. the password
#     NEVER lands in the nix store or the public mirror; the script reads it from the
#     runtime sops path. it IS briefly visible in `ps` while mount_smbfs runs (the URL
#     carries it), acceptable on a single-user laptop, flagged here on purpose.
#   - enabled per-host (home/otter.nix). off by default; coral is a fixed office desktop
#     on a different LAN, cuttlefish is linux.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.rice.homeMounts;

  mountScript = pkgs.writeShellScript "home-mounts" ''
    set -u
    server="${cfg.server}"
    smbuser="${cfg.username}"
    base="${cfg.mountBase}"
    passFile="${config.sops.secrets."smb-password".path}"
    shares="${lib.concatStringsSep " " cfg.shares}"

    reachable() { /usr/bin/nc -z -G 2 "$server" 445 >/dev/null 2>&1; }
    mounted()   { /sbin/mount | /usr/bin/grep -q " on $1 "; }

    if ! reachable; then
      # off the home net: drop our mounts so a dead server can't hang Finder/io.
      for s in $shares; do
        mp="$base/$s"
        mounted "$mp" && /sbin/umount -f "$mp" >/dev/null 2>&1 || true
      done
      exit 0
    fi

    [ -r "$passFile" ] || exit 0
    pass="$(/bin/cat "$passFile")"
    # percent-encode the userinfo-reserved chars so the smb:// URL parses cleanly.
    # '#' and '?' too: CFURL treats them as fragment/query delimiters even inside
    # userinfo, which truncates the URL. '%' must stay first or it double-encodes.
    enc="$(printf '%s' "$pass" | /usr/bin/sed \
      -e 's/%/%25/g' -e 's/@/%40/g' -e 's#/#%2F#g' -e 's/:/%3A/g' \
      -e 's/!/%21/g' -e 's/ /%20/g' -e 's/#/%23/g' -e 's/?/%3F/g')"

    for s in $shares; do
      mp="$base/$s"
      mounted "$mp" && continue
      /bin/mkdir -p "$mp"
      /sbin/mount_smbfs -N "//$smbuser:$enc@$server/$s" "$mp" >/dev/null 2>&1 || true
    done
  '';
in
{
  options.rice.homeMounts = {
    enable = lib.mkEnableOption "auto-mount the home NAS SMB shares when on the home network";

    server = lib.mkOption {
      type = lib.types.str;
      default = "192.168.1.89";
      description = "Home NAS host/IP probed on tcp/445 to decide 'am I home'.";
    };

    username = lib.mkOption {
      type = lib.types.str;
      default = "quaver";
      description = "SMB username for the shares.";
    };

    shares = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        "quaver"
        "shared"
      ];
      description = "Share names to mount under mountBase (verified on the NAS).";
    };

    mountBase = lib.mkOption {
      type = lib.types.str;
      default = "${config.home.homeDirectory}/mnt";
      description = "Parent dir the shares mount under (user-owned; avoids root /Volumes).";
    };
  };

  config = lib.mkIf cfg.enable {
    sops.secrets."smb-password" = {
      sopsFile = ../../../secrets/smb.yaml;
      key = "password";
    };

    launchd.agents.home-mounts = {
      enable = true;
      config = {
        ProgramArguments = [ "${mountScript}" ];
        # run at login, poll every 2 min, and react fast when the network changes
        # (resolv.conf is rewritten on every interface/DHCP change).
        RunAtLoad = true;
        StartInterval = 120;
        WatchPaths = [ "/etc/resolv.conf" ];
        KeepAlive = false;
        ProcessType = "Background";
        StandardOutPath = "${config.home.homeDirectory}/Library/Logs/home-mounts.log";
        StandardErrorPath = "${config.home.homeDirectory}/Library/Logs/home-mounts.log";
      };
    };
  };
}
