# swayosd on-screen display for the niri desktop (tuna): volume/brightness keypresses
# had ZERO visual feedback, so a silent mute (or a bottomed-out volume) looked like
# broken audio. swayosd-server draws a bar on each change; swayosd-client REPLACES the
# raw wpctl/brightnessctl calls in niri.nix so every media-key press pops the OSD.
# themed to the blood rice: near-black panel, mauve progress fill, SQUARE corners,
# hairline surface border, matching mako/waybar.
# ownership: swayosd-server runs as a systemd user service on graphical-session.target
# (same shape as clipse.nix / waybar's systemd unit). the client binary is referenced
# from niri.nix by store path (a `swayosd` let-binding), NOT spawned here.
# cross-file deps: niri.nix binds XF86Audio*/XF86MonBrightness* to swayosd-client and
# drops its old wpctl/brightnessctl volume+brightness binds; theme.nix owns
# rice.theme.colors; playerctl transport keys stay in niri.nix (swayosd handles those
# via --playerctl, but the transport keys give their own app feedback already).
{ config, pkgs, ... }:
let
  c = config.rice.theme.colors;
in
{
  home.packages = [ pkgs.swayosd ];

  # the server must be alive in the session before the client can draw; run it on the
  # graphical-session target so niri brings it up and takes it down with the session.
  # swayosd-libinput-backend is the privileged caps/num-lock path we do NOT use here
  # (needs a system service + udev), so only the plain server runs.
  systemd.user.services.swayosd = {
    Unit = {
      Description = "swayosd on-screen display server";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart = "${pkgs.swayosd}/bin/swayosd-server";
      Restart = "always";
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };

  # swayosd reads a GTK CSS at ~/.config/swayosd/style.css. we override the default
  # rounded pill (border-radius 999px) with the rice: a flat near-black panel, SQUARE
  # corners (radius 0, matching niri's outline windows / mako / waybar), a hairline
  # surface border, soft-grey label/icon, mauve progress fill over a dim trough.
  # class names track the upstream style.scss: window#osd, #container, image, label,
  # progressbar/trough/progress.
  xdg.configFile."swayosd/style.css".text = ''
    window#osd {
      border-radius: 0;
      border: 1px solid ${c.surface1};
      background: alpha(${c.base}, 0.94);
      padding: 4px;
    }

    window#osd #container {
      margin: 16px;
    }

    window#osd image,
    window#osd label {
      color: ${c.text};
    }

    window#osd progressbar:disabled,
    window#osd image:disabled {
      opacity: 0.5;
    }

    window#osd progressbar {
      min-height: 6px;
      border-radius: 0;
      background: transparent;
      border: none;
    }

    window#osd trough {
      min-height: 6px;
      border-radius: 0;
      border: none;
      background: ${c.surface2};
    }

    window#osd progress {
      min-height: 6px;
      border-radius: 0;
      border: none;
      background: ${c.mauve};
    }
  '';
}
