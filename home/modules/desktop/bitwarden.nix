# bitwarden: the desktop app (vault UI, biometric/browser unlock) plus the bw
# cli for scripting against the same vault. no home-manager programs.* module
# exists for either, so plain packages; login/session state stays imperative
# in ~/.config/Bitwarden on purpose (it holds the encrypted vault cache).
{ pkgs, ... }:
{
  home.packages = with pkgs; [
    bitwarden-desktop
    bitwarden-cli
  ];
}
