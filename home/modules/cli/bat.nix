{ ... }:
{
  # catppuccin is OFF for the wired variants, so bat lost its themed .tmTheme. point it at the
  # built-in "ansi" theme: it paints from the terminal's 16 ANSI slots, which wezterm fills from
  # theme.ansi16. no hardcoded hex here, the variant's amber/crimson ANSI carries it.
  programs.bat = {
    enable = true;
    config = {
      theme = "ansi";
      style = "numbers,changes,header";
      map-syntax = [
        "*.s:Assembly"
        "*.asm:Assembly"
      ];
    };
  };
}
