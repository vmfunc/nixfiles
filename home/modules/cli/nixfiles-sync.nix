{ pkgs, config, ... }:
let
  # the nixfiles working checkout (this flake). edits land on the box azzie is at;
  # the OTHER boxes only catch up when they pull. syncthing covers ~/workspace +
  # ~/.claude/projects, NOT this repo, and the auto-update daemon builds from the
  # REMOTE flakeref and never touches the local checkout, so without this a box
  # silently runs a stale tree until a manual `git pull`.
  repo = "${config.home.homeDirectory}/mac-rice";

  # ff-only on purpose: it catches up to the remote but NEVER clobbers. a diverged
  # history (local commits not yet pushed) or dirty edits the pull would touch make
  # it a clean no-op, leaving the box behind rather than destroying work. pushing
  # this repo stays a deliberate manual act.
  tick = pkgs.writeShellScript "nixfiles-pull-tick" ''
    export GIT_TERMINAL_PROMPT=0
    repo="${repo}"
    [ -e "$repo/.git" ] || exit 0
    branch="$(${pkgs.git}/bin/git -C "$repo" rev-parse --abbrev-ref HEAD 2>/dev/null || echo main)"
    ${pkgs.git}/bin/git -C "$repo" pull --ff-only -q origin "$branch" 2>/dev/null || true
  '';
in
{
  # at login + hourly. mirrors the plan-sync agent. launchd is darwin-only; on
  # linux this option no-ops (cuttlefish would need a systemd.user timer, deferred
  # while it is offline).
  launchd.agents.nixfiles-pull = {
    enable = true;
    config = {
      ProgramArguments = [ "${tick}" ];
      StartInterval = 3600;
      RunAtLoad = true;
      StandardErrorPath = "/tmp/nixfiles-pull.log";
      StandardOutPath = "/tmp/nixfiles-pull.log";
    };
  };
}
