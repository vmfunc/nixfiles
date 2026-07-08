{ inputs, outputs }:
let
  inherit (inputs)
    nixpkgs
    nix-darwin
    home-manager
    catppuccin
    sops-nix
    nix-index-database
    ;

  theme = import ../theme.nix;

  hmModule = username: hostname: {
    home-manager.useGlobalPkgs = true;
    home-manager.useUserPackages = true;
    home-manager.backupFileExtension = "hm-backup";
    home-manager.extraSpecialArgs = {
      inherit
        inputs
        outputs
        username
        hostname
        theme
        ;
    };
    home-manager.sharedModules = [
      catppuccin.homeModules.catppuccin
      sops-nix.homeManagerModules.sops
      nix-index-database.homeModules.nix-index
    ];
    home-manager.users.${username}.imports = [ ../home/${hostname}.nix ];
  };

  commonModules =
    { hostname, system }:
    [
      ../hosts/${hostname}
      ../modules/shared
      { nixpkgs.hostPlatform = system; }
    ];
in
{
  mkDarwin =
    {
      hostname,
      username,
      system,
    }:
    nix-darwin.lib.darwinSystem {
      specialArgs = {
        inherit
          inputs
          outputs
          username
          hostname
          theme
          ;
      };
      modules = (commonModules { inherit hostname system; }) ++ [
        ../modules/darwin
        inputs.mac-app-util.darwinModules.default
        { home-manager.sharedModules = [ inputs.mac-app-util.homeManagerModules.default ]; }
        home-manager.darwinModules.home-manager
        (hmModule username hostname)
      ];
    };

  # tuna and any future linux host. shares commonModules + hmModule with mkDarwin
  # (identical specialArgs), so the shared modules/rice.* options and the theme
  # spine are threaded the same way. no impermanence/lanzaboote here: tuna adopts
  # the fresh ext4 Calamares install in place, no wipe-on-boot, no secureboot.
  mkNixos =
    {
      hostname,
      username,
      system,
    }:
    nixpkgs.lib.nixosSystem {
      specialArgs = {
        inherit
          inputs
          outputs
          username
          hostname
          theme
          ;
      };
      modules = (commonModules { inherit hostname system; }) ++ [
        ../modules/nixos

        # niri-flake: the compositor NixOS module wires the session/portals AND
        # auto-injects its home-manager module (supplying the typed
        # programs.niri.settings schema the home layer uses) when home-manager runs
        # as a nixos module, so it must NOT be added to sharedModules again or its
        # options are declared twice.
        inputs.niri.nixosModules.niri

        home-manager.nixosModules.home-manager
        (hmModule username hostname)
      ];
    };
}
