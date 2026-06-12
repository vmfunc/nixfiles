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
      senpai
      ncspot
      spotify-player
      bottom
      lazydocker
      gh-dash
      serie
      presenterm
      wiki-tui
      cmatrix
      pipes-rs
    ]
    ++ lib.optionals pkgs.stdenv.hostPlatform.isDarwin [
      # prebuilt aarch64-darwin binary, darwin-only
      linear-cli
      cinny-desktop
      ctf-new
      case
      gate-check
      pvr-scan
      remind
      record
      mesh
      plan

      r2mcp
      frida-mcp
      # pyghidra-mcp closure is huge; run on demand: nix run .#pyghidra-mcp -- <binary>

      # self-hosted forgejo CI runner (docker executor via colima)
      forgejo-runner
      colima
      docker-client
    ];
}
