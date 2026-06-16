{ pkgs, lib, ... }:
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

      # file-based credential store for the forge token. osxkeychain needs a gui
      # session and fails -25308 over ssh on a headless box, so reset the inherited
      # osxkeychain helper (empty entry) and consult only the store file, which is
      # populated from the sops netrc by the activation below.
      credential.helper = [
        ""
        "store"
      ];
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

  # populate ~/.git-credentials from the sops netrc once sops-nix has written it, so
  # the store helper can auth to the forge for the private claude-config input, the
  # plan repo, and the hourly auto-update. works over ssh, no keychain required.
  home.activation.gitForgeCredentials = lib.hm.dag.entryAfter [ "sops-nix" ] ''
    netrc="$HOME/.config/nix/netrc"
    if [ -f "$netrc" ]; then
      machine=$(${pkgs.gawk}/bin/awk '$1=="machine"{print $2}' "$netrc")
      login=$(${pkgs.gawk}/bin/awk '$1=="login"{print $2}' "$netrc")
      pass=$(${pkgs.gawk}/bin/awk '$1=="password"{print $2}' "$netrc")
      if [ -n "$machine" ] && [ -n "$login" ] && [ -n "$pass" ]; then
        umask 077
        printf 'https://%s:%s@%s\n' "$login" "$pass" "$machine" > "$HOME/.git-credentials"
      fi
    fi
  '';
}
