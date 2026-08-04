# minnow: framework 12 (13th-gen intel U, 12.2" 1920x1200 touch + stylus), the
# convertible. same travel posture as guppy (luks2 + fido2 target, yubikey PAM
# with a sops backup password behind it, stock cached kernel, key-only sshd,
# real power management) plus the touch layer: rice.tablet (iio rotation + a
# plasma 6 second session for tablet posture), rice.reading, and the notes/ink
# stack in the home layer. per-box SYSTEM config only; the shared spine
# (modules/shared, modules/nixos) comes in through mkNixos.
{
  config,
  pkgs,
  inputs,
  username,
  hostname,
  ...
}:
{
  imports = [
    ./hardware.nix
    # framework 12 bring-up: intel commons + the 12-inch platform quirks
    # (touchscreen/sensor hid, ec, audio). path import instead of the
    # nixosModules attr so the name never drifts.
    "${inputs.nixos-hardware}/framework/12-inch/13th-gen-intel"
  ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # STOCK cached kernel, same reasoning as guppy: any structuredExtraConfig
  # forces a from-source kernel build on every rebuild, pain on a laptop for
  # VM-lab knobs it does not need. linuxPackages_latest stays substitutable
  # from cache.nixos.org, and the OOT LKMs build against its headers fine.
  boot.kernelPackages = pkgs.linuxPackages_latest;
  # bpf must be in the active lsm list at boot for BPF-LSM to attach.
  boot.kernelParams = [ "lsm=landlock,lockdown,yama,integrity,bpf" ];

  # azzie's out-of-tree LKMs from the private kmods monorepo, built against
  # minnow's kernel. wired/wired_nvim/wired_banner auto-load, the rest build
  # but load on demand.
  boot.extraModulePackages = builtins.attrValues (
    inputs.kmods.lib.packagesFor config.boot.kernelPackages
  );
  boot.kernelModules = [
    "wired"
    "wired_nvim"
    "wired_banner"
  ];

  # raptor lake igpu (iris xe): media-driver for va-api, vpl for the qsv encode
  # path. enable32Bit for proton (rice.gaming below).
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
    extraPackages = with pkgs; [
      intel-media-driver
      vpl-gpu-rt
    ];
  };

  # niri daily + plasma 6 for tablet posture (rice.tablet.plasmaSession). the
  # shared SDDM greeter (modules/nixos/greeter.nix) shows both as selectable
  # sessions and its graphical login is touch-friendly on the convertible; niri
  # stays the default session.
  programs.niri.enable = true;
  environment.sessionVariables = {
    NIXOS_OZONE_WL = "1";
    MOZ_ENABLE_WAYLAND = "1";
  };
  # audio: pipewire, plain (no 32-bit quirk, no quantum floor; those were
  # tuna-isms). rice.gaming brings its own low-latency layer.
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    pulse.enable = true;
  };

  networking.hostName = hostname;
  networking.networkmanager.enable = true;
  # plain resolved, same reasoning as guppy: a roaming laptop needs the DHCP
  # resolver for captive portals to work at all.
  services.resolved.enable = true;

  time.timeZone = "America/Los_Angeles";
  i18n.defaultLocale = "en_US.UTF-8";
  console.keyMap = "us";

  # tailscale transport only, fleet policy. TODO(deploy): `tailscale up` once
  # at migration (minnow and guppy both join the tailnet then).
  services.tailscale.enable = true;

  # laptop power: ppd for cpu profiles, thermald so the 13th-gen U boost does
  # not cook a 12-inch chassis, fwupd because framework ships firmware through
  # lvfs. lid close = suspend, then hibernate after 2h so a bag-stowed
  # convertible lands cold instead of dead.
  services.power-profiles-daemon.enable = true;
  services.thermald.enable = true;
  services.fwupd.enable = true;
  services.logind.settings.Login.HandleLidSwitch = "suspend-then-hibernate";
  systemd.sleep.settings.Sleep.HibernateDelaySec = "2h";

  # yubikey auth, same shape and same lesson as guppy: pam_u2f "sufficient" so
  # a touch short-circuits, with the sops backup password BEHIND it as the
  # fallback, never a locked account. THREAT MODEL: gates interactive auth
  # only; disk confidentiality is the luks layer (hardware.nix). origin/appid
  # pinned so a hostname tweak never invalidates the enrolled credential.
  # TODO(deploy): enroll on the box (`pamu2fcfg -o pam://minnow -i pam://minnow`)
  # and commit the resulting u2f_keys line (public key handle, not a secret);
  # until then the empty authfile just falls through to the password.
  security.pam.u2f = {
    enable = true;
    control = "sufficient";
    settings = {
      cue = true;
      origin = "pam://minnow";
      appid = "pam://minnow";
      authfile = "${./u2f_keys}";
    };
  };

  # backup login password, sops-encrypted (hash in secrets/passwords.yaml;
  # recipients are the current fleet keys). TODO(deploy): rekey the secrets to
  # minnow's age key at migration, before first switch on the box.
  sops.secrets.minnow-password = {
    sopsFile = ../../secrets/passwords.yaml;
    neededForUsers = true;
  };

  # hardened sshd from first boot: key-only, no passwords ever on this box.
  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      PermitRootLogin = "prohibit-password";
    };
  };
  users.users.${username} = {
    # backup password behind pam_u2f, NOT locked (guppy's first-install lesson:
    # locked account + pam/nss hiccup = full lockout). hash lives in sops, this
    # repo has a public mirror.
    hashedPasswordFile = config.sops.secrets.minnow-password.path;
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJuUZY9+MFmjGNknQNdjVknnfffU6TqoJaa6ocPdJv7G quaver@otter"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJQJAuMwyenNO3VjYb3PZA2YjJ8HoA7/XsXDw99BHG7N quaver@coral"
      # the tuna keypair is also guppy's working key, so this one line admits
      # both linux boxes
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFxd+OY2Lhdos2ZxPnMerMBxRXnC7qsgxUw2InR80ye3 quaver@tuna"
    ];
  };

  # roles. the road kit minus llm: 13th-gen U igpu inference is slow enough to
  # be a battery tax with no payoff, tuna serves models over tailscale instead.
  rice.dev.enable = true;
  rice.ime.enable = true;
  # RE GUI/debug layer is always-on via the shared spine (modules/nixos/re.nix);
  # this adds the OOT LKM build toolchain.
  rice.lkm.enable = true;
  # steam + gamescope + proton: light/retro gaming + streaming from tuna.
  rice.gaming.enable = true;
  # emulation + retro-computing corner, the couch half of convertible life.
  rice.retro.enable = true;
  # NAS SMB shares as lazy automounts; the two-way syncs stay off (roaming box,
  # same reasoning as guppy).
  rice.nas.enable = true;
  rice.kdeconnect.enable = true;
  # tor client + browser: hostile hotel/conference wifi is where laptops live.
  rice.tor.enable = true;
  # the touch layer: iio rotation source + plasma 6 tablet session (system
  # half; the session glue is rice.tablet in home/minnow.nix).
  rice.tablet.enable = true;
  rice.tablet.plasmaSession = true;
  # koreader/sioyek/newsflash; the fleet-wide reading apps come from apps.nix.
  rice.reading.enable = true;

  # bluez daemon + blueman's dbus mechanism (clients ship from the apps layer).
  hardware.bluetooth.enable = true;
  services.blueman.enable = true;

  # TODO(deploy): set to the stateVersion of the interim install already on the
  # box (read it out of its /etc/nixos before the first switch); never change
  # post-adoption.
  system.stateVersion = "25.11";
}
