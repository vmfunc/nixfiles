{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.rice.backup;
in
{
  options.rice.backup = {
    enable = lib.mkEnableOption "scheduled restic backups to an external drive";

    repository = lib.mkOption {
      type = lib.types.str;
      example = "/Volumes/EASYSTORE/restic-repo";
      description = "Path to the restic repo on the mounted drive. The job no-ops when it isn't mounted.";
    };

    passwordFile = lib.mkOption {
      type = lib.types.str;
      default = "${config.home.homeDirectory}/.config/restic/password";
      description = "File containing the restic repo password.";
    };

    healthcheckUrlFile = lib.mkOption {
      type = lib.types.str;
      default = "${config.home.homeDirectory}/.config/restic/healthcheck-url";
      description = ''
        Path to a local file (kept out of the repo, like the password) with a
        healthchecks.io ping URL. when present, runitor pings /start then
        /success|/fail around each backup. a not-mounted skip does not ping, so a
        chronically-unplugged drive trips the dead-man's switch.
      '';
    };

    paths = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ "${config.home.homeDirectory}/workspace" ];
      description = "Paths to back up.";
    };

    exclude = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Exclude patterns passed to restic.";
    };

    pruneOpts = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        "--keep-daily"
        "7"
        "--keep-weekly"
        "4"
        "--keep-monthly"
        "12"
      ];
      description = "Retention flags for `restic forget --prune`.";
    };

    command = lib.mkOption {
      type = lib.types.package;
      internal = true;
      description = "Generated backup script; referenced by the platform scheduler.";
    };
  };

  config = lib.mkIf cfg.enable {
    rice.backup.command = pkgs.writeShellScript "restic-backup" ''
      set -uo pipefail
      REPO="${cfg.repository}"
      [ -d "$REPO" ] || { echo "[$(date)] skip: $REPO not mounted"; exit 0; }

      # single-flight: RunAtLoad + StartOnMount + daily timer can overlap on one repo
      LOCK="/tmp/restic-backup.lock"
      mkdir "$LOCK" 2>/dev/null || { echo "[$(date)] another backup running; skip"; exit 0; }
      trap 'rmdir "$LOCK" 2>/dev/null || true' EXIT

      export RESTIC_REPOSITORY="$REPO"
      export RESTIC_PASSWORD_FILE="${cfg.passwordFile}"
      RESTIC="${pkgs.restic}/bin/restic"

      notify() {
        command -v osascript >/dev/null 2>&1 \
          && osascript -e "display notification \"$1\" with title \"restic backup\"" >/dev/null 2>&1 && return
        command -v notify-send >/dev/null 2>&1 && notify-send "restic backup" "$1" >/dev/null 2>&1 || true
      }

      # runitor takes -api-url <base> + -uuid <id>, no -ping-url flag
      RUNITOR=()
      if [ -r "${cfg.healthcheckUrlFile}" ]; then
        URL="$(cat "${cfg.healthcheckUrlFile}")"
        RUNITOR=("${pkgs.runitor}/bin/runitor" -api-url "''${URL%/*}" -uuid "''${URL##*/}" --)
      fi

      echo "[$(date)] backing up: ${lib.escapeShellArgs cfg.paths}"
      if ! "''${RUNITOR[@]}" "$RESTIC" backup ${lib.escapeShellArgs cfg.paths} ${
        lib.concatMapStringsSep " " (e: "--exclude=${lib.escapeShellArg e}") cfg.exclude
      }; then
        echo "[$(date)] BACKUP FAILED"
        notify "easystore backup FAILED — check the log"
        exit 1
      fi
      "$RESTIC" unlock 2>/dev/null || true
      "$RESTIC" forget ${lib.escapeShellArgs cfg.pruneOpts} --prune || echo "[$(date)] prune warning (non-fatal)"

      # weekly structural integrity check, marker-gated
      CHECKMARK="$HOME/.cache/restic-lastcheck"
      mkdir -p "$HOME/.cache"
      if [ ! -e "$CHECKMARK" ] || [ -n "$(find "$CHECKMARK" -mtime +7 2>/dev/null)" ]; then
        echo "[$(date)] weekly restic check"
        if "$RESTIC" check; then
          touch "$CHECKMARK"
        else
          echo "[$(date)] restic check FAILED — repo may be corrupt"
          notify "restic integrity check FAILED — check the repo"
        fi
      fi

      # weekly restore rehearsal: round-trip one real file out and compare to source
      REHEARSEMARK="$HOME/.cache/restic-lastrehearsal"
      if [ ! -e "$REHEARSEMARK" ] || [ -n "$(find "$REHEARSEMARK" -mtime +7 2>/dev/null)" ]; then
        echo "[$(date)] weekly restore rehearsal"
        # stat is BSD on darwin (-f %z) vs GNU on linux (-c %s)
        if stat -f '%z' "$HOME" >/dev/null 2>&1; then
          statsize() { stat -f '%z' "$1"; }
        else
          statsize() { stat -c '%s' "$1"; }
        fi
        # smallest non-empty file across the paths, NUL-safe walk
        REH_FILE=""
        REH_SIZE=""
        while IFS= read -r -d "" f; do
          sz=$(statsize "$f") || continue
          if [ -z "$REH_SIZE" ] || [ "$sz" -lt "$REH_SIZE" ]; then
            REH_SIZE="$sz"
            REH_FILE="$f"
          fi
        done < <(find ${lib.escapeShellArgs cfg.paths} -type f -size +0c -print0 2>/dev/null)

        if [ -z "$REH_FILE" ]; then
          echo "[$(date)] rehearsal: no non-empty file found; skipping"
          touch "$REHEARSEMARK"
        else
          REH_DIR="$(mktemp -d "''${TMPDIR:-/tmp}/restic-rehearsal.XXXXXX")"
          trap 'rm -rf "$REH_DIR" 2>/dev/null || true; rmdir "$LOCK" 2>/dev/null || true' EXIT
          if "$RESTIC" restore latest --target "$REH_DIR" --include "$REH_FILE" --verify >/dev/null 2>&1; then
            REH_OUT="$(find "$REH_DIR" -type f -size +0c -print -quit 2>/dev/null)"
            if [ -z "$REH_OUT" ] || [ ! -s "$REH_OUT" ]; then
              echo "[$(date)] rehearsal: restored file missing or empty"
              notify "restore rehearsal FAILED — restored file empty/missing"
            elif [ -e "$REH_FILE" ] && ! cmp -s "$REH_OUT" "$REH_FILE"; then
              echo "[$(date)] rehearsal: restored bytes differ from live source"
              notify "restore rehearsal FAILED — content mismatch"
            else
              echo "[$(date)] rehearsal OK ($REH_SIZE bytes round-tripped)"
              touch "$REHEARSEMARK"
            fi
          else
            echo "[$(date)] rehearsal: restic restore failed"
            notify "restore rehearsal FAILED — restore errored"
          fi
          rm -rf "$REH_DIR" 2>/dev/null || true
          trap 'rmdir "$LOCK" 2>/dev/null || true' EXIT
        fi
      fi
      echo "[$(date)] done"
    '';
  };
}
