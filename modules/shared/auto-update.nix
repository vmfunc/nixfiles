{
  config,
  options,
  lib,
  pkgs,
  username,
  hostname,
  ...
}:
let
  cfg = config.rice.autoUpdate;

  # this module is pulled in by modules/shared/default.nix, which both the darwin
  # and nixos toplevels import, so the option tree must exist on both platforms.
  # the implementation forks on the platform below.
  #
  # WHY two predicates: `isDarwin` (from pkgs) is used only for VALUES that are
  # forced lazily inside the chosen branch (homeDir, the script). it must NOT
  # decide WHICH option paths the config sets, because pkgs depends on the
  # resolved config and that is an infinite recursion. `onDarwin` instead probes
  # `options ? launchd` (the launchd option tree exists only on nix-darwin); that
  # reads from `options`, which is available before `config`/`pkgs` are forced,
  # so it can safely select the config shape.
  isDarwin = pkgs.stdenv.hostPlatform.isDarwin;
  onDarwin = options ? launchd;
  homeDir = if isDarwin then "/Users/${username}" else "/home/${username}";

  # WHY: the netrc carries the forgejo token that authenticates the private
  # claude-config flake input, and the age key decrypts every sops secret a
  # generation needs. on a freshly imaged box neither exists until the first
  # manual `darwin-rebuild switch` materialises them. fail-closed on both so the
  # hourly daemon is a no-op until then, instead of half-activating a broken
  # generation with missing secrets.
  netrcFile = "${homeDir}/.config/nix/netrc";
  ageKeyFile = "${homeDir}/Library/Application Support/sops/age/keys.txt";

  # WHY: darwin-rebuild derives the system-config path from its own argv[0]
  # (`${0%*/sw/bin/darwin-rebuild}`), so it must be invoked from the canonical
  # /run/current-system path, never from a bare store path. the daemon also runs
  # under launchd's minimal PATH, so nix itself has to be put on PATH explicitly.
  darwinRebuild = "/run/current-system/sw/bin/darwin-rebuild";
  nixProfileBin = "/nix/var/nix/profiles/default/bin";

  stampDir = "/var/lib/nixfiles-autoupdate";
  stampFile = "${stampDir}/last";
  lockDir = "/var/run/nixfiles-autoupdate.lock";
  logFile = "/var/log/nixfiles-autoupdate.log";

  # darwin updater. runs as root (only root can activate a generation). all
  # binaries are absolute store paths so the script does not depend on PATH;
  # the one exception is the nix CLI, which darwin-rebuild shells out to and
  # which is added to PATH explicitly above.
  darwinUpdate = pkgs.writeShellScript "nixfiles-autoupdate" ''
    set -u
    export PATH="${nixProfileBin}:${homeDir}/.nix-profile/bin:$PATH"
    export GIT_TERMINAL_PROMPT=0

    flake_ref=${lib.escapeShellArg cfg.flakeRef}
    flake_attr=${lib.escapeShellArg hostname}

    # single-flight: mkdir is atomic on macOS where flock(1) is absent. a stale
    # lock from a hard kill is cleared by hand; auto-reaping is deliberately
    # avoided, since a still-running rebuild holding it is exactly what must not
    # be stomped. trap removes it on a clean exit.
    if ! ${pkgs.coreutils}/bin/mkdir "${lockDir}" 2>/dev/null; then
      exit 0
    fi
    trap '${pkgs.coreutils}/bin/rmdir "${lockDir}" 2>/dev/null || true' EXIT

    # fail-closed until first manual switch materialises the secrets (see above).
    if [ ! -f "${netrcFile}" ] || [ ! -f "${ageKeyFile}" ]; then
      exit 0
    fi

    # never race a switch that a human (or a previous run) kicked off by hand.
    if ${pkgs.procps}/bin/pgrep -x darwin-rebuild >/dev/null 2>&1; then
      exit 0
    fi

    # cheap change check: ls-remote the deploy ref and compare to the stamp.
    # if HEAD has not moved since the last successful switch, do nothing. this
    # keeps the common (idle) hour from spending a full eval.
    remote=$(${pkgs.git}/bin/git ls-remote "$flake_ref" 2>/dev/null \
      | ${pkgs.coreutils}/bin/head -n1 \
      | ${pkgs.coreutils}/bin/cut -f1)
    if [ -z "$remote" ]; then
      # ls-remote failed (forge down, or the deploy ref does not exist yet).
      # treat as nothing-to-do rather than as an error worth paging over.
      exit 0
    fi

    last=""
    if [ -f "${stampFile}" ]; then
      last=$(${pkgs.coreutils}/bin/cat "${stampFile}" 2>/dev/null)
    fi
    if [ "$remote" = "$last" ]; then
      exit 0
    fi

    # build-then-switch is inherent: darwin-rebuild builds the new toplevel first
    # and only activates on a successful build, so a broken commit on deploy can
    # never take down the box, it just fails here and pages instead.
    if "${darwinRebuild}" switch --flake "$flake_ref#$flake_attr"; then
      ${pkgs.coreutils}/bin/mkdir -p "${stampDir}"
      ${pkgs.coreutils}/bin/printf '%s\n' "$remote" > "${stampFile}"
    else
      # best-effort page to the logged-in user via their remind tool. the daemon
      # is in root context, so re-enter the login gui session with `asuser`.
      uid=$(${pkgs.coreutils}/bin/id -u ${lib.escapeShellArg username} 2>/dev/null || true)
      if [ -n "$uid" ]; then
        /bin/launchctl asuser "$uid" ${pkgs.remind}/bin/remind \
          add "nixfiles auto-update failed for $flake_attr, see ${logFile}" \
          >/dev/null 2>&1 || true
      fi
      exit 1
    fi
  '';
