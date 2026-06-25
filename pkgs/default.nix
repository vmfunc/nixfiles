# `inputs` is threaded in (from flake.nix and overlays/default.nix, both of which
# have it in scope) so re-harness can bake in the private claude-config SKILL.md.
{ pkgs, inputs }:
let
  # ghidrecomp not in nixpkgs; resolve once, threaded into pyghidra-mcp at runtime
  ghidrecomp = pkgs.python3Packages.callPackage ./ghidrecomp/package.nix { };
  # same instance threaded onto re-harness PATH (it shells out to r2mcp)
  r2mcp = pkgs.callPackage ./r2mcp/package.nix { };
in
{
  linear-cli = pkgs.callPackage ./linear-cli/package.nix { };
  ctf-new = pkgs.callPackage ./ctf-new/package.nix { };
  case = pkgs.callPackage ./case/package.nix { };
  gate-check = pkgs.callPackage ./gate-check/package.nix { };
  pvr-scan = pkgs.callPackage ./pvr-scan/package.nix { };
  remind = pkgs.callPackage ./remind/package.nix { };
  record = pkgs.callPackage ./record/package.nix { };
  lumen = pkgs.callPackage ./lumen/package.nix { };
  scrobble = pkgs.callPackage ./scrobble/package.nix { };
  mesh = pkgs.callPackage ./mesh/package.nix { };
  plan = pkgs.callPackage ./plan/package.nix { };
  zen-tabgrouper = pkgs.callPackage ./zen-tabgrouper/package.nix { };
  frida-mcp = pkgs.callPackage ./frida-mcp/package.nix { };
  inherit r2mcp;
  re-harness = pkgs.python3Packages.callPackage ./re-harness/package.nix {
    inherit r2mcp;
    claudeSkill = "${inputs.claude-config}/skills/aarch64-triage/SKILL.md";
  };

  inherit ghidrecomp;
  pyghidra-mcp = pkgs.python3Packages.callPackage ./pyghidra-mcp/package.nix {
    # jdk21 is top-level, not in python3Packages
    inherit (pkgs) ghidra jdk21;
    inherit ghidrecomp;
  };
}
