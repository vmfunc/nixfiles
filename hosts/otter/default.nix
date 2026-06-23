# otter: per-machine layer, host-specific overrides go here
{ ... }:
{
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
