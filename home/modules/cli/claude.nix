# claude-config bundle comes from the private flake input (flake = false).
# deliberately home.file + xdg.configFile, not the hm programs.claude-code module:
# settings.json stays hand-managed and the bundle layout (skills/, output-styles/,
# hooks/) is richer than what that module models.
{ inputs, ... }:
let
  cc = inputs.claude-config;
in
{
  home.file = {
    # force: may be hand-symlinked at ~/claude-config between rebuilds; clobber it
    ".claude/CLAUDE.md" = {
      source = "${cc}/CLAUDE.md";
      force = true;
    };

    # re + security skills
    ".claude/skills/aarch64-triage/SKILL.md".source = "${cc}/skills/aarch64-triage/SKILL.md";
    ".claude/skills/pwn/SKILL.md".source = "${cc}/skills/pwn/SKILL.md";
    ".claude/skills/firmware-diff/SKILL.md".source = "${cc}/skills/firmware-diff/SKILL.md";
    ".claude/skills/kernel-exploit/SKILL.md".source = "${cc}/skills/kernel-exploit/SKILL.md";
    ".claude/skills/disclose/SKILL.md".source = "${cc}/skills/disclose/SKILL.md";

    # chat-mode persona: `chat` / claude --settings '{"outputStyle":"companion"}'
    ".claude/output-styles/companion.md" = {
      source = "${cc}/output-styles/companion.md";
      force = true;
    };
  };

  xdg.configFile = {
    # drop one in a project root as CLAUDE.md to override
    "claude/azzie-style-guide.md".source = "${cc}/identity/azzie-style-guide.md";
    "claude/security-guide.md".source = "${cc}/security/CLAUDE_SECURITY.md";
    "claude/cpp-guide.md".source = "${cc}/coding/CLAUDE_CPP.md";
    "claude/go-guide.md".source = "${cc}/coding/CLAUDE_GO.md";
    "claude/rust-guide.md".source = "${cc}/coding/CLAUDE_RUST.md";
    "claude/python-guide.md".source = "${cc}/coding/CLAUDE_PYTHON.md";
    "claude/asm-guide.md".source = "${cc}/coding/CLAUDE_ASM.md";
    "claude/nix-guide.md".source = "${cc}/coding/CLAUDE_NIX.md";

    # UserPromptSubmit hooks, wired in settings.json (hand-managed)
    "claude/rice-mode.sh".source = "${cc}/hooks/rice-mode.sh";
    "claude/sleep-nudge.sh".source = "${cc}/hooks/sleep-nudge.sh";
  };
}
