{
  pkgs,
  username,
  hostname,
  ...
}:
{
  system.stateVersion = 6;
  system.primaryUser = username;

  networking.hostName = hostname;
  networking.computerName = hostname;

  system.keyboard = {
    enableKeyMapping = true;
    remapCapsLockToEscape = true;
  };

  environment.systemPackages = with pkgs; [
    git
    curl
    jq
  ];

  nix.gc.interval = {
    Weekday = 0;
    Hour = 3;
    Minute = 15;
  };
  nix.optimise.interval = {
    Weekday = 0;
    Hour = 3;
    Minute = 45;
  };
}
