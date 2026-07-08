{ username, ... }:
{
  # nixos asserts exactly one of isNormalUser/isSystemUser. groups: wheel (sudo),
  # networkmanager (nmcli), video/input/render for a wayland/niri desktop + the
  # /dev/dri render node (radv, rocm, va-api), gamemode for the gaming stack.
  # the login password is already set by the Calamares install, so no sops here.
  users.users.${username} = {
    isNormalUser = true;
    extraGroups = [
      "wheel"
      "networkmanager"
      "video"
      "input"
      "render"
      "gamemode"
    ];
  };
}
