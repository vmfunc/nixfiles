# brew build lacks EXPERIMENTAL_FOCUS_FIRST so focusDelay is a no-op; use raise args
# needs Accessibility permission on first run
{ config, ... }:
{
  launchd.agents.autoraise = {
    enable = true;
    config = {
      ProgramArguments = [
        "/opt/homebrew/bin/AutoRaise"
        "-delay"
        "1"
        "-pollMillis"
        "20"
        "-requireMouseStop"
        "false"
      ];
      RunAtLoad = true;
      KeepAlive = true;
      StandardOutPath = "${config.home.homeDirectory}/Library/Logs/autoraise.log";
      StandardErrorPath = "${config.home.homeDirectory}/Library/Logs/autoraise.log";
    };
  };
}
