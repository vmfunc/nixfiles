# otter: per-machine layer, host-specific overrides go here
{ lib, ... }:
{
  # ---------------------------------------------------------------------------
  # battery: force deep sleep on the lid-close, no maintenance darkwakes
  # ---------------------------------------------------------------------------
  # symptom: lid shut on battery drains ~7%/hr (100 -> 10 over 13h). `pmset -g
  # log` shows an RTC SleepService/Maintenance DarkWake every ~16 min the whole
  # time, so the machine never reaches deep sleep. two macOS battery defaults
  # cause it, and there is NO nix-darwin option for either, so drive pmset by
  # hand (same escape hatch coral uses). `-b` = battery source only; AC keeps
  # its defaults. idempotent, so `|| true` keeps activation from aborting.
  system.activationScripts.postActivation.text = lib.mkBefore ''
    pmset=/usr/bin/pmset
    if [ -x "$pmset" ]; then
      echo "applying otter battery power policy..." >&2
      # powernap wakes every ~16 min for iCloud/Spotlight/Mail upkeep. on a
      # closed laptop that upkeep is the drain, not a feature. off on battery.
      "$pmset" -b powernap 0 || true
      # tcpkeepalive holds the network stack up so the mac can "wake for network
      # access", which pins it in shallow sleep. off = deeper sleep (macOS warns
      # once that it can't wake for network; that is the trade we want on batt).
      "$pmset" -b tcpkeepalive 0 || true
    fi
  '';

  # tailnet transport so otter can reach coral (ssh + remote builds) when away
  # from the LAN. ssh stays apple openssh, pubkey-only; tailscale ssh NOT enabled.
  services.tailscale.enable = true;

  # otter (laptop) can't realise heavy aarch64-darwin closures comfortably, so
  # offload to coral (m5 pro, always-on). coral builds, otter substitutes the result.
  nix.distributedBuilds = true;
  nix.buildMachines = [
    {
      # coral's stable tailnet IP, reachable from anywhere, survives the office
      # DHCP shuffling its LAN address. both otter + coral are on the tailnet.
      hostName = "100.112.237.15";
      sshUser = "quaver";
      protocol = "ssh-ng";
      system = "aarch64-darwin";
      maxJobs = 8;
      speedFactor = 2;
      supportedFeatures = [
        "nixos-test"
        "benchmark"
        "big-parallel"
        "kvm"
      ];
      # nix-daemon runs as root, so the builder key must live in root's homedir.
      # TODO(deploy): provision /var/root/.ssh/coral-builder (matching pubkey in
      # coral's authorized_keys) AND add coral's host key to root's known_hosts.
      sshKey = "/var/root/.ssh/coral-builder";
    }
  ];

  # let the remote builder pull deps from caches instead of otter shipping them over ssh
  nix.settings.builders-use-substitutes = true;
}
