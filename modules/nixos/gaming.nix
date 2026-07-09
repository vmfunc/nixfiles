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

  # pso2tricks: bootstraps the JP client on linux (downloads the ARKS-Layer
  # tweaker into ~/pso2_files, applies the english fan patch). upstream is a
  # single PEP 723 script with a requests dep and no shebang, so a thin exec
  # wrapper beats a full mkDerivation. lives here and not in pkgs/ because
  # pkgs/default.nix is darwin-gated; promote it if pkgs/ ever grows a linux
  # side. pinned by rev; bump by hand when arks-layer moves endpoints.
  pso2tricks =
    let
      py = pkgs.python3.withPackages (p: [ p.requests ]);
      src = pkgs.fetchFromGitHub {
        owner = "SynthSy";
        repo = "pso2tricks.py";
        rev = "263dc00da579d2ac03b0c5303ffab8d3c8749c79";
        hash = "sha256-QpSQf0eqvKbXXQqBZE0v1CmtMR3qTD796GM6qwqoq28=";
      };
    in
    pkgs.writeShellScriptBin "pso2tricks" ''exec ${py}/bin/python3 ${src}/pso2tricks.py "$@"'';
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
      osu-lazer-bin # rhythm; -bin is the prebuilt (avoids the long dotnet build)
      # vulkan post-processing layer (cas/smaa/reshade-fx). the package bundles
      # BOTH arch manifests (vkBasalt.json + vkBasalt32.json), so no separate
      # i686 package. inert unless a game runs with ENABLE_VKBASALT=1; per-user
      # vkBasalt.conf comes from home/modules/desktop/vkbasalt.nix.
      vkbasalt
      goverlay # gui for authoring mangohud/vkbasalt configs, if the hand-rolled ones need tweaking

      # wine-prefix surgery: MMO mods (xiv reshade/penumbra, pso2 tweaker,
      # ragnarok) live INSIDE proton/wine prefixes, not in the nix store.
      # protontricks reaches steam's per-appid proton prefixes; winetricks does
      # the lutris/umu ones. these are the imperative escape hatch the docs
      # (docs/gaming.md) lean on.
      protontricks
      winetricks

      # OG MMOs. runelite (old school runescape) is the only one nixpkgs
      # packages natively, so it is fully declarative. ragnarok online is a
      # wine/lutris install (no package), documented in docs/gaming.md; lutris
      # above is its vehicle.
      runelite
      # ffxiv: XIVLauncher manages its own wine/dxvk prefix and stores the
      # square account in the keyring (niri-flake already wires gnome-keyring).
      xivlauncher
      # pso2 JP: no nix package exists for the game or the ARKS-Layer tweaker
      # (self-updating windows app), so the declarative part stops at tooling.
      # bootstrap: `pso2tricks --tweaker`, then run the tweaker under proton-ge
      # via heroic/umu (arks-layer linux guide); `pso2tricks -p` for the
      # english patch. gameguard tolerates proton but injected dlls are a
      # gamble, so shaders go through vkbasalt, not in-prefix reshade.
      pso2tricks
      umu-launcher
    ];
  };
}
