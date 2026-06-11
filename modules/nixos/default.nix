{ username, ... }:
{
  imports = [
    ./impermanence.nix
    ./secureboot.nix
    ./atuin-server.nix
  ];

  # nixos asserts exactly one of isNormalUser/isSystemUser
  users.users.${username} = {
    isNormalUser = true;
    extraGroups = [
      "wheel"
      "networkmanager"
    ];
  };
}
