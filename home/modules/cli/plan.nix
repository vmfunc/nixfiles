{ pkgs, lib, ... }:
let
  # Hourly sync: two-way and conflict-safe. Delegates to `plan sync`, which pulls
  # the shared source of truth (.plan.age), takes remote when this box has no local
  # edits, pushes when only this box changed, and refuses to clobber when both moved.
  # GIT_TERMINAL_PROMPT=0 keeps the launchd run non-interactive over HTTPS.
  synctick = pkgs.writeShellScript "plan-sync-tick" ''
    export GIT_TERMINAL_PROMPT=0
    exec ${pkgs.plan}/bin/plan sync
  '';
in
{
  # ~/.plan is the classic finger path: a symlink to the repo's working file.
  # the repo (git.collar.sh/quaver/plan) is cloned on a fresh box if missing, so
  # the plan is reproducible. the full .plan is gitignored, so a fresh clone has
  # no working copy: self-heal it by decrypting .plan.age. only-when-missing, so
  # this never overwrites local unpublished edits (that path is `plan sync`).
  home.activation.plan = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    plandir="$HOME/plan"
    key="$HOME/Library/Application Support/sops/age/keys.txt"
    if [ ! -e "$plandir/.git" ]; then
      run ${pkgs.git}/bin/git clone https://git.collar.sh/quaver/plan.git "$plandir" || true
    fi
    run ln -sfn "$plandir/.plan" "$HOME/.plan"
    if [ ! -f "$plandir/.plan" ] && [ -f "$plandir/.plan.age" ] && [ -f "$key" ]; then
      run ${pkgs.age}/bin/age -d -i "$key" -o "$plandir/.plan" "$plandir/.plan.age" || true
    fi
  '';

  # at login + hourly: pull remote + push local, conflict-safe (see `plan sync`).
  # RunAtLoad so a box that was off catches up the moment it comes back, not up to
  # an hour later.
  launchd.agents.plan-sync = {
    enable = true;
    config = {
      ProgramArguments = [ "${synctick}" ];
      StartInterval = 3600;
      RunAtLoad = true;
      StandardErrorPath = "/tmp/plan-sync.log";
      StandardOutPath = "/tmp/plan-sync.log";
    };
  };
}
