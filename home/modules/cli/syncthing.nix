# cross-platform workspace replication across otter / cuttlefish / coral.
# home-manager's services.syncthing wires a launchd agent on darwin and a
# systemd user service on linux from the SAME declaration, so this one module
# is correct on every node (verified against the pinned hm syncthing.nix).
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
  # device ids are unknown until syncthing has run at least once on each node
  # (no syncthing exists anywhere yet). fill these at deploy from each node's
  # `syncthing --device-id` (or the web UI). until then they stay TODO.
  deviceIds = {
    otter = "TODO-FILL-AT-DEPLOY";
    cuttlefish = "TODO-FILL-AT-DEPLOY";
    coral = "TODO-FILL-AT-DEPLOY";
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
  realDeviceIds = lib.filterAttrs (_name: id: isReal id) deviceIds;

  # only the peers with real ids, as syncthing device entries. addresses are
  # left dynamic (global+local discovery + relays). TODO at deploy: once
  # tailscale is up, pin `addresses = [ "tcp://<tailnet-ip>:22000" ]` per peer
  # so replication rides the tailnet directly instead of via relays.
  devices = lib.mapAttrs (_name: id: { inherit id; }) realDeviceIds;

  # folder is shared with every peer that currently has a real id. these names
  # must all exist in `devices` above or hm's folder->device-id lookup throws,
  # which is exactly why both are derived from the same filtered set.
  folderDevices = lib.attrNames devices;

  # coral is the always-on hub, so it keeps file history. the laptops (otter,
  # cuttlefish) aren't always up, so versioning there would just be dead weight.
  isHub = hostname == "coral";

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
    };
  };

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
    .git/objects
    screenshots
    recordings
    easystore-export
    *.qcow2
    .stfolder
  '';
}