in
{
  options.rice.autoUpdate = {
    enable = lib.mkEnableOption "hourly automatic deploy from the nixfiles deploy branch";

    flakeRef = lib.mkOption {
      type = lib.types.str;
      default = "git+https://git.collar.sh/quaver/nixfiles?ref=deploy";
      description = ''
        flake reference the updater deploys from. WHY a separate `deploy` branch:
        the updater ls-remotes this ref and only switches when it moves, so a
        `deploy` branch must actually exist on the forge before anything happens.
        promote `main` to `deploy` to ship. otter intentionally leaves
        rice.autoUpdate disabled so it is never auto-switched out from under a
        working session; coral and cuttlefish opt in.
      '';
    };

    intervalSec = lib.mkOption {
      type = lib.types.int;
      default = 3600;
      description = "seconds between auto-update checks.";
    };
  };

  # WHY a plain `if` on onDarwin (not lib.mkIf per branch): `launchd.daemons`
  # exists only on darwin and `system.autoUpgrade` exists only on nixos. the
  # module system validates that every option PATH in a config attrset exists
  # before it ever evaluates an mkIf condition, so wrapping the unknown-platform
  # branch in `mkIf false` still throws "option does not exist". onDarwin is an
  # eval-time bool from `options`, so a plain if selects exactly one attrset and
  # the other platform's option path is never present in the config tree at all.
  config = lib.mkIf cfg.enable (
    if onDarwin then
      {
        # system-level launchd DAEMON (root), not a home-manager agent: only root
        # can activate a generation. note daemons take .serviceConfig (the raw
        # plist), unlike home-manager's launchd.agents.<name>.config.
        launchd.daemons.nixfiles-autoupdate = {
          serviceConfig = {
            ProgramArguments = [ "${darwinUpdate}" ];
            StartInterval = cfg.intervalSec;
            RunAtLoad = false;
            StandardOutPath = logFile;
            StandardErrorPath = logFile;
          };
        };
      }
    else
      {
        # nixos has a first-class hourly upgrade timer. when `flake` is set and
        # `channel` is null the module omits --upgrade, so the deploy flake's own
        # lockfile is honoured and inputs are exactly what was committed on the
        # deploy branch, never silently bumped. --no-write-lock-file is the belt:
        # a remote-fetched flake's lock must never be rewritten, and there is no
        # --update-input / --recreate-lock-file. allowReboot=false matches the
        # darwin side; reboots are handled by hand.
        system.autoUpgrade = {
          enable = true;
          flake = cfg.flakeRef;
          flags = [ "--no-write-lock-file" ];
          dates = "hourly";
          randomizedDelaySec = "45min";
          allowReboot = false;
        };
      }
  );
}
