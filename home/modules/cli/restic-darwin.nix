# script no-ops if the drive is absent
{ config, lib, ... }:
lib.mkIf config.rice.backup.enable {
  launchd.agents.restic-backup = {
    enable = true;
    config = {
      ProgramArguments = [ "${config.rice.backup.command}" ];
      RunAtLoad = true;
      StartOnMount = true;
      StartCalendarInterval = [
        {
          Hour = 14;
          Minute = 0;
        }
      ];
      StandardOutPath = "${config.home.homeDirectory}/Library/Logs/restic-backup.log";
      StandardErrorPath = "${config.home.homeDirectory}/Library/Logs/restic-backup.log";
      ProcessType = "Background";
      LowPriorityIO = true;
    };
  };
}
