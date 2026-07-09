# tuna: framework desktop (ryzen ai max+ 395 / strix halo), the fleet's first
# x86_64-linux host. per-box SYSTEM config only; the shared spine (modules/shared,
# modules/nixos) comes in through mkNixos. niri rice + bleeding-edge RE kernel +
# gaming + local llm. deps: ./hardware.nix (generated), ./strix-halo.nix (amd
# bring-up), nixos-hardware framework profile, inputs.kmods (OOT LKM monorepo).
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
    ./strix-halo.nix
    inputs.nixos-hardware.nixosModules.framework-desktop-amd-ai-max-300-series
  ];

  # systemd-boot, matching the Calamares install we adopt in place.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # bleeding-edge RE/exploit-dev kernel: newest kernel.org mainline RC
  # (linuxPackages_testing) rebuilt with the config knobs azzie's kernel/RE/pwn/
  # CTF work needs. gfx1151 wants >= 6.18.4 for stability, which _testing clears.
  # WHY each knob: KPROBES/KRETPROBES + KALLSYMS_ALL = the kprobe/execsnoop LKMs
  # and the unexported-kallsyms bootstrap; FUNCTION_TRACER/DYNAMIC_FTRACE = ftrace
  # hooking research; UPROBES = userspace tracing; KGDB(+serial) = live kernel
  # debug; IKCONFIG(+PROC) = /proc/config.gz; DEBUG_INFO_BTF + BPF_SYSCALL +
  # BPF_LSM = CO-RE eBPF + a self-authored MAC layer; KUNIT = the selftest module;
  # DEBUG_FS/MAGIC_SYSRQ = the usual lab escape hatches.
  # fallback: if an RC + this config fails to build, drop kernelPatches and use
  # plain pkgs.linuxPackages_testing (still bleeding edge).
  boot.kernelPackages = pkgs.linuxPackages_testing;
  boot.kernelPatches = [
    {
      name = "tuna-re-lab";
      patch = null;
      # mkForce: several of these (e.g. KUNIT=n) are set the other way in nixpkgs
      # common-config, so a plain set is a priority conflict. this is a deliberate
      # custom RE kernel, so force our values to win.
      structuredExtraConfig = with lib.kernel; {
        KPROBES = lib.mkForce yes;
        KRETPROBES = lib.mkForce yes;
        KALLSYMS_ALL = lib.mkForce yes;
        FUNCTION_TRACER = lib.mkForce yes;
        DYNAMIC_FTRACE = lib.mkForce yes;
        UPROBES = lib.mkForce yes;
        KGDB = lib.mkForce yes;
        KGDB_SERIAL_CONSOLE = lib.mkForce yes;
        IKCONFIG = lib.mkForce yes;
        IKCONFIG_PROC = lib.mkForce yes;
        DEBUG_INFO_BTF = lib.mkForce yes;
        BPF_SYSCALL = lib.mkForce yes;
        BPF_LSM = lib.mkForce yes;
        DEBUG_FS = lib.mkForce yes;
        MAGIC_SYSRQ = lib.mkForce yes;
        KUNIT = lib.mkForce module;
        # ntsync for wine/proton (gaming.nix loads it + adds the udev rule).
        # nixpkgs common-config only builds NTSYNC for zen kernels, so the
        # custom kernel has to ask for it itself. landed 6.14, _testing clears.
        NTSYNC = module;
      };
    }
  ];

  # BPF-LSM only attaches if bpf is in the active lsm list at boot; keep the other
  # stacked LSMs nixos relies on and append bpf. pcie_aspm=off stabilises the
  # RTL8126 ethernet on r8169 (aspm link-state churn was flapping enp191s0).
  boot.kernelParams = [
    "lsm=landlock,lockdown,yama,integrity,bpf"
    "pcie_aspm=off"
  ];

  # azzie's out-of-tree LKMs, built against the pinned kernel from her private
  # monorepo. wired (execve tracer), wired_nvim (editor bridge), wired_banner
  # (cute boot logs) auto-load; hello-wired + selftest build but load on demand;
  # pwnmod (VM-only) is excluded from packagesFor entirely.
  boot.extraModulePackages = builtins.attrValues (
    inputs.kmods.lib.packagesFor config.boot.kernelPackages
  );
  boot.kernelModules = [
    "wired"
    "wired_nvim"
    "wired_banner"
  ];

  # RADV vulkan + 32-bit for proton/wine. the nixos-hardware amd profile already
  # brings amdgpu + mesa; extraPackages adds va-api. do NOT add amdvlk (dead).
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
    extraPackages = with pkgs; [
      libva-utils
      libva-vdpau-driver
    ];
  };

  # niri: scrollable-tiling wayland compositor (niri-flake wires the session,
  # portals, polkit, keyring). the rice itself lives in the home layer.
  programs.niri.enable = true;

  # force electron/chromium (vesktop, element, signal, spotify) and firefox/zen
  # onto native wayland, so they honor niri's prefer-no-csd (no client title bars)
  # and render crisp instead of blurry under xwayland.
  environment.sessionVariables = {
    NIXOS_OZONE_WL = "1";
    MOZ_ENABLE_WAYLAND = "1";
  };

  # wayland-native greeter -> niri-session. no GNOME/GDM (the Calamares default
  # is replaced wholesale).
  services.greetd = {
    enable = true;
    settings.default_session = {
      # lain-themed greeter: plum-rose accents (blood palette), asterisks for the
      # password, and a wired greeting. --remember-session too so it keeps niri.
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

  # audio: pipewire (32-bit for proton), replacing the install's pulse=false stub.
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };

  networking.hostName = hostname;
  networking.networkmanager.enable = true;
  # opened at the SYSTEM layer because the syncthing home-manager USER service
  # can't touch the firewall. 22000 = syncthing sync, 21027/udp = syncthing lan
  # discovery. 1990 + 2021/udp = bambu lab LAN-mode SSDP discovery (the printer
  # broadcasts, the slicer listens); direct-IP connect works without them, but
  # discovery does not. avahi/mDNS below resolves the printer hostname on the LAN.
  networking.firewall.allowedTCPPorts = [ 22000 ];
  networking.firewall.allowedUDPPorts = [
    22000
    21027
    1990
    2021
  ];
  # mDNS so bambu-studio/orca can find the printer by name on the LAN, and so the
  # box is itself resolvable. openFirewall opens 5353/udp for it.
  services.avahi = {
    enable = true;
    nssmdns4 = true;
    openFirewall = true;
  };
  # wifi power-save off: the mt7925 is unstable with it on (drops/flaps under
  # nm's default powersave), which kept killing ssh + downloads.
  networking.networkmanager.wifi.powersave = false;

  # robust DNS. first boot came up with routing working (1.1.1.1 pingable) but
  # name resolution dead, which broke every fetch. hand resolution to
  # systemd-resolved (NM integrates with it) and give it public fallbacks so a
  # DHCP hiccup or a half-populated resolv.conf can never kill DNS again.
  services.resolved = {
    enable = true;
    settings.Resolve.FallbackDNS = [
      "1.1.1.1"
      "9.9.9.9"
    ];
  };

  time.timeZone = "America/Los_Angeles";
  i18n.defaultLocale = "en_US.UTF-8";
  console.keyMap = "us";

  # tailscale transport only (tailscale ssh stays off; auth is openssh below),
  # same policy as the macs. joins the tailnet for fleet reachability.
  services.tailscale.enable = true;

  # passwordless sudo for wheel. WHY: this is a personal single-user box behind
  # key-only ssh (below), the calamares user password is unreliable across the
  # us/ch keyboard layout, and rebuilds need root non-interactively. the security
  # boundary here is ssh key auth, not the local sudo prompt.
  security.sudo.wheelNeedsPassword = false;

  # hardened sshd. the Calamares install allowed empty/password auth; the mac
  # pubkeys are already planted (Phase 0) and declared below, so key-only is safe.
  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      PermitRootLogin = "prohibit-password";
    };
  };
  users.users.${username}.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJuUZY9+MFmjGNknQNdjVknnfffU6TqoJaa6ocPdJv7G quaver@otter"
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJQJAuMwyenNO3VjYb3PZA2YjJ8HoA7/XsXDw99BHG7N quaver@coral"
  ];

  # roles (options in modules/nixos/{gaming,llm}.nix). autoUpdate stays off
  # (interactive desk box, like otter). sensors (strix-halo.nix) default on.
  # re-enabled now that the box booted the new kernel (r8126 stabilised the
  # network), so the multi-GB steam/proton/rocm/ollama closure can pull reliably.
  rice.gaming.enable = true;
  # console/PC emulation + retro-computing toys (module: modules/nixos/retro.nix)
  rice.retro.enable = true;
  # fcitx5 + mozc japanese input (module: modules/nixos/ime.nix). JP PSO2 + JP tv.
  rice.ime.enable = true;
  # self-hosted media servers, tailnet-only (module: modules/nixos/media-servers.nix)
  rice.mediaServers.jellyfin.enable = true;
  rice.mediaServers.manga.enable = true;
  rice.llm.enable = true;

  # android container for gacha / mobage. needs kernel binderfs, which tuna's
  # kernel has (CONFIG_ANDROID_BINDERFS=y); the waydroid nixos module asserts it.
  virtualisation.waydroid.enable = true;
  # usb + kdeconnect + ANCS notification mirroring (module: modules/nixos/iphone.nix)
  rice.iphone.enable = true;
  # docker + compose + node, so docker-compose dev stacks boot (module: dev.nix)
  rice.dev.enable = true;

  # cap per-build core count. 32 threads, but ONE memory-hungry compile
  # (libslic3r/CGAL: template-hell, ~3GB per cc1plus) at -j32 = ~90GB peak, which
  # OOM-thrashed the 64GB box. -j8 keeps a heavy build's peak RAM ~24GB;
  # max-jobs (auto) still parallelises across separate derivations.
  nix.settings.cores = 8;

  # string on nixos; match the installed base so no stateful data-format moves.
  system.stateVersion = "24.11";
}
