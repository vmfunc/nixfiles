{ pkgs, lib, ... }:
{
  home.packages =
    with pkgs;
    [
      ripgrep
      fd
      jq
      gitui
      gh
      tree
      onefetch
      gitleaks
      age
      wget
      glow
      dust
      duf
      procs
      restic
      television
      ncspot
      spotify-player
      bottom
      lazydocker
      serie
      presenterm
      wiki-tui
      cmatrix
      pipes-rs
      bun

      # cozy CLIs: pure writeShellApplications, portable across darwin + linux
      case
      mesh
      plan
    ]
    ++ lib.optionals pkgs.stdenv.hostPlatform.isDarwin [
      # prebuilt aarch64-darwin binary, darwin-only
      linear-cli
      cinny-desktop
      ctf-new
      gate-check
      pvr-scan
      remind
      record

      r2mcp
      frida-mcp
      # pyghidra-mcp closure is huge; run on demand: nix run .#pyghidra-mcp -- <binary>

      # self-hosted forgejo CI runner (docker executor via colima)
      forgejo-runner
      colima
      docker-client
    ];
}
