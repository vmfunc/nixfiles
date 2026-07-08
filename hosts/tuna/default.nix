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
        FTRACE_MCOUNT_RECORD = lib.mkForce yes;
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
      };
    }
  ];

  # BPF-LSM only attaches if bpf is in the active lsm list at boot; keep the other
  # stacked LSMs nixos relies on and append bpf.
  boot.kernelParams = [ "lsm=landlock,lockdown,yama,integrity,bpf" ];

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

  # wayland-native greeter -> niri-session. no GNOME/GDM (the Calamares default
  # is replaced wholesale).
  services.greetd = {
    enable = true;
    settings.default_session = {
      command = "${pkgs.tuigreet}/bin/tuigreet --time --remember --cmd niri-session";
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

  time.timeZone = "America/Los_Angeles";
  i18n.defaultLocale = "en_US.UTF-8";
  console.keyMap = "us";

  # tailscale transport only (tailscale ssh stays off; auth is openssh below),
  # same policy as the macs. joins the tailnet for fleet reachability.
  services.tailscale.enable = true;

  # hardened sshd. the Calamares install allowed empty/password auth; the mac
  # pubkeys are already planted (Phase 0) and declared below, so key-only is safe.
  # sudo keeps its password (the loose wheelNeedsPassword=false is dropped).
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

  # roles this pass (options in modules/nixos/{gaming,llm}.nix). autoUpdate stays
  # off (interactive desk box, like otter). sensors (strix-halo.nix) default on.
  rice.gaming.enable = true;
  rice.llm.enable = true;

  # string on nixos; match the installed base so no stateful data-format moves.
  system.stateVersion = "24.11";
}
