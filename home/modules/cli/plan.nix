{ pkgs, lib, ... }:
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
}
