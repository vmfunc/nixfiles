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

    # swift 5.10.1 fails on x86_64-linux since cc-wrapper started injecting
    # -mtls-dialect=gnu2 (machineFlags, clang >= 19.1): swift wraps its in-tree
    # clang-16 with a wrapper generated for clang 21, and clang-16 rejects the
    # flag. this rev is the pre-bump lock (2026-07-01), i.e. the closure tuna is
    # already running, so pulling swift-corelibs-libdispatch (deadbeef's only
    # path into swift) from here costs no rebuild. drop once upstream swift
    # builds again (filter lands or swift moves to a clang >= 19.1 bootstrap).
    nixpkgs-swift.url = "github:nixos/nixpkgs/f76e4c7b1840704deda511ab34f37b829f6b5636";

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

    # emacs built from source daily (native-comp on by default). we deliberately use
    # emacs-unstable-pgtk / emacs-unstable (31.0.9x pretest), NOT emacs-git: master is
    # emacs 32.0.50 now and doom's module library tops out at 31-era features (core
    # README warns against .50 builds). revert to emacs-git* once doom supports 32.
    # git+https (not github:) on both emacs inputs: locking the github: form resolves
    # HEAD through api.github.com, which rate-limits anonymous callers (403s here and
    # on CI runners); ls-remote over git+https has no such limit. shallow keeps the
    # emacs-overlay clone small.
    emacs-overlay = {
      url = "git+https://github.com/nix-community/emacs-overlay.git?shallow=1";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # doom emacs, fully declarative: DOOMDIR in-repo, doom's package pins exported by
    # its own CLI then built with nix (no doom sync, no straight.el, no network at
    # activation). follows = "" detaches its nixpkgs on purpose (the hm module never
    # uses it, README recommends this to skip the download; a follows to ours would
    # pull it back in for nothing).
    nix-doom-emacs-unstraightened = {
      url = "git+https://github.com/marienz/nix-doom-emacs-unstraightened.git?shallow=1";
      inputs.nixpkgs.follows = "";
    };

    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # linux-only inputs (tuna, the framework desktop). nixos-hardware carries no
    # nixpkgs dep of its own, so it needs no follows.
    nixos-hardware.url = "github:NixOS/nixos-hardware";

    # niri: scrollable-tiling wayland compositor. the flake ships both the nixos
    # module (session/portals) and the home-manager module (typed settings).
    niri = {
      url = "github:sodiboo/niri-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # gaming: lowLatency pipewire + platform-optimizations modules. proton itself
    # comes from nixpkgs (proton-ge-bin), not from here.
    nix-gaming = {
      url = "github:fufexan/nix-gaming";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # millennium: steam client skin/plugin loader, for the "old steam" look. not
    # in nixpkgs; this flake wraps the upstream in-tree nix build (which itself
    # patches a loader into the steam client) and exposes an overlay + a steam
    # package + HM theme options. consumed ONLY on tuna, gated default-off behind
    # rice.steamOld (modules/nixos/steam-millennium.nix), so it is inert until
    # opted in and never touches the macs. WHY pinned: millennium injects into a
    # self-updating client, so a steam-client update can transiently break the
    # skin; pin the flake and bump deliberately. revert: drop rice.steamOld back
    # to false and steam runs unmodified (the module override is mkDefault-safe).
    nixos-millennium = {
      url = "github:re1n0/nixos-millennium/2fa2beb8605b744c610769182615e151cfe143c8";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # zen browser (azzie's daily driver). not in nixpkgs; the linux build comes
    # from this flake. the macs get zen via homebrew, so this is linux-only.
    zen-browser = {
      url = "github:0xc000022070/zen-browser-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # kmods: azzie's out-of-tree kernel module monorepo (kept OUT of this public
    # mirror). exposes lib.packagesFor <linuxPackages> -> { <mod> = drv; }, built
    # against tuna's pinned kernel and surfaced via boot.extraModulePackages.
    kmods = {
      url = "git+https://git.collar.sh/quaver/modules.git";
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

      # tuna: framework desktop (ryzen ai max+ 395 / strix halo), the fleet's
      # first x86_64-linux host. niri rice, bleeding-edge kernel, gaming + llm.
      nixosConfigurations.tuna = mylib.mkNixos {
        hostname = "tuna";
        username = "quaver";
        system = "x86_64-linux";
      };
    };
}
