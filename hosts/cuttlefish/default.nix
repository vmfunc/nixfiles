{
  inputs,
  pkgs,
  hostname,
  ...
}:
{
  imports = [
    ./hardware.nix
    ./disko.nix
    # single-box role, so it lives here and not in modules/nixos
    ./atuin-server.nix

    # framework/12-inch/13th-gen-intel, not the 13-inch variant (missing convertible quirks)
    inputs.nixos-hardware.nixosModules.framework-12-13th-gen-intel

    inputs.disko.nixosModules.disko
  ];

  # systemd in initrd needed for impermanence rollback + tpm2 crypttab unlock
  boot.initrd.systemd.enable = true;

  # framework ec kmod asserts kernel >= 6.10
  boot.kernelPackages = pkgs.linuxPackages_latest;

  # power: ppd, which makes nixos-hardware yield tlp off. enable exactly one
  services.power-profiles-daemon.enable = true;

  hardware.bluetooth.enable = true;

  networking.hostName = hostname;
  networking.networkmanager.enable = true;

  # tailscale is transport only, same policy as the macs: tailscale ssh stays
  # OFF, auth lives in openssh below. the node key survives wipe-on-boot via
  # modules/nixos/impermanence.nix (/var/lib/tailscale).
  services.tailscale.enable = true;

  # deploy-rs (flake.nix: sshUser=root, remoteBuild=true) and the PROVISIONING.md
  # step-5 rebuild path are ssh-only, so without sshd every deploy after the
  # nixos-anywhere bootstrap breaks. pubkey-only; root stays key-only too. host
  # keys survive the wipe (persisted in modules/nixos/impermanence.nix).
  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      PermitRootLogin = "prohibit-password";
    };
  };

  # root because deploy-rs connects as sshUser=root; same quaver@otter key coral
  # authorizes (hosts/coral/default.nix). declarative, so impermanence cannot
  # lose it.
  users.users.root.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJuUZY9+MFmjGNknQNdjVknnfffU6TqoJaa6ocPdJv7G quaver@otter"
  ];

  time.timeZone = "America/Los_Angeles";
  i18n.defaultLocale = "en_US.UTF-8";

  # easystore is exfat
  boot.supportedFilesystems = [ "exfat" ];
  environment.systemPackages = [ pkgs.exfatprogs ];

  # hourly auto-deploy from the promoted deploy branch (nixos system.autoUpgrade branch)
  rice.autoUpdate.enable = true;

  # string on nixos, not the integer darwin uses
  system.stateVersion = "25.11";
}
