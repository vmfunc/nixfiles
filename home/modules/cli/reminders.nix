{ pkgs, ... }:
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
    };
  };
}
