# plan-mirror: ~/.plan rendered into the vault as plan.md, so the finger plan
# shows up in obsidian on every device (ios included) without the note system
# growing a second todo store. one-way by design: the plan is edited with the
# `plan` command (cli/plan.nix owns sync + the repo), the note is a read-only
# window. %hidden lines are STRIPPED before the mirror: they are age-encrypted
# in the plan repo precisely so they never leave the box in cleartext, and the
# vault syncs to a third party (e2e, but hidden means hidden).
# linux: a path unit fires on edit + a timer catches `plan sync` pulls; darwin
# mirrors with a launchd interval, same shape as cli/plan.nix.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.rice.notes;
  inherit (pkgs.stdenv.hostPlatform) isDarwin;

  mirror = pkgs.writeShellScript "plan-mirror" ''
    set -eu
    plan="$HOME/.plan"
    vault=${lib.escapeShellArg cfg.vault}
    [ -f "$plan" ] || exit 0
    [ -d "$vault" ] || exit 0
    tmp="$vault/.plan.md.tmp"
    {
      printf -- '---\ncssclasses: plan\n---\n\n'
      printf -- '> [!info] live mirror of `~/.plan`. edit with the `plan` command, not here.\n\n'
      printf -- '```plan\n'
      # grep exits 1 when every line is %hidden; an empty mirror is still valid
      ${pkgs.gnugrep}/bin/grep -v '%hidden' "$plan" || true
      printf -- '```\n'
    } >"$tmp"
    mv "$tmp" "$vault/plan.md"
  '';
in
{
  config = lib.mkIf cfg.enable {
    systemd.user.services.plan-mirror = lib.mkIf (!isDarwin) {
      Unit.Description = "mirror ~/.plan into the vault (read-only window)";
      Service = {
        Type = "oneshot";
        ExecStart = "${mirror}";
      };
    };

    # the path unit watches the repo working file, not the ~/.plan symlink:
    # PathModified follows the inode, and edits land in ~/plan/.plan.
    systemd.user.paths.plan-mirror = lib.mkIf (!isDarwin) {
      Unit.Description = "re-mirror the plan on edit";
      Path.PathModified = "%h/plan/.plan";
      Install.WantedBy = [ "default.target" ];
    };

    # timer as the backstop: catches pulls done by plan-sync while the path
    # unit was not running (box was off) and the first login of the day.
    systemd.user.timers.plan-mirror = lib.mkIf (!isDarwin) {
      Unit.Description = "periodic plan mirror";
      Timer = {
        OnStartupSec = "3m";
        OnUnitActiveSec = "15m";
      };
      Install.WantedBy = [ "timers.target" ];
    };

    launchd.agents.plan-mirror = lib.mkIf isDarwin {
      enable = true;
      config = {
        ProgramArguments = [ "${mirror}" ];
        StartInterval = 900;
        RunAtLoad = true;
      };
    };
  };
}
