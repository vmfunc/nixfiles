{ ... }:
{
  # catppuccin is OFF for the wired variants. btop's built-in "TTY" theme paints from the
  # terminal's 16 ANSI slots (wezterm fills those from theme.ansi16), so the amber/crimson set
  # carries through with no hardcoded hex. theme_background off keeps the warm-black terminal bg.
  programs.btop = {
    enable = true;
    settings = {
      color_theme = "TTY";
      theme_background = false;
    };
  };
}
