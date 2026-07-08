# gaming stack, gated behind rice.gaming.enable (default off). steam + a
# gamescope session + gamemode + proton-ge, with nix-gaming's low-latency
# pipewire. 32-bit RADV comes from hosts/tuna hardware.graphics.enable32Bit.
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
  # always import the module (it only adds the services.pipewire.lowLatency
  # option); the option is switched on under mkIf below.
  imports = [ inputs.nix-gaming.nixosModules.pipewireLowLatency ];

  options.rice.gaming.enable = lib.mkEnableOption "steam + gamescope + proton gaming stack";

  config = lib.mkIf cfg.enable {
    programs.steam = {
      enable = true;
      gamescopeSession.enable = true;
      extraCompatPackages = [ pkgs.proton-ge-bin ];
      remotePlay.openFirewall = true;
    };
    programs.gamescope = {
      enable = true;
      capSysNice = true;
    };
    programs.gamemode.enable = true;

    services.pipewire.lowLatency.enable = true;

    environment.systemPackages = with pkgs; [
      mangohud
      protonup-qt
      lutris
      heroic
    ];
  };
}
