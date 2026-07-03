{ inputs, outputs }:
let
  inherit (inputs)
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
}
