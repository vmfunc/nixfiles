{ pkgs, lib, ... }:
let
  recipient = "age17p7gtew5du203m4g5wja9gfyahqhwqjh6zsnwq55g7fv2zecj9yqj86xfw";

  # Hourly autosave: commit + push ONLY when ~/plan/.plan actually changed since the
  # last commit. Change is detected by decrypting the committed .plan.age and diffing
  # against the current .plan -- this works for %hidden-only edits too, and avoids a
  # false commit every hour (age ciphertext is non-deterministic). Uses store paths so
  # it does not depend on the launchd PATH. A leak-guard refuses any %hidden in public.
  autocommit = pkgs.writeShellScript "plan-autocommit" ''
    set -u
    export GIT_TERMINAL_PROMPT=0
    dir="$HOME/plan"
    key="$HOME/Library/Application Support/sops/age/keys.txt"
    cd "$dir" 2>/dev/null || exit 0
    [ -f .plan ] || exit 0

    if [ -f .plan.age ] \
      && ${pkgs.age}/bin/age -d -i "$key" .plan.age 2>/dev/null \
         | ${pkgs.diffutils}/bin/diff -q - .plan >/dev/null 2>&1; then
      exit 0
    fi

    ${pkgs.gnugrep}/bin/grep -v '%hidden' .plan > plan.txt || true
    if ${pkgs.gnugrep}/bin/grep -q '%hidden' plan.txt; then exit 1; fi
    ${pkgs.age}/bin/age -r "${recipient}" -o .plan.age .plan

    ${pkgs.git}/bin/git add plan.txt .plan.age
    ${pkgs.git}/bin/git -c commit.gpgsign=false commit -q \
      -m "plan: autosave $(${pkgs.coreutils}/bin/date '+%Y-%m-%d %H:%M')" >/dev/null 2>&1 || exit 0
    ${pkgs.git}/bin/git push -q >/dev/null 2>&1 || true
  '';
in
{
  # ~/.plan is the classic finger path: a symlink to the repo's working file.
  # the repo (git.collar.sh/quaver/plan) is cloned on a fresh box if missing, so
  # the plan is reproducible. the full .plan is gitignored, so after a fresh clone
  # run `plan restore` to decrypt it back from .plan.age.
  home.activation.plan = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    plandir="$HOME/plan"
    if [ ! -e "$plandir/.git" ]; then
      run ${pkgs.git}/bin/git clone https://git.collar.sh/quaver/plan.git "$plandir" || true
    fi
    run ln -sfn "$plandir/.plan" "$HOME/.plan"
  '';

  # hourly autosave: commits + pushes only when .plan changed.
  launchd.agents.plan-autocommit = {
    enable = true;
    config = {
      ProgramArguments = [ "${autocommit}" ];
      StartInterval = 3600;
      RunAtLoad = false;
      StandardErrorPath = "/tmp/plan-autocommit.log";
    };
  };
}
