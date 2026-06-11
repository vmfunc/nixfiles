{
  description = "re-target static re devshell (radare2/rizin/ghidra) for a single target, darwin-native";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";

    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = import nixpkgs {
          inherit system;
          config.allowUnfree = false;
        };
        inherit (pkgs) lib stdenv;

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
        ];

        linuxExtras = lib.optionals stdenv.hostPlatform.isLinux (
          with pkgs;
          [
            checksec
            elfutils
            pax-utils
          ]
        );
      in
      {
        devShells.default = pkgs.mkShell {
          name = "re-target";

          packages = coreNative ++ linuxExtras;

          # catppuccin macchiato mauve = #c6a0f6 -> 256-colour 183
          shellHook = ''
            mauve='\033[38;5;183m'
            subtext='\033[38;5;146m'
            reset='\033[0m'
            printf "''${mauve}re-target shell ready''${reset}\n"
            printf "''${subtext}   radare2: %s''${reset}\n" "$(${pkgs.radare2}/bin/r2 -v 2>/dev/null | head -1)"
            printf "''${subtext}   case dir: run 'mkdir -p case/{notes,decomp,scripts,artifacts}' to externalize findings.''${reset}\n"
            printf "''${subtext}   /aarch64-triage drives this shell. r2mcp/pyghidra-mcp are on the host PATH (see CLAUDE.md).''${reset}\n"
            ${lib.optionalString stdenv.hostPlatform.isDarwin ''
              printf "''${subtext}   host: darwin — native arm64/arm64e static analysis + LLDB. No VM for Mach-O.''${reset}\n"
            ''}
            ${lib.optionalString stdenv.hostPlatform.isLinux ''
              printf "''${subtext}   host: linux — checksec + elfutils lit up for ELF triage.''${reset}\n"
            ''}
          '';
        };
      }
    );
}
