{ username, ... }:
{
  # nixos asserts exactly one of isNormalUser/isSystemUser
  users.users.${username} = {
    isNormalUser = true;
    extraGroups = [
      "wheel"
      "networkmanager"
    ];
  };
}
