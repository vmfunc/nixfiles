# shared NixOS system layer. imported by every linux host via mkNixos ->
# commonModules. currently only tuna, but keep it host-agnostic: per-box
# deviations belong in hosts/<host>, cross-linux config belongs here. the
# rice.* option modules (gaming/llm) default OFF and are switched on per host.
{ ... }:
{
  imports = [
    ./desktop-portal.nix
    ./users.nix
    ./gaming.nix
    ./steam-millennium.nix
    ./pso2-macro.nix
    ./retro.nix
    ./ime.nix
    ./media-servers.nix
    ./llm.nix
    ./apps.nix
    ./iphone.nix
    ./re.nix
    ./dev.nix
  ];
}
