{
  config,
  lib,
  pkgs,
  username,
  hostname,
  ...
}:
let
  cfg = config.rice.autoUpdate;

  # the rice.autoUpdate option lives in modules/shared because it belongs to every
  # host, but both hosts are macs, so the implementation is a single system-level
  # launchd daemon (below). a future nixos host would fork the config here again.
  homeDir = "/Users/${username}";

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
  # binaries are absolute paths (store paths, or OS-fixed /bin and /usr/bin
  # tools) so the script does not depend on PATH; the one exception is the nix
  # CLI, which darwin-rebuild shells out to and which is added to PATH
  # explicitly above.
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
    # WHY /usr/bin/pgrep (OS-fixed, adv_cmds): darwin's pkgs.procps is unixtools
    # procps, which ships no pgrep at all, so the store-path form execs to 127
    # and the guard never fires. WHY -f, not -x: darwin-rebuild is a bash shebang
    # script, its p_comm is "bash", so an exact name match can never see it; only
    # a full-argv match does. a -f false positive just skips one hourly cycle.
    if /usr/bin/pgrep -f darwin-rebuild >/dev/null 2>&1; then
      exit 0
    fi

    # cheap change check: ls-remote the deploy ref and compare to the stamp.
    # if HEAD has not moved since the last successful switch, do nothing. this
    # keeps the common (idle) hour from spending a full eval.
    # flakeRef is git+https://host/path?ref=BRANCH, but `git ls-remote` needs a
    # plain url + ref: strip the git+ scheme prefix and the ?ref= query.
    git_url=$(${pkgs.coreutils}/bin/printf '%s' "$flake_ref" | ${pkgs.gnused}/bin/sed -E 's/^git\+//; s/\?.*$//')
    git_ref=$(${pkgs.coreutils}/bin/printf '%s' "$flake_ref" | ${pkgs.gnused}/bin/sed -nE 's/.*[?&]ref=([^&]+).*/\1/p')
    [ -z "$git_ref" ] && git_ref="HEAD"
    remote=$(${pkgs.git}/bin/git ls-remote "$git_url" "refs/heads/$git_ref" 2>>"${logFile}" \
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

    # PIN the exact rev ls-remote just reported. resolving `?ref=deploy` (even
    # with --refresh) was observed to still build a STALE commit while step 4
    # stamped the fresh rev, leaving the box silently behind forever. appending
    # &rev=<sha> forces nix to evaluate exactly the commit that gets stamped, so
    # build, activation, and stamp are always the same tree. --refresh stays as a
    # belt so the underlying git fetch can't serve a cached pack without the rev.
    pinned_ref="$flake_ref&rev=$remote"

    # 1. build the new system toplevel FIRST. a broken commit on deploy fails
    #    here (real failure): page the user and leave the stamp untouched so it
    #    retries next hour. nothing is activated, so the box is never taken down.
    if ! ${pkgs.nix}/bin/nix build --refresh "$pinned_ref#darwinConfigurations.$flake_attr.system" \
        --no-link --print-out-paths >/dev/null 2>>"${logFile}"; then
      # WHY sudo -H, not launchctl asuser: asuser only adopts the user's mach
      # bootstrap namespace, never the uid or env (launchctl(1)), so remind ran
      # as root and paged root's store, which the user's reminders agent never
      # reads. root sudo needs no password or tty, -H resolves the user's HOME,
      # and `add` touches no mach services so the bootstrap context is unneeded.
      /usr/bin/sudo -u ${lib.escapeShellArg username} -H ${pkgs.remind}/bin/remind \
        add "nixfiles auto-update BUILD failed for $flake_attr, see ${logFile}" >/dev/null 2>&1 || true
      exit 1
    fi

    # 2. activate the SAME pinned rev. the build is cached now, so this only
    #    switches. the headless launchctl bootstrap of home-manager GUI agents
    #    fails with EIO (a root daemon has no aqua session) and returns non-zero
    #    even though the system + hm files/secrets activated, so do NOT gate
    #    success on the exit code.
    "${darwinRebuild}" switch --flake "$pinned_ref#$flake_attr" >>"${logFile}" 2>&1 || true

    # 3. re-assert home-manager GUI agents into the active console session. this
    #    is the one thing the headless activation cannot do, and it is what stops
    #    the rebuild from leaving the rice booted-out (bootout succeeds, bootstrap
    #    EIO -> agent dead) on a desk box that is also used at the keyboard.
    cuid=$(/usr/bin/stat -f%u /dev/console 2>/dev/null || true)
    if [ -n "$cuid" ] && [ "$cuid" != "0" ]; then
      cuser=$(${pkgs.coreutils}/bin/id -un "$cuid" 2>/dev/null || true)
      # source the generation from the SYSTEM that was just activated, not from
      # the user's standalone hm profile. a headless `darwin-rebuild switch` does
      # not advance ~/.local/state/nix/profiles/home-manager, so reading there
      # re-links the PREVIOUS generation's agents every hour (e.g. a syncthing
      # agent stuck on an old folder topology). the current-system closure always
      # holds exactly the generation that was deployed this run.
      hmgen=$(${pkgs.nix}/bin/nix-store -qR /run/current-system 2>/dev/null \
        | ${pkgs.gnugrep}/bin/grep -m1 'home-manager-generation' || true)
      if [ -n "$hmgen" ] && [ -d "$hmgen/LaunchAgents" ]; then
        # keep the standalone profile pointer in step with the deployed gen so
        # the pointer never lies and any other tooling reading it sees the truth.
        /bin/launchctl asuser "$cuid" ${pkgs.nix}/bin/nix-env \
          -p "/Users/$cuser/.local/state/nix/profiles/home-manager" --set "$hmgen" >/dev/null 2>&1 || true
        for p in "$hmgen/LaunchAgents"/*.plist; do
          # bash leaves an unmatched glob as the literal pattern (no nullglob in
          # a writeShellScript), so an empty LaunchAgents dir would symlink a
          # dangling '*.plist' into the user's LaunchAgents and drive launchctl
          # with a garbage label. skip the literal pattern.
          [ -e "$p" ] || continue
          label=$(${pkgs.coreutils}/bin/basename "$p" .plist)
          ${pkgs.coreutils}/bin/ln -sf "$p" "/Users/$cuser/Library/LaunchAgents/$label.plist"
          /bin/launchctl asuser "$cuid" /bin/launchctl bootout "gui/$cuid/$label" 2>/dev/null || true
          /bin/launchctl asuser "$cuid" /bin/launchctl bootstrap "gui/$cuid" "$p" 2>/dev/null || true
          # bootstrap can return EIO from a root daemon and register the agent
          # WITHOUT spawning its RunAtLoad process (seen with syncthing): the
          # daemon is left dead until something forces it. kickstart -k forces the
          # (re)start, so a long-lived agent actually comes back after a switch.
          /bin/launchctl asuser "$cuid" /bin/launchctl kickstart -k "gui/$cuid/$label" 2>/dev/null || true
        done
      fi
    fi

    # 4. build succeeded and the toplevel is activated -> deployed. stamp so this
    #    commit is not redone next hour.
    ${pkgs.coreutils}/bin/mkdir -p "${stampDir}"
    ${pkgs.coreutils}/bin/printf '%s\n' "$remote" > "${stampFile}"
  '';
in
{
  options.rice.autoUpdate = {
    enable = lib.mkEnableOption "hourly automatic deploy from the nixfiles deploy branch";

    flakeRef = lib.mkOption {
      type = lib.types.str;
      default = "git+https://git.collar.sh/quaver/nixfiles?ref=deploy";
      description = ''
        Flake reference the updater deploys from. WHY a separate `deploy` branch:
        the updater ls-remotes this ref and only switches when it moves, so a
        `deploy` branch must actually exist on the forge before anything happens.
        promote `main` to `deploy` to ship. otter intentionally leaves
        rice.autoUpdate disabled so it is never auto-switched out from under a
        working session; coral opts in.
      '';
    };

    intervalSec = lib.mkOption {
      type = lib.types.int;
      default = 3600;
      description = "Seconds between auto-update checks.";
    };
  };

  # system-level launchd DAEMON (root), not a home-manager agent: only root can
  # activate a generation. daemons take .serviceConfig (the raw plist), unlike
  # home-manager's launchd.agents.<name>.config.
  config = lib.mkIf cfg.enable {
    launchd.daemons.nixfiles-autoupdate = {
      serviceConfig = {
        ProgramArguments = [ "${darwinUpdate}" ];
        StartInterval = cfg.intervalSec;
        RunAtLoad = false;
        StandardOutPath = logFile;
        StandardErrorPath = logFile;
      };
    };
  };
}
