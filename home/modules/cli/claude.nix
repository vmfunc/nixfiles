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

    # vault skills: obsidian project management + knowledge capture from any cwd.
    # `vault` is the substrate (tree map, frontmatter, link + task syntax, the
    # no-git safety rules); the rest reference it instead of restating it, so a
    # vault convention change lands in exactly one file. installed on every host,
    # not gated behind rice.notes: the vault syncs to boxes whose profile does
    # not import the notes spine, and a skill costs nothing until it is invoked.
    # `daylog` (notes/daylog.nix) drives daily-log / project-sync / wind-down.
    ".claude/skills/vault/SKILL.md".source = "${cc}/skills/vault/SKILL.md";
    ".claude/skills/project-start/SKILL.md".source = "${cc}/skills/project-start/SKILL.md";
    ".claude/skills/project-sync/SKILL.md".source = "${cc}/skills/project-sync/SKILL.md";
    ".claude/skills/daily-log/SKILL.md".source = "${cc}/skills/daily-log/SKILL.md";
    ".claude/skills/week/SKILL.md".source = "${cc}/skills/week/SKILL.md";
    ".claude/skills/wind-down/SKILL.md".source = "${cc}/skills/wind-down/SKILL.md";
    ".claude/skills/ink-note/SKILL.md".source = "${cc}/skills/ink-note/SKILL.md";
    ".claude/skills/case-to-vault/SKILL.md".source = "${cc}/skills/case-to-vault/SKILL.md";
    ".claude/skills/vault-query/SKILL.md".source = "${cc}/skills/vault-query/SKILL.md";

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
