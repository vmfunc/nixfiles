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
# shares the Papirus-Dark icon name (gtk.iconTheme); waybar/ sets the register.
{ config, pkgs, ... }:
let
  c = config.rice.theme.colors;
  # rice.look (theme.nix) is the one switch; niri and fuzzel read the same one.
  soft = config.rice.look == "soft";
in
{
  services.mako = {
    enable = true;
    settings = {
      # top-right under the waybar strip; mako is on the `top` layer so it respects
      # the bar's exclusive zone, and 12 matches niri's gaps so panels line up.
      anchor = "top-right";
      layer = "top";
      # soft: the bar floats now (margin-top 8), so notifications need to clear it
      # by more than the old flush-strip 12 or they tuck under the pills.
      margin = if soft then "16" else "12";
      width = if soft then 400 else 380;
      height = 160;
      padding = if soft then "14,18" else "10,14";
      max-visible = 5;

      font = "JetBrainsMono Nerd Font 10";
      # sheer near-black like fuzzel's panel (the SAME alpha in both looks, so the
      # two surfaces read as one material) framed the way niri frames windows:
      # square + 2px accent in hairline, or a rounded hairline in soft, where a
      # thick outline at radius 14 would read as a sticker.
      background-color = "${c.base}${if soft then "e6" else "f2"}";
      text-color = c.text;
      border-size = if soft then 1 else 2;
      border-color = if soft then "${c.mauve}80" else c.mauve;
      border-radius = if soft then 14 else 0;
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
