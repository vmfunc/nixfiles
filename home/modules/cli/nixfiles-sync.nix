{
  pkgs,
  config,
  lib,
  ...
}:
let
  # the nixfiles working checkout (this flake). edits land on the box azzie is at;
  # the OTHER boxes only catch up when they pull. syncthing covers ~/workspace +
  # ~/.claude/projects, NOT this repo, and the auto-update daemon builds from the
  # REMOTE flakeref and never touches the local checkout, so without this a box
  # silently runs a stale tree until a manual `git pull`.
  # the checkout lives at ~/mac-rice on the macs and ~/nixfiles on tuna; probe
  # both at runtime so one script serves every host and no-ops when neither exists
  home = config.home.homeDirectory;

  # ff-only on purpose: it catches up to the remote but NEVER clobbers. a diverged
  # history (local commits not yet pushed) or dirty edits the pull would touch make
  # it a clean no-op, leaving the box behind rather than destroying work. pushing
  # this repo stays a deliberate manual act.
  tick = pkgs.writeShellScript "nixfiles-pull-tick" ''
    export GIT_TERMINAL_PROMPT=0
    repo=""
    for c in "${home}/mac-rice" "${home}/nixfiles"; do
      [ -e "$c/.git" ] && { repo="$c"; break; }
    done
    [ -n "$repo" ] || exit 0
    branch="$(${pkgs.git}/bin/git -C "$repo" rev-parse --abbrev-ref HEAD 2>/dev/null || echo main)"
    ${pkgs.git}/bin/git -C "$repo" pull --ff-only -q origin "$branch" 2>/dev/null || true
  '';
  inherit (pkgs.stdenv.hostPlatform) isDarwin;
in
{
  # at login + hourly. mirrors the plan-sync agent: launchd on the macs, a
  # systemd.user timer on linux. each half is gated because setting the other
  # platform's service tree trips home-manager's platform assertions.
  launchd.agents.nixfiles-pull = lib.mkIf isDarwin {
    enable = true;
    config = {
      ProgramArguments = [ "${tick}" ];
      StartInterval = 3600;
      RunAtLoad = true;
      StandardErrorPath = "${config.home.homeDirectory}/Library/Logs/nixfiles-pull.log";
      StandardOutPath = "${config.home.homeDirectory}/Library/Logs/nixfiles-pull.log";
    };
  };

  # linux mirror: OnStartupSec plays RunAtLoad (fires shortly after login),
  # OnUnitActiveSec is the hourly tick.
  systemd.user.services.nixfiles-pull = lib.mkIf (!isDarwin) {
    Unit.Description = "nixfiles ff-only pull (catch up, never clobber)";
    Service = {
      Type = "oneshot";
      ExecStart = "${tick}";
    };
  };
  systemd.user.timers.nixfiles-pull = lib.mkIf (!isDarwin) {
    Unit.Description = "hourly nixfiles pull";
    Timer = {
      OnStartupSec = "2m";
      OnUnitActiveSec = "1h";
    };
    Install.WantedBy = [ "timers.target" ];
  };
}
