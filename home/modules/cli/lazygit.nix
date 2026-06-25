{ ... }:
{
  # catppuccin is OFF for the wired variants. drive lazygit's theme with NAMED ansi colors, not
  # hex, so it paints from the terminal's 16 slots (wezterm fills those from theme.ansi16).
  # magenta = the gold accent slot (active border / selection), yellow = secondary, red = rust.
  programs.lazygit = {
    enable = true;
    settings.gui.theme = {
      activeBorderColor = [
        "magenta"
        "bold"
      ];
      inactiveBorderColor = [ "white" ];
      searchingActiveBorderColor = [
        "yellow"
        "bold"
      ];
      optionsTextColor = [ "blue" ];
      selectedLineBgColor = [ "reverse" ];
      cherryPickedCommitFgColor = [ "magenta" ];
      cherryPickedCommitBgColor = [ "yellow" ];
      markedBaseCommitFgColor = [ "magenta" ];
      markedBaseCommitBgColor = [ "yellow" ];
      unstagedChangesColor = [ "red" ];
      defaultFgColor = [ "default" ];
    };
  };
}
