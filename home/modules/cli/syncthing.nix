# workspace replication between otter and coral over the tailnet.
# home-manager's services.syncthing wires the launchd agent on both macs from the
# same declaration (verified against the pinned hm syncthing.nix).
#
# nix is the source of truth: overrideDevices/overrideFolders delete anything
# added through the web UI on restart, so the mesh stays exactly what's here.
#
# restic (rice.backup -> /Volumes/EASYSTORE) remains the REAL backup. syncthing
# is live replication of the working tree, not a backup.
{
  config,
  lib,
  hostname,
  ...
}:
let
  # device ids, from each node's `syncthing -C <confdir> device-id`. a new host
  # stays filtered out (see isReal below) until its real id is filled in here.
  deviceIds = {
    otter = "QJRNTDE-ZA47SUS-RMMW2DH-SFPHKOG-SVDENDV-5CX6FDZ-A63LFOF-DO2ANAJ";
    coral = "PKBLYLF-EXI7YSC-ZGYUJFR-V3E2MHP-P3NKY2O-SATE56V-2MKCZEY-YI3BZAD";
    # TODO(deploy): fill from `syncthing device-id` on tuna after the first switch.
    # the TODO prefix keeps it filtered out (isReal) so the mesh comes up own-only
    # and healthy until the real id lands, then activates on the next rebuild.
    tuna = "TODO-tuna-device-id";
  };

  # EVAL-SAFETY + DON'T-SHIP-BROKEN-PAIRING gate.
  #
  # a literal "TODO-..." string evals fine but would be a broken device id at
  # runtime (syncthing would reject it / never pair). so a device is only emitted
  # once its id has been replaced with a real one. before deploy this
  # filters to {} -> syncthing comes up own-only and healthy; after the ids are
  # filled the mesh activates automatically on the next rebuild. no half-broken
  # intermediate state ever reaches the daemon.
  isReal = id: !(lib.hasPrefix "TODO" id);
  realDeviceIds = lib.filterAttrs (_name: isReal) deviceIds;

  # tailnet IPs so replication rides the tailnet directly (stable, survives the
  # office DHCP shuffling LAN addresses); "dynamic" stays as a discovery/relay
  # fallback for any peer without a pinned address.
  tailnetAddr = {
    otter = "100.125.228.81";
    coral = "100.112.237.15";
  };
  devices = lib.mapAttrs (name: id: {
    inherit id;
    addresses = (lib.optional (tailnetAddr ? ${name}) "tcp://${tailnetAddr.${name}}:22000") ++ [
      "dynamic"
    ];
  }) realDeviceIds;

  # folder is shared with every peer that currently has a real id. these names
  # must all exist in `devices` above or hm's folder->device-id lookup throws,
  # which is exactly why both are derived from the same filtered set.
  folderDevices = lib.attrNames devices;

  # coral and tuna are the always-on desktops, so they keep file history. otter
  # (the laptop) is not always up, so versioning there would just be dead weight.
  isHub = builtins.elem hostname [
    "coral"
    "tuna"
  ];

  # staggered: keep deleted/overwritten versions for ~30 days, sweep hourly.
  thirtyDaysSeconds = 30 * 24 * 60 * 60;
  oneHourSeconds = 60 * 60;
  hubVersioning = {
    type = "staggered";
    params = {
      cleanInterval = toString oneHourSeconds;
      maxAge = toString thirtyDaysSeconds;
    };
  };

  workspacePath = "${config.home.homeDirectory}/workspace";
in
{
  services.syncthing = {
    enable = true;

    # nix owns the topology; discard anything added out-of-band on restart.
    overrideDevices = true;
    overrideFolders = true;

    settings = {
      inherit devices;

      folders.workspace = {
        path = workspacePath;
        type = "sendreceive";
        # inotify/fsevents instead of only periodic scans, so edits propagate fast.
        fsWatcherEnabled = true;
        devices = folderDevices;
        # only the hub retains history; null = no versioning on the laptops.
        versioning = lib.mkIf isHub hubVersioning;
      };

      # claude conversation transcripts (the claude --resume history). lives outside
      # ~/workspace so it needs its own folder. same device set + hub versioning.
      folders.claude-convos = {
        path = "${config.home.homeDirectory}/.claude/projects";
        type = "sendreceive";
        fsWatcherEnabled = true;
        devices = folderDevices;
        versioning = lib.mkIf isHub hubVersioning;
      };

      # ~/Downloads mirrored across every paired box so a file grabbed on one is on
      # the others. same device set + hub versioning; partials are ignored below.
      folders.downloads = {
        path = "${config.home.homeDirectory}/Downloads";
        type = "sendreceive";
        fsWatcherEnabled = true;
        devices = folderDevices;
        versioning = lib.mkIf isHub hubVersioning;
      };
    };
  };

  # keep in-flight downloads and machine-local junk out of the Downloads mesh so
  # half-written files don't replicate mid-transfer.
  home.file."Downloads/.stignore".text = ''
    .DS_Store
    .stversions
    .stfolder
    *.crdownload
    *.part
    *.download
    *.tmp
  '';

  # pinned ignore list lives inside the synced folder so every node honours the
  # same rules. keeps build artifacts and heavy machine-local dirs out of the
  # mesh: per-machine outputs, caches, vcs internals, and bulky local-only data.
  home.file."workspace/.stignore".text = ''
    target
    node_modules
    result
    result-*
    .venv
    __pycache__
    .direnv
    .DS_Store
    .stversions
    screenshots
    recordings
    easystore-export
    *.qcow2
    .stfolder
  '';
}
