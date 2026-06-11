{
  description = "rust-cli devShell with azzie's toolchain (clippy/rustfmt/audit/+nightly fuzz)";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";

    flake-utils.url = "github:numtide/flake-utils";

    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
      rust-overlay,
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = import nixpkgs {
          inherit system;
          overlays = [ (import rust-overlay) ];
        };
        inherit (pkgs) lib stdenv;

        rustToolchain = pkgs.rust-bin.stable.latest.default.override {
          extensions = [
            "rust-src"
            "rust-analyzer"
            "clippy"
            "rustfmt"
            "llvm-tools-preview"
          ];
        };
      in
      {
        devShells.default = pkgs.mkShell {
          name = "rust-cli";

          packages = [
            rustToolchain
          ]
          ++ (with pkgs; [
            cargo-audit
            cargo-deny
            cargo-nextest
            cargo-watch
            cargo-edit
            cargo-geiger
            taplo
          ])
          ++ lib.optionals stdenv.hostPlatform.isDarwin [
            pkgs.libiconv
          ];

          # cargo fuzz needs a nightly toolchain + cargo-fuzz, not wired here
          shellHook = ''
            mauve='\033[38;5;183m'
            subtext='\033[38;5;146m'
            reset='\033[0m'
            printf "''${mauve}rust-cli shell ready''${reset}\n"
            printf "''${subtext}   %s''${reset}\n" "$(${rustToolchain}/bin/rustc --version 2>/dev/null)"
            printf "''${subtext}   clippy -D warnings, rustfmt, cargo-audit/deny/nextest/geiger on PATH.''${reset}\n"
            printf "''${subtext}   conventions: ~/.config/claude/rust-guide.md (also seeded in CLAUDE.md).''${reset}\n"
          '';

          RUST_SRC_PATH = "${rustToolchain}/lib/rustlib/src/rust/library";
        };
      }
    );
}
