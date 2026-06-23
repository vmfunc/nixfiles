{
  description = "nix-module: a home-manager module skeleton in azzie's house style (rice.theme-aware)";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";

    flake-utils.url = "github:numtide/flake-utils";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
      home-manager,
    }:
    {
      homeManagerModules.default = import ./module.nix;
      homeManagerModules.example = import ./module.nix;
    }
    // flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
      in
      {
        checks.module-evaluates =
          (home-manager.lib.homeManagerConfiguration {
            inherit pkgs;
            modules = [
              ./module.nix
              {
                home = {
                  username = "test";
                  homeDirectory = "/home/test";
                  stateVersion = "24.11";
                };
              }
            ];
          }).activationPackage;

        formatter = pkgs.nixfmt-rfc-style;

        devShells.default = pkgs.mkShell {
          name = "nix-module";
          packages = with pkgs; [
            nixfmt-rfc-style
            nixd
          ];
          shellHook = ''
            printf '\033[38;5;183mnix-module shell: `nix fmt` to format, `nix flake check` to eval the module.\033[0m\n'
          '';
        };
      }
    );
}
