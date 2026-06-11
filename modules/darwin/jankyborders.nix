{ theme, ... }:
{
  services.jankyborders = {
    enable = true;
    active_color = theme.border.active;
    inactive_color = theme.border.inactive;
    width = 6.0;
    hidpi = true;
    style = "round";
  };
}
