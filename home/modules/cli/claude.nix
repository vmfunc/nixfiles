# claude-config bundle comes from the private flake input (flake = false)
{ inputs, ... }:
let
  cc = inputs.claude-config;
in
{
  home.file = {
    ".claude/CLAUDE.md".source = "${cc}/CLAUDE.md";

    # drop one in a project root as CLAUDE.md to override
    ".config/claude/azzie-style-guide.md".source = "${cc}/identity/azzie-style-guide.md";
    ".config/claude/security-guide.md".source = "${cc}/security/CLAUDE_SECURITY.md";
    ".config/claude/cpp-guide.md".source = "${cc}/coding/CLAUDE_CPP.md";
    ".config/claude/go-guide.md".source = "${cc}/coding/CLAUDE_GO.md";
    ".config/claude/rust-guide.md".source = "${cc}/coding/CLAUDE_RUST.md";
    ".config/claude/python-guide.md".source = "${cc}/coding/CLAUDE_PYTHON.md";
    ".config/claude/asm-guide.md".source = "${cc}/coding/CLAUDE_ASM.md";
    ".config/claude/nix-guide.md".source = "${cc}/coding/CLAUDE_NIX.md";

    # re + security skills
    ".claude/skills/aarch64-triage/SKILL.md".source = "${cc}/skills/aarch64-triage/SKILL.md";
    ".claude/skills/pwn/SKILL.md".source = "${cc}/skills/pwn/SKILL.md";
    ".claude/skills/firmware-diff/SKILL.md".source = "${cc}/skills/firmware-diff/SKILL.md";
    ".claude/skills/kernel-exploit/SKILL.md".source = "${cc}/skills/kernel-exploit/SKILL.md";
    ".claude/skills/disclose/SKILL.md".source = "${cc}/skills/disclose/SKILL.md";

    # UserPromptSubmit hooks, wired in settings.json (hand-managed)
    ".config/claude/rice-mode.sh".source = "${cc}/hooks/rice-mode.sh";
    ".config/claude/sleep-nudge.sh".source = "${cc}/hooks/sleep-nudge.sh";

    # chat-mode persona — `chat` / claude --settings '{"outputStyle":"companion"}'
    ".claude/output-styles/companion.md" = {
      source = "${cc}/output-styles/companion.md";
      force = true;
    };
  };
}
