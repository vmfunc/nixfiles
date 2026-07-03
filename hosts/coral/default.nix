# coral. per-machine SYSTEM layer (always-on office desktop, M5 Pro)
#
# this host is BOTH a clamshell desk machine (external display + keyboard, lid
# closed) AND the always-on remote box when nobody is at the desk. everything
# in modules/darwin/* and modules/shared/* is inherited;
# only the always-on / remote-access deviations live here.
#
# FileVault stays ON. the recovery key lives in sops and planned reboots use
# `fdesetup authrestart` at deploy time so the disk re-unlocks headless. the
# nix side must NOT fight FileVault: there is deliberately NO
# system.defaults.loginwindow.autoLoginUser here (auto-login would defeat FDE).
#
# the macOS application firewall (modules/darwin/firewall.nix) already applies
# with stealth mode on. no inbound allow rule is needed: tailscale and its
# relays are outbound-initiated, and Apple's sshd is reached over the tailnet.
#
# nix.linux-builder is inherited from modules/darwin/linux-builder.nix. this is
# an 18-core / 48 GB box, so it stays a builder host (otter offloads to it).
{
  lib,
  pkgs,
  username,
  ...
}:
{
  # ---------------------------------------------------------------------------
  # always-on power policy
  # ---------------------------------------------------------------------------
  # never sleep: this box must stay reachable on the tailnet at all hours.
  power.sleep = {
    computer = "never";
    display = "never";
    harddisk = "never";
  };

  # restart after a hard freeze is safe and supported on Apple Silicon.
  power.restartAfterFreeze = true;

  # NOTE: power.restartAfterPowerFailure is intentionally NOT set. the pinned
  # nix-darwin (modules/system/checks.nix) runs `systemsetup
  # -getRestartPowerFailure` during activation and HARD-ABORTS (exit 2) when the
  # machine reports "Not supported", which Apple Silicon notebooks do. auto-boot
  # after power loss is instead driven below via `pmset -c autorestart 1`, which
  # skips the systemsetup probe entirely.

  # ---------------------------------------------------------------------------
  # remote access: Apple OpenSSH, pubkey-only, reached over the tailnet
  # ---------------------------------------------------------------------------
  # tailscale is transport only. tailscale ssh stays OFF; auth and
  # access control stay in sshd below.
  services.tailscale.enable = true;

  services.openssh = {
    enable = true;
    # services.openssh exposes only `extraConfig` (lib.types.lines) as the
    # escape hatch; it is written verbatim to sshd_config.d/100-nix-darwin.conf.
    extraConfig = ''
      # pubkey only. no passwords, no keyboard-interactive, no root
      PasswordAuthentication no
      KbdInteractiveAuthentication no
      ChallengeResponseAuthentication no
      PermitRootLogin no
      PubkeyAuthentication yes
      AuthenticationMethods publickey

      # only quaver may log in
      AllowUsers ${username}
      MaxAuthTries 3
      MaxSessions 4
      LoginGraceTime 30

      # modern crypto allowlist (no sha1 kex, no cbc, no umac-64)
      KexAlgorithms curve25519-sha256,curve25519-sha256@libssh.org,sntrup761x25519-sha512@openssh.com
      Ciphers chacha20-poly1305@openssh.com,aes256-gcm@openssh.com,aes128-gcm@openssh.com
      MACs hmac-sha2-512-etm@openssh.com,hmac-sha2-256-etm@openssh.com

      # drop dead/idle sessions so a yanked tailnet link doesn't wedge sshd
      ClientAliveInterval 300
      ClientAliveCountMax 2

      # reduce surface
      X11Forwarding no
      AllowAgentForwarding no
      PermitTunnel no
      PrintLastLog yes
    '';
  };

  # nix-darwin's users.users.<name>.openssh.authorizedKeys exists on the current
  # pin (wired via an AuthorizedKeysCommand reading /etc/ssh/nix_authorized_keys.d),
  # but it only ADDS keys next to ~/.ssh/authorized_keys, which sshd still reads.
  # this shared-office box wants the file OWNED, stray keys evicted on every
  # switch, so the activation script below writes it wholesale instead.
  # two keys: quaver@otter (laptop, interactive login) and the dedicated
  # coral-builder key (otter's root uses it for distributed nix builds, see
  # hosts/otter nix.buildMachines). both are pubkeys; sshd above is pubkey-only.
  # mkBefore, not mkAfter: home-manager's activation runs in this same phase and
  # aborts on the headless launchctl EIO, which would skip an mkAfter block. run
  # the always-on policy first so pmset + authorized_keys apply regardless.
  system.activationScripts.postActivation.text = lib.mkBefore ''
    echo "configuring coral always-on policy..." >&2

    # --- authorized_keys (managed; sshd above is pubkey-only) ---
    ssh_dir="/Users/${username}/.ssh"
    auth_keys="$ssh_dir/authorized_keys"
    ${pkgs.coreutils}/bin/install -d -m 700 -o ${username} -g staff "$ssh_dir"
    printf '%s\n' \
      'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJuUZY9+MFmjGNknQNdjVknnfffU6TqoJaa6ocPdJv7G quaver@otter' \
      'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIC9/RNzQuObS7umy8EfEExl1jIX5i7U7p2AFmzpg3qm7 root@otter->coral-builder' \
      > "$auth_keys"
    ${pkgs.coreutils}/bin/chown ${username}:staff "$auth_keys"
    ${pkgs.coreutils}/bin/chmod 600 "$auth_keys"

    # --- clamshell stay-awake via pmset ---
    # there is NO nix-darwin option for `pmset disablesleep` (the lid-closed
    # override), so drive /usr/bin/pmset directly. sleep/displaysleep/disksleep
    # use "-a" (all power sources): this is a desk box that must never blank or
    # sleep, even on the brief battery window before AC is restored. each setting
    # is idempotent; `|| true` keeps activation from aborting on a transient error.
    pmset=/usr/bin/pmset
    if [ -x "$pmset" ]; then
      echo "applying clamshell always-on pmset policy..." >&2
      "$pmset" -a disablesleep 1 || true    # lid-closed sleep override (global)
      "$pmset" -a sleep 0 || true           # never system-sleep on any source
      "$pmset" -a displaysleep 0 || true    # never blank the office display
      "$pmset" -a disksleep 0 || true
      "$pmset" -c autopoweroff 0 || true
      "$pmset" -c standby 0 || true
      "$pmset" -c powernap 0 || true
      "$pmset" -c womp 1 || true            # wake-on-network so the tailnet can poke it
      "$pmset" -c autorestart 1 || true     # power-loss auto-restart (AC source)
    fi
  '';

  # ---------------------------------------------------------------------------
  # shared-office lock hardening
  # ---------------------------------------------------------------------------
  system.defaults = {
    screensaver = {
      # require the password immediately on screensaver/lock, no grace window,
      # on a machine that sits in a shared office.
      askForPassword = true;
      askForPasswordDelay = 0;
    };

    # no `> console` login from the loginwindow on a shared/remote box.
    loginwindow.DisableConsoleAccess = true;
  };

  # NOTE: the screen-LOCK idle delay (how long before the screensaver/lock
  # engages) has NO system.defaults option in the pinned nix-darwin. it must be
  # set in System Settings, Lock Screen, at deploy. set it DELIBERATELY LONGER
  # than the AFK dashboard idle threshold (home/modules/desktop/dashboard.nix)
  # so the dashboard appears first, then the lock takes over. suggested: lock at
  # ~20 min, dashboard at a shorter threshold.
  # TODO(deploy): System Settings, Lock Screen, set "Start Screen Saver when
  # inactive" = 20 min; "Require password after screen saver begins" = immediately.

  # ---------------------------------------------------------------------------
  # auto-update (rice.autoUpdate option lives in modules/shared/auto-update.nix)
  # ---------------------------------------------------------------------------
  # hourly pull+switch from the promoted deploy branch. flakeRef is left at its
  # default (git+https://git.collar.sh/quaver/nixfiles?ref=deploy).
  rice.autoUpdate.enable = true;
}
