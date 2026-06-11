{
  description = "pwn/ctf devshell — pwntools + native re on darwin, full kit on linux";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";

    flake-utils.url = "github:numtide/flake-utils";

    # not in nixpkgs; only consumed on linux
    pwndbg = {
      url = "github:pwndbg/pwndbg";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
      pwndbg,
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = import nixpkgs {
          inherit system;
          config.allowUnfree = false;
        };
        inherit (pkgs) lib stdenv;

        # python
        py = pkgs.python3.withPackages (
          ps: with ps; [
            pwntools
            ropper
            ropgadget # top-level ropper/angr attrs missing; use python3Packages.*
            angr
            angrop
            capstone
            unicorn
            keystone-engine
            requests
            ipython
          ]
        );

        # native re
        coreNative = with pkgs; [
          radare2
          rizin
          cutter
          ghidra
          binwalk
          one_gadget
          patchelf
          file
          ripgrep
          qemu # qemu-system-*, not qemu-user
          lima
          colima

          # runs on mac, targets aarch64-linux; pair with a remote gdbstub
          pkgsCross.aarch64-multiplatform.buildPackages.gdb
        ];

        # linux-only; pwninit transitively pulls elfutils which won't eval on darwin
        linuxExtras = lib.optionals stdenv.hostPlatform.isLinux (
          with pkgs;
          [
            gdb
            gef
            qemu-user
            checksec
            pwninit
            elfutils
            rubyPackages.seccomp-tools
            patchelf
            pwndbg.packages.${system}.default
          ]
        );
      in
      {
        devShells.default = pkgs.mkShell {
          name = "pwn";

          packages = [ py ] ++ coreNative ++ linuxExtras;

          # mauve #cba6f7 -> 256-colour 183
          shellHook = ''
            mauve='\033[38;5;183m'
            subtext='\033[38;5;146m'
            reset='\033[0m'
            printf "''${mauve}pwn shell ready''${reset}\n"
            printf "''${subtext}   python: %s''${reset}\n" "$(${py}/bin/python --version 2>&1)"
            ${lib.optionalString stdenv.hostPlatform.isDarwin ''
              printf "''${subtext}   host: darwin — static analysis + angr/unicorn native.''${reset}\n"
              printf "''${subtext}   dynamic ELF debugging lives in linux: 'lima' / 'colima' / nix linux-builder,''${reset}\n"
              printf "''${subtext}   then re-enter this same flake inside the aarch64-linux VM for the full kit.''${reset}\n"
            ''}
            ${lib.optionalString stdenv.hostPlatform.isLinux ''
              printf "''${subtext}   host: linux — full kit lit up (gdb+pwndbg, qemu-user, checksec, seccomp-tools).''${reset}\n"
            ''}
          '';
        };
      }
    );
}
