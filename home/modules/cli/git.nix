{ pkgs, ... }:
{
  programs.git = {
    enable = true;
    settings = {
      user.name = "vmfunc";
      user.email = "celeste@collar.sh";
      init.defaultBranch = "main";
      pull.rebase = true;
      push.autoSetupRemote = true;
      tag.gpgSign = true;
    };

    signing = {
      format = "openpgp";
      key = "094FDAEF95F5EDA6";
      signByDefault = true;
    };

    # core.hooksPath is global, so this gates itself to repos with a .gitleaks.toml
    hooks.pre-commit = pkgs.writeShellScript "gitleaks-pre-commit" ''
      set -uo pipefail

      GITLEAKS="${pkgs.gitleaks}/bin/gitleaks"
      [ -x "$GITLEAKS" ] || exit 0

      ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || exit 0
      [ -f "$ROOT/.gitleaks.toml" ] || exit 0

      if ! "$GITLEAKS" git --staged --redact --no-banner -c "$ROOT/.gitleaks.toml" "$ROOT"; then
        echo "gitleaks: staged secret detected — commit blocked. fix it, or 'git commit --no-verify' to override." >&2
        exit 1
      fi
    '';
  };
}
