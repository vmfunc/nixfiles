{ config, lib, ... }:
lib.mkIf config.rice.backup.enable {
  systemd.user.services.restic-backup = {
    Unit.Description = "restic backup to easystore";
    Service = {
      Type = "oneshot";
      ExecStart = "${config.rice.backup.command}";
    };
  };
  systemd.user.timers.restic-backup = {
    Unit.Description = "Daily restic backup to easystore";
    Timer = {
      OnCalendar = "daily";
      Persistent = true;
    };
    Install.WantedBy = [ "timers.target" ];
  };
}
