# tuna hardware bring-up: framework desktop, ryzen ai max+ 395 (strix halo).
# purpose: the amd/strix-halo-specific system config the generic nixos-hardware
# framework-desktop profile does not cover. deps: consumed by hosts/tuna, reads
# config.boot.kernelPackages.kernel to build the out-of-tree sensor modules.
#
# WHY out-of-tree sensors: k10temp does not bind this SMN layout, so there is no
# in-tree CPU die temp. zenpower5 is the only tree with Zen5/Strix Halo support
# (nixpkgs zenpower is pre-Zen5 0.1.x); ryzen_smu exposes the SMU pm-table that
# ryzenadj needs for power-limit tuning. both are OOT and rebuild on every kernel
# bump (version pinned to kernel.version), so they are gated behind rice.sensors
# to keep an RC-bump build break contained.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.rice.sensors;
  kernel = config.boot.kernelPackages.kernel;

  # shared OOT builder: both Makefiles compute KERNEL_BUILD from uname and only
  # ship a `modules` target (no nix-friendly install), so override KERNEL_BUILD +
  # TARGET on the command line and drive the KERNEL's own modules_install, which
  # installs the .ko under $out/lib/modules/<ver>/extra regardless of the module
  # Makefile. depmod at system build picks it up via boot.extraModulePackages.
  ootModule =
    {
      pname,
      owner,
      repo,
      rev,
      hash,
    }:
    pkgs.stdenv.mkDerivation {
      inherit pname;
      inherit (kernel) version;
      src = pkgs.fetchFromGitHub {
        inherit
          owner
          repo
          rev
          hash
          ;
      };
      hardeningDisable = [
        "pic"
        "format"
      ];
      nativeBuildInputs = kernel.moduleBuildDependencies;
      makeFlags = [
        "KERNEL_BUILD=${kernel.dev}/lib/modules/${kernel.modDirVersion}/build"
        "TARGET=${kernel.modDirVersion}"
      ];
      installPhase = ''
        runHook preInstall
        make -C ${kernel.dev}/lib/modules/${kernel.modDirVersion}/build \
          M=$(pwd) modules_install INSTALL_MOD_PATH=$out
        runHook postInstall
      '';
      meta.platforms = [ "x86_64-linux" ];
    };

  zenpower5 = ootModule {
    pname = "zenpower5";
    owner = "mattkeenan";
    repo = "zenpower5";
    rev = "66871d8e59c3741e00de2eb1f61c3b64263ed10b";
    hash = "sha256-g0zVTDi5owa6XfQN8vlFwGX+gpRIg+5q1F4EuxAk9Sk=";
  };

  ryzen-smu = ootModule {
    pname = "ryzen_smu";
    owner = "amkillam";
    repo = "ryzen_smu";
    rev = "1be4fb1cd9d60b5ddefc2a4201a898766a731400";
    hash = "sha256-Tj3MZBDtobXAdF07DmqEnaJWCoJ0Xkbn25jqAIWAfoc=";
  };
in
{
  options.rice.sensors.enable = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = "Build + load the OOT Zen5 sensor modules (zenpower5 + ryzen_smu).";
  };

  config = lib.mkMerge [
    {
      # amd_pstate=active gives hardware-managed EPP (best on this mobile-class
      # silicon); prefcore honors the preferred-core ranking. iommu on+pt keeps
      # DMA perf high while still forming groups for kvm. GTT is auto-sized on
      # >=6.16.9, so NO amdgpu.gttsize / ttm.pages_limit here (stale + wrong on a
      # current kernel); keep the BIOS UMA carveout minimal instead.
      boot.kernelParams = [
        "amd_pstate=active"
        "amd_prefcore=1"
        "amd_iommu=on"
        "iommu=pt"
      ];

      # amd_pstate=active wants an EPP-aware scaling governor, not ondemand.
      powerManagement.cpuFreqGovernor = lib.mkDefault "powersave";

      # firmware: rtl8126 (r8126), mt7925 wifi/bt, amdgpu gfx1151 microcode all
      # come from linux-firmware. TODO(deploy): if amdgpu fails to load gfx1151
      # microcode or mt7925 panics, pin a linux-firmware git overlay (>=20260110,
      # avoid 20251125) here; unstable's packaged blob is usually fresh enough.
      hardware.enableRedistributableFirmware = true;
      hardware.enableAllFirmware = true;

      # mt7925 combo carries bluetooth on the same die.
      hardware.bluetooth.enable = true;

      # corectrl for amdgpu clock/power/fan curves; hardware.amdgpu.overdrive sets
      # ppfeaturemask=0xffffffff to unlock overdrive on gfx1151 (the corectrl
      # gpuOverclock option was renamed to this).
      programs.corectrl.enable = true;
      hardware.amdgpu.overdrive.enable = true;

      # framework EC is cros_ec based (fan/thermal/EC comms over LPC). fwupd
      # delivers the EC + BIOS capsules through LVFS.
      boot.kernelModules = [
        "cros_ec_lpcs"
        "cros_ec_dev"
      ];
      services.fwupd.enable = true;

      environment.systemPackages = with pkgs; [
        lm_sensors
        pciutils
        ryzenadj # power-limit tuning; inert without ryzen_smu (loaded below)
        vulkan-tools # vulkaninfo, to confirm RADV on gfx1151
        mesa-demos # glxinfo
        libva-utils # vainfo
      ];
    }

    (lib.mkIf cfg.enable {
      boot.extraModulePackages = [
        zenpower5
        ryzen-smu
      ];
      # zenpower conflicts with k10temp (which is dead on this board anyway).
      boot.blacklistedKernelModules = [ "k10temp" ];
      boot.kernelModules = [
        "zenpower"
        "ryzen_smu"
      ];
    })
  ];
}
