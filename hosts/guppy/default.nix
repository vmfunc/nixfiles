# guppy: thinkpad t14 gen 6 (lunar lake ultra 7 258V / arc 140V / be201), the
# travel laptop. per-box SYSTEM config only; the shared spine (modules/shared,
# modules/nixos) comes in through mkNixos. same niri rice as tuna, but the
# posture differs where a laptop differs from a desk box: full-disk luks2 with
# yubikey fido2 unlock (hardware.nix), yubikey-only PAM everywhere, a boring
# cached kernel instead of tuna's custom RE build, and real power management.
{
  config,
  lib,
  pkgs,
  inputs,
  username,
  hostname,
  ...
}:
{
  imports = [
    ./hardware.nix
    # lunar lake bring-up: intel cpu/gpu commons + t14 platform quirks. path
    # import instead of the nixosModules attr so the name never drifts.
    "${inputs.nixos-hardware}/lenovo/thinkpad/t14/intel/gen6"
  ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # STOCK cached kernel, deliberately NOT tuna's from-source RE build: any
  # structuredExtraConfig forces a full kernel compile on every nixos-rebuild,
  # which on a laptop is pain for little gain. plain linuxPackages_latest stays
  # substitutable from cache.nixos.org, so rebuilds are fast forever. the RE
  # capabilities that matter day-to-day are ALREADY on in the nixpkgs kernel:
  # KPROBES/UPROBES, FUNCTION_TRACER/DYNAMIC_FTRACE, DEBUG_INFO_BTF + BPF_SYSCALL
  # + BPF_LSM (eBPF/CO-RE), MAGIC_SYSRQ. and the OOT LKMs below build against this
  # kernel's headers fine, they never needed a source build. what stock drops vs
  # tuna: KALLSYMS_ALL, KGDB serial console, KUNIT, NTSYNC (proton falls back to
  # esync). those are VM-lab knobs; flip back to a kernelPatches block here if a
  # specific one is ever needed on metal.
  boot.kernelPackages = pkgs.linuxPackages_latest;
  # bpf must be in the active lsm list at boot for BPF-LSM to attach; append it to
  # the stack nixos ships. no config rebuild, this is a boot param.
  boot.kernelParams = [ "lsm=landlock,lockdown,yama,integrity,bpf" ];

  # azzie's out-of-tree LKMs, built against guppy's kernel from the private kmods
  # monorepo. wired (execve tracer), wired_nvim (editor bridge), wired_banner
  # (boot logs) auto-load; the rest build but load on demand.
  boot.extraModulePackages = builtins.attrValues (
    inputs.kmods.lib.packagesFor config.boot.kernelPackages
  );
  boot.kernelModules = [
    "wired"
    "wired_nvim"
    "wired_banner"
  ];

  # xe2 igpu: media-driver for va-api, vpl for the qsv encode path. enable32Bit
  # for proton/wine (the gaming role wants it).
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
    extraPackages = with pkgs; [
      intel-media-driver
      vpl-gpu-rt
    ];
  };

  # niri + the same lain greeter as tuna (the rice lives in the home layer).
  programs.niri.enable = true;
  environment.sessionVariables = {
    NIXOS_OZONE_WL = "1";
    MOZ_ENABLE_WAYLAND = "1";
  };
  services.greetd = {
    enable = true;
    settings.default_session = {
      command = builtins.concatStringsSep " " [
        "${pkgs.tuigreet}/bin/tuigreet"
        "--time"
        "--remember"
        "--remember-session"
        "--asterisks"
        "--greeting 'present day. present time.'"
        "--theme 'border=magenta;text=lightgray;prompt=magenta;time=magenta;action=magenta;button=magenta;input=lightgray'"
        "--cmd niri-session"
      ];
      user = "greeter";
    };
  };

  # audio: pipewire, no 32-bit (no gaming stack here) and no quantum floor (that
  # was a tuna hda quirk).
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    pulse.enable = true;
  };

  networking.hostName = hostname;
  networking.networkmanager.enable = true;
  # plain resolved, NO pinned-public-DNS dispatcher like tuna: that hack exists
  # for the home gateway's flaky resolver, but a roaming laptop needs the DHCP
  # resolver for captive portals to work at all. if home-wifi DNS stalls get
  # annoying, pin per-connection via nm instead of globally.
  services.resolved.enable = true;

  time.timeZone = "America/Los_Angeles";
  i18n.defaultLocale = "en_US.UTF-8";
  console.keyMap = "us";

  # tailscale transport only, same policy as the rest of the fleet.
  services.tailscale.enable = true;

  # laptop power: ppd for cpu profiles (thinkpad_acpi platform profile aware),
  # thermald so lunar lake boost doesn't cook the chassis, fwupd because lenovo
  # ships firmware (and the fingerprint sensor's) through lvfs. lid close =
  # suspend, then hibernate to the encrypted swap LV after 2h so a bag-stowed
  # laptop lands cold instead of dead.
  services.power-profiles-daemon.enable = true;
  services.thermald.enable = true;
  services.fwupd.enable = true;
  services.logind.settings.Login.HandleLidSwitch = "suspend-then-hibernate";
  systemd.sleep.settings.Sleep.HibernateDelaySec = "2h";

  # yubikey auth: pam_u2f "sufficient" satisfies login/greetd/sudo/swaylock on a
  # touch. a backup password (hashedPassword below) sits BEHIND it as the fallback:
  # pam tries the yubikey first (sufficient, so a touch short-circuits), and only
  # falls through to the password prompt if the token is absent or auth is declined. this is the lesson from the first
  # install, a locked "!" password + any pam/nss breakage = full lockout, so the
  # box now always has a way in that does not depend on the token. THREAT MODEL:
  # gates interactive auth only; disk confidentiality is the luks layer, and
  # physical console compromise (init=/bin/sh) is out of scope because the disk is
  # encrypted. deeper recovery = luks recovery key + installer usb + chroot.
  # origin/appid pinned so a hostname tweak never invalidates the enrolled
  # credential (u2f_keys, committed: it's a public key handle, not a secret).
  security.pam.u2f = {
    enable = true;
    control = "sufficient";
    settings = {
      cue = true;
      origin = "pam://guppy";
      appid = "pam://guppy";
      authfile = "${./u2f_keys}";
    };
  };

  # backup login password, sops-encrypted (recipients: quaver + guppy). neededForUsers
  # stages it into /run/secrets-for-users early enough for hashedPasswordFile below.
  sops.secrets.guppy-password = {
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
    # backup password, the fallback behind pam_u2f. NOT locked: a locked account
    # + a pam/nss hiccup locked azzie out on first install, so the token is primary
    # but never the ONLY way in. the hash lives in sops (secrets/passwords.yaml),
    # NOT in this file, this repo has a PUBLIC mirror and a yescrypt hash of a weak
    # password is crackable offline.
    hashedPasswordFile = config.sops.secrets.guppy-password.path;
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJuUZY9+MFmjGNknQNdjVknnfffU6TqoJaa6ocPdJv7G quaver@otter"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJQJAuMwyenNO3VjYb3PZA2YjJ8HoA7/XsXDw99BHG7N quaver@coral"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFxd+OY2Lhdos2ZxPnMerMBxRXnC7qsgxUw2InR80ye3 quaver@tuna"
    ];
  };

  # roles. the full desk-box toolkit comes on the road: RE/kernel work, local llm,
  # gaming, NAS shares. these cost DISK, not battery: each idles at ~0 and only
  # draws when actively used (llm inference, a game launch), so wall power for
  # those sessions is the ask, not a reason to omit them.
  rice.dev.enable = true;
  rice.ime.enable = true;
  # RE GUI/debug layer (ghidra/cutter/gef/frida/pwntools) is always-on via the
  # shared nixos spine (modules/nixos/re.nix, no toggle), so it's already here.
  # this adds the OOT LKM build toolchain (make/gcc/sparse + KDIR).
  rice.lkm.enable = true;
  # local llm: llama.cpp built with vulkan runs on the arc 140V igpu directly
  # (the module's HSA/rocm override is AMD-only and inert on intel). ollama on
  # auto acceleration. idle service, only draws under inference.
  rice.llm.enable = true;
  # steam + gamescope + proton. NTSYNC knob is in the kernel above.
  rice.gaming.enable = true;
  # NAS SMB shares as lazy systemd automounts (mount on first touch of ~/nas).
  # the two-way workspace/screenshot SYNCS stay OFF: those daemons retry on a
  # loop, which off-lan (the whole point of a laptop) just burns wakeups against
  # an unreachable share. mount on demand when home; re-enable syncs if a
  # tailscale-routed path to the NAS gets set up.
  rice.nas.enable = true;

  # fresh 2026-07-29 install against nixpkgs-unstable; never change post-install.
  system.stateVersion = "25.11";
}
