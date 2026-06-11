{ ... }:
{
  imports = [
    ./core.nix
    ./profiles/base.nix
    ./profiles/desktop-darwin.nix
    ./profiles/security.nix
  ];
}
