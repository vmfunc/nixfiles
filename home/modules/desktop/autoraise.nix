# brew build lacks EXPERIMENTAL_FOCUS_FIRST so focusDelay is a no-op; use raise args
# TODO(deploy): grant AutoRaise the Accessibility permission on first run
# (System Settings > Privacy & Security > Accessibility); nix can't grant TCC.
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
