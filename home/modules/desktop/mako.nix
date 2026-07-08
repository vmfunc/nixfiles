# mako notifications for the niri desktop (tuna): the lain console register in a
# notification. flat sheer near-black panel, hairline mauve outline, SQUARE corners
# (niri went square + outline borders, a rounded bubble here would break the set),
# JetBrainsMono like waybar, accent title over soft-grey body like the bar's
# FIELD:value two-tone. colors come from rice.theme.colors so a theme.nix variant
# swap recolors notifications with the rest of the rice.
# ownership: this hm rev's services.mako writes ~/.config/mako/config (+ makoctl
# reload on change) and installs the package but ships NO systemd user unit, so
# niri.nix spawn-at-startup stays the single process owner; dbus activation never
# fires because the spawned instance already owns org.freedesktop.Notifications.
# cross-file deps: theme.nix owns rice.theme.colors; niri.nix spawns the daemon and
# shares the Papirus-Dark icon name (gtk.iconTheme); waybar.nix sets the register.
{ config, pkgs, ... }:
let
  c = config.rice.theme.colors;
in
{
  services.mako = {
    enable = true;
    settings = {
      # top-right under the waybar strip; mako is on the `top` layer so it respects
      # the bar's exclusive zone, and 12 matches niri's gaps so panels line up.
      anchor = "top-right";
      layer = "top";
      margin = "12";
      width = 380;
      height = 160;
      padding = "10,14";
      max-visible = 5;

      font = "JetBrainsMono Nerd Font 10";
      # sheer near-black like fuzzel's panel (same f2 alpha) with a 2px accent
      # outline at radius 0, the exact frame treatment niri draws on windows.
      background-color = "${c.base}f2";
      text-color = c.text;
      border-size = 2;
      border-color = c.mauve;
      border-radius = 0;
      # accent title, soft body: the notification's FIELD:value split.
      format = ''<b><span color='${c.mauve}'>%s</span></b>\n%b'';
      progress-color = "over ${c.surface1}";

      icons = true;
      max-icon-size = 48;
      # same icon set gtk/fuzzel use, so app icons in notifications match the desktop.
      icon-path = "${pkgs.papirus-icon-theme}/share/icons/Papirus-Dark";

      default-timeout = 6000;

      # low fades into the surface tones; critical takes the reserved alarm red and
      # stays up until dismissed (red is the lone alarm in the wired palettes).
      "urgency=low" = {
        border-color = c.surface2;
        format = ''<b><span color='${c.subtext0}'>%s</span></b>\n%b'';
      };
      "urgency=critical" = {
        border-color = c.red;
        format = ''<b><span color='${c.red}'>%s</span></b>\n%b'';
        default-timeout = 0;
      };
    };
  };
}
