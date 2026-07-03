{
  description = "quaver's nix-config - multi-host darwin + nixos rice (lain wired)";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";

    # qemu 11.x's HVF backend asserts on HV_SYS_REG_SMCR_EL1 (SME sysreg) in
    # hvf_arch_init_vcpu under macOS 26.5.1, SIGABRT on every vcpu init, which
    # crash-loops the linux-builder. This rev is the last nixpkgs with qemu
    # 10.2.2 (parent of nixpkgs 734846393f8c), which boots a vcpu fine. The
    # overlay pulls only qemu from here. Drop once upstream qemu fixes the assert.
    nixpkgs-qemu.url = "github:nixos/nixpkgs/549bd84d6279f9852cae6225e372cc67fb91a4c1";

    nix-darwin = {
      url = "github:nix-darwin/nix-darwin/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    catppuccin = {
      url = "github:catppuccin/nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # deliberately NOT following our nixpkgs: its sbcl 2.6.4 fails to compile
    # fare-quasiquote ("Bug in readtable iterators"), which mac-app-util needs.
    # revert to inputs.nixpkgs.follows = "nixpkgs" once sbcl builds it again.
    mac-app-util.url = "github:hraban/mac-app-util";

    treefmt-nix = {
      url = "github:numtide/treefmt-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-index-database = {
      url = "github:nix-community/nix-index-database";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # flake=false so claude-config is a plain store path at eval time (home.file source, no decrypt)
    claude-config = {
      url = "git+https://git.collar.sh/quaver/claude-config.git?ref=main&shallow=1";
      flake = false;
    };
  };

  outputs =
    inputs@{
      self,
      nixpkgs,
      treefmt-nix,
      ...
    }:
    let
      inherit (self) outputs;
      mylib = import ./lib { inherit inputs outputs; };

      forAllSystems = nixpkgs.lib.genAttrs [
        "aarch64-darwin"
        "x86_64-darwin"
        "aarch64-linux"
        "x86_64-linux"
      ];
      treefmtEval = forAllSystems (
        system: treefmt-nix.lib.evalModule nixpkgs.legacyPackages.${system} ./treefmt.nix
      );
    in
    {
      overlays = import ./overlays { inherit inputs; };

      # darwin-only, custom pkgs need the apple sdk
      packages = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        pkgs.lib.optionalAttrs pkgs.stdenv.hostPlatform.isDarwin (import ./pkgs { inherit pkgs inputs; })
      );

      formatter = forAllSystems (system: treefmtEval.${system}.config.build.wrapper);

      # only formatting is exposed in checks; a full config here would IFD a foreign
      # system once a non-darwin host returns. build hosts via `just check` / eval.yml
      checks = forAllSystems (system: {
        formatting = treefmtEval.${system}.config.build.check self;
      });

      devShells = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        {
          default = pkgs.mkShell {
            name = "nix-config";
            packages = with pkgs; [
              nixd
              nixfmt
              statix
              deadnix
              nh
              just
              sops
              ssh-to-age
              age
            ];
          };

          # body lifted to shells/pwn.nix to keep flake.nix thin; mirrors templates/pwn
          pwn = import ./shells/pwn.nix { inherit pkgs; };
        }
      );

      templates = {
        pwn = {
          path = ./templates/pwn;
          description = "pwn/ctf devshell - pwntools + native re on darwin, full kit on linux";
        };
        re-target = {
          path = ./templates/re-target;
          description = "re scaffold - radare2/ghidra/frida devshell + case/ dir + a /re-target skill stub";
        };
        nix-module = {
          path = ./templates/nix-module;
          description = "home-manager module skeleton in azzie's house style (catppuccin/rice.theme wired)";
        };
        rust-cli = {
          path = ./templates/rust-cli;
          description = "rust cli devshell - claude_rust.md conventions baked in";
        };
        # templates.default supersedes the deprecated top-level defaultTemplate
        default = self.templates.re-target;
      };

      darwinConfigurations.otter = mylib.mkDarwin {
        hostname = "otter";
        username = "quaver";
        system = "aarch64-darwin";
      };

      # coral: always-on office desktop (m5 pro, clamshell + external display)
      darwinConfigurations.coral = mylib.mkDarwin {
        hostname = "coral";
        username = "quaver";
        system = "aarch64-darwin";
      };
    };
}
