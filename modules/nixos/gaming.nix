# gaming stack, gated behind rice.gaming.enable (default off). steam + a
# gamescope session + gamemode + proton-ge, with nix-gaming's low-latency
# pipewire and SteamOS sysctls. 32-bit RADV comes from hosts/tuna
# hardware.graphics.enable32Bit; the NTSYNC kernel knob for the ntsync
# module below comes from the tuna kernelPatches (nixpkgs only builds it
# for zen kernels).
{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
let
  cfg = config.rice.gaming;
in
{
  # always import the modules (they only add options: services.pipewire.lowLatency
  # and programs.steam.platformOptimizations); both are switched on under mkIf below.
  imports = [
    inputs.nix-gaming.nixosModules.pipewireLowLatency
    inputs.nix-gaming.nixosModules.platformOptimizations
  ];

  options.rice.gaming.enable = lib.mkEnableOption "steam + gamescope + proton gaming stack";

  config = lib.mkIf cfg.enable {
    programs.steam = {
      enable = true;
      gamescopeSession.enable = true;
      extraCompatPackages = [ pkgs.proton-ge-bin ];
      remotePlay.openFirewall = true;
      # SteamOS sysctls (nix-gaming): vm.max_map_count to max-int (dx12 games
      # mmap-spray), tcp_fin_timeout=5 (fast relaunch port reuse), split-lock
      # mitigation off (games hit it, the "mitigation" is a deliberate slowdown).
      platformOptimizations.enable = true;
    };
    programs.gamescope = {
      enable = true;
      capSysNice = true;
    };
    programs.gamemode = {
      enable = true;
      settings = {
        # renice game threads; the setcap/cgroup plumbing comes from enableRenice
        # (default on in the nixos module).
        general.renice = 10;
        # pin amdgpu clocks to high while a game runs (reset on exit). the strix
        # halo iGPU otherwise ramp-lags on load spikes; "accept-responsibility"
        # is gamemode's required opt-in string for touching the gpu at all.
        gpu = {
          apply_gpu_optimisations = "accept-responsibility";
          gpu_device = 0;
          amd_performance_level = "high";
        };
      };
    };

    services.pipewire.lowLatency.enable = true;

    # ntsync: in-kernel NT synchronization primitives, replacing wineserver
    # round-trips (esync/fsync successor; wine 10 + proton-ge 10 pick it up).
    # needs the NTSYNC kconfig, which the tuna kernelPatches force on; on a
    # kernel without it the module-load just no-ops at boot. udev rule makes
    # /dev/ntsync reachable from the logged-in user.
    boot.kernelModules = [ "ntsync" ];
    services.udev.packages = [
      (pkgs.writeTextFile {
        name = "ntsync-udev-rules";
        text = ''KERNEL=="ntsync", MODE="0660", TAG+="uaccess"'';
        destination = "/etc/udev/rules.d/70-ntsync.rules";
      })
    ];

    environment.systemPackages = with pkgs; [
      mangohud
      protonup-qt
      lutris
      heroic
      # ffxiv: XIVLauncher manages its own wine/dxvk prefix and stores the
      # square account in the keyring (niri-flake already wires gnome-keyring).
      xivlauncher
      # pso2: there is NO nix package for the game or the ARKS-Layer tweaker
      # (self-updating windows app). the game itself is the steam build under
      # proton-ge; the tweaker runs outside steam via umu (proton-ge runtime
      # for arbitrary windows exes) or the lutris install script.
      umu-launcher
    ];
  };
}
