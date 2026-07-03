{ config, pkgs, ... }:
{
  # poll every minute; fire a laptop notification for any reminder that just came due
  launchd.agents.reminders = {
    enable = true;
    config = {
      ProgramArguments = [
        "${pkgs.remind}/bin/remind"
        "notify"
      ];
      StartInterval = 60;
      RunAtLoad = true;
      ProcessType = "Background";
      # a silent agent hides EventKit permission failures; log like every other agent
      StandardOutPath = "${config.home.homeDirectory}/Library/Logs/reminders.log";
      StandardErrorPath = "${config.home.homeDirectory}/Library/Logs/reminders.log";
    };
  };
}
