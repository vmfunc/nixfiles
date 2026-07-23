# shared NixOS system layer. imported by every linux host via mkNixos ->
# commonModules. currently only tuna, but keep it host-agnostic: per-box
# deviations belong in hosts/<host>, cross-linux config belongs here. the
# rice.* option modules (gaming/llm) default OFF and are switched on per host.
{ inputs, username, ... }:
{
  imports = [
    # SYSTEM-level sops: root-side consumers (cifs mount credentials in nas.nix)
    # cannot reach the home-manager sops layer, so the nixos module comes in here.
    inputs.sops-nix.nixosModules.sops
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
    ./lkm.nix
    ./nas.nix
  ];

  # same age key the home layer decrypts with (home/modules/cli/sops.nix):
  # single-user boxes, one key materialised per box, not a second one to rot.
  # root reads it fine, and /home sits on the root fs on every linux host so
  # it is reachable when sops-install-secrets runs at boot.
  sops.age.keyFile = "/home/${username}/.config/sops/age/keys.txt";
}
