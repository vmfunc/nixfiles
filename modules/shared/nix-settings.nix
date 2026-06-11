{
  inputs,
  username,
  pkgs,
  ...
}:
let
  homeDir = if pkgs.stdenv.hostPlatform.isDarwin then "/Users/${username}" else "/home/${username}";
in
{
  nix.settings = {
    experimental-features = [
      "nix-command"
      "flakes"
    ];
    trusted-users = [
      "root"
      username
    ];
    max-jobs = "auto";
    warn-dirty = false;

    # forgejo token for private flake inputs; file is a per-host secret, not in repo
    netrc-file = "${homeDir}/.config/nix/netrc";

    substituters = [
      "https://cache.nixos.org"
      "https://nix-community.cachix.org"
    ];
    trusted-public-keys = [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
    ];
  };

  nix.registry.nixpkgs.flake = inputs.nixpkgs;

  # schedule/interval set per-platform
  nix.gc = {
    automatic = true;
    options = "--delete-older-than 7d";
  };
  nix.optimise.automatic = true;
}
