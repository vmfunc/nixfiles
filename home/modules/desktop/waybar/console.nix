# the console look: the lain status-console, verbatim as it stood before the
# islands redesign. flat near-black hairline strip pinned to the top edge, NO
# floating pills, square corners, FIELD:value readouts in the copland-os register
# (dimmed all-caps field label + accent value). the LINUX twin of the mac's
# sketchybar (sketchybar/sketchybarrc).
#
# a plain function, not a module: waybar/default.nix picks one look and hands it
# the palette, the option set and the shared data scripts.
{
  c,
  lib,
  pkgs,
  cfg,
  scripts,
  # accepted-and-ignored: islands.nix uses these for tablet touch buttons, and
  # default.nix hands the same arg set to whichever look is active.
  tablet ? false,
  couch ? false,
}:
let
  # console register: a dimmed all-caps FIELD label + an accent VALUE, two-toned in one
  # pango span pair exactly like sketchybar's icon(field)/label(value) split. waybar renders
  # every module `format` through pango markup, so the built-in modules get the split too.
  field = label: "<span color='${c.subtext0}'>${label}</span>";
  value = color: v: "<span color='${color}'>${v}</span>";
in
{
  settings = {
    layer = "top";
    position = "top";
    height = 26;
    # flat strip, no float: spacing lives in per-module padding, not gaps between pills.
    spacing = 0;

    # left: workspace tape + focused-window readout, mirroring sketchybar's
    # space.* tape -> sep.app "::" -> front_app "APP:<name>".
    modules-left = [
      "niri/workspaces"
      "custom/sep"
      "niri/window"
    ];
    modules-center = [ "clock" ];
    # right: the same console field stack as sketchybarrc, extended with the
    # now-playing transport (prev / NP-as-play-pause / next), thermals off the
    # zenpower Tdie, root disk, an idle inhibitor and the privacy dots.
    modules-right = [
      "custom/media-prev"
      "mpris"
      "custom/media-next"
      "cpu"
      "memory"
      "temperature"
      "disk"
      "network"
    ]
    # BAT sits after NET, before VOL, on the hosts that opt in (guppy).
    ++ lib.optional cfg.battery.enable "battery"
    ++ lib.optional cfg.water.enable "custom/water"
    ++ lib.optional cfg.meds.enable "custom/meds"
    ++ [
      "pulseaudio"
      "idle_inhibitor"
      "custom/eorzea"
      "privacy"
      "tray"
    ];

    "niri/workspaces".format = "{index}";

    # the "::" divider between the tape and the app readout (sketchybar sep.app).
    "custom/sep" = {
      format = "::";
      tooltip = false;
    };

    # APP:<focused title>, the mac's front_app readout. {title} is markup-substituted
    # into the accent value slot; max-length keeps a long title from eating the bar.
    "niri/window" = {
      max-length = 48;
      format = "${field "APP:"} ${value c.mauve "{title}"}";
    };

    clock = {
      format = "${field "TIME:"} ${value c.text "{:%a %d %b %H:%M}"}";
      format-alt = "${field "TIME:"} ${value c.text "{:%H:%M:%S}"}";
      tooltip-format = "<tt><small>{calendar}</small></tt>";
    };

    cpu = {
      format = "${field "CPU:"} ${value c.mauve "{usage}%"}";
      interval = 3;
    };

    memory = {
      format = "${field "MEM:"} ${value c.green "{percentage}%"}";
      interval = 5;
    };

    network = {
      format-wifi = "${field "NET:"} ${value c.mauve "{bandwidthDownBytes}"}";
      format-ethernet = "${field "NET:"} ${value c.mauve "{bandwidthDownBytes}"}";
      format-disconnected = "${field "NET:"} ${value c.subtext0 "DOWN"}";
      interval = 3;
      tooltip-format = "{ifname}: {ipaddr}";
    };

    pulseaudio = {
      format = "${field "VOL:"} ${value c.mauve "{volume}%"}";
      format-muted = "${field "VOL:"} ${value c.subtext0 "MUTE"}";
      on-click = "${pkgs.pavucontrol}/bin/pavucontrol";
    };

    # clicking it counts a glass, same as the notification's button. the shared
    # script emits json (text + class), so the label lives here and the color
    # lives in css, per class.
    #
    # the trailing/leading space in these two formats is deliberate and is NOT
    # decoration: a diagnostic background on #custom-water / #custom-meds paints
    # nothing, so waybar 0.15 is not handing these json cells the id the
    # stylesheet asks for, and the css padding every other cell gets never lands.
    # without the literal space they render flush against their neighbours
    # ("H2O: 1MEDS").
    "custom/water" = {
      exec = "${scripts.waterCell}";
      return-type = "json";
      format = "${field "H2O:"} {} ";
      interval = 30;
      on-click = "sip";
      tooltip = false;
    };

    # filled heart while a dose is unacknowledged; clicking it is the same ack
    # as the notification button or `meds-taken` in a shell.
    "custom/meds" = {
      exec = "${scripts.medsHeart}";
      return-type = "json";
      format = " ${field "MEDS:"} {}";
      interval = 10;
      on-click = "meds-taken";
      tooltip = false;
    };

    "custom/eorzea" = {
      exec = "${scripts.eorzea}";
      return-type = "json";
      format = "${field "ET:"} {}";
      interval = 20;
      tooltip = false;
    };

    # now playing over mpris (mpv's mpris script, spotify-player, ncspot all
    # surface here). the readout itself is the play/pause button: waybar's mpris
    # module toggles on click by default, so no on-click is set. the status icon
    # shows the action a click takes (pause glyph while playing). {dynamic}
    # degrades gracefully when a player has no artist tag (mpv on a bare file).
    mpris = {
      format = "${field "NP:"} ${value c.mauve "{status_icon} {dynamic}"}";
      format-paused = "${field "NP:"} ${value c.subtext0 "{status_icon} {dynamic}"}";
      format-stopped = "";
      dynamic-order = [
        "artist"
        "title"
      ];
      dynamic-len = 40;
      status-icons = {
        playing = "󰏤";
        paused = "󰐊";
        stopped = "";
      };
      tooltip-format = "{player}: {artist} - {title}";
    };

    # transport buttons flank the readout; exec-if hides them (exec exits 1 ->
    # empty output) whenever no mpris player is up, so no orphan arrows.
    "custom/media-prev" = {
      format = "{}";
      exec = "printf '󰒮'";
      exec-if = "${pkgs.playerctl}/bin/playerctl status";
      interval = 5;
      on-click = "${pkgs.playerctl}/bin/playerctl previous";
      tooltip = false;
    };
    "custom/media-next" = {
      format = "{}";
      exec = "printf '󰒭'";
      exec-if = "${pkgs.playerctl}/bin/playerctl status";
      interval = 5;
      on-click = "${pkgs.playerctl}/bin/playerctl next";
      tooltip = false;
    };

    # zenpower Tdie by stable PCI path, NOT thermal-zone/hwmon index (hwmonN
    # shuffles across boots, and the Tccd* channels on this die read a bogus
    # ~150 degrees, so the module must pin temp1 = Tdie specifically).
    temperature = {
      hwmon-path-abs = "/sys/devices/pci0000:00/0000:00:18.3/hwmon";
      input-filename = "temp1_input";
      critical-threshold = 90;
      format = "${field "TMP:"} ${value c.peach "{temperatureC}°"}";
      format-critical = "${field "TMP:"} ${value c.red "{temperatureC}°"}";
      interval = 5;
    };

    disk = {
      format = "${field "DSK:"} ${value c.blue "{percentage_used}%"}";
      path = "/";
      interval = 120;
    };

    # click to hold the session awake (HELD = idle/lock inhibited, e.g. long
    # builds or a stream with no input); FREE = normal idle behavior.
    idle_inhibitor = {
      format = "${field "IDLE:"} {icon}";
      format-icons = {
        activated = value c.yellow "HELD";
        deactivated = value c.subtext0 "FREE";
      };
    };

    # red dots when something captures the screen or mic (the obs era wants a
    # tally light). silent and zero-width when nothing captures.
    privacy = {
      icon-spacing = 6;
      icon-size = 12;
      modules = [
        { type = "screenshare"; }
        { type = "audio-in"; }
      ];
    };

    tray.spacing = 8;
  }
  // lib.optionalAttrs cfg.battery.enable {
    # BAT readout, laptop hosts only. mirrors sketchybar/plugins/battery.sh so the two
    # bars agree: value color encodes charge (green>=60 / yellow>=40 / peach>=20 / red<20)
    # and charging shows a '+' suffix in green instead of a bolt glyph, all-caps console
    # register. waybar picks the LOWEST state threshold that capacity still falls under, so
    # these bands read 40-59 yellow, 20-39 peach, <20 red; >=60 falls through to the default.
    battery = {
      interval = 30;
      states = {
        yellow = 59;
        peach = 39;
        red = 19;
      };
      format = "${field "BAT:"} ${value c.green "{capacity}%"}";
      format-yellow = "${field "BAT:"} ${value c.yellow "{capacity}%"}";
      format-peach = "${field "BAT:"} ${value c.peach "{capacity}%"}";
      format-red = "${field "BAT:"} ${value c.red "{capacity}%"}";
      # charging takes precedence over the state formats: green with the '+' suffix.
      format-charging = "${field "BAT:"} ${value c.green "+{capacity}%"}";
      format-plugged = "${field "BAT:"} ${value c.green "+{capacity}%"}";
      format-full = "${field "BAT:"} ${value c.green "+{capacity}%"}";
      tooltip-format = "{timeTo}";
    };
  };

  css = ''
    * {
      font-family: "JetBrainsMono Nerd Font", "Symbols Nerd Font";
      font-size: 12px;
      font-weight: 700;
      min-height: 0;
    }

    /* flat lain hairline strip: near-black crust at ~0.94 like sketchybar's BAR_COLOR
       (0xf0 crust), pinned to the top edge, no float, no rounding, no per-module pills.
       a 1px surface line gives it a CRT scanline edge over a dark wallpaper. */
    window#waybar {
      background: alpha(${c.crust}, 0.94);
      color: ${c.text};
      border-bottom: 1px solid ${c.surface1};
    }

    /* every readout is transparent and flat: the console look comes from the two-tone
       FIELD:value markup, not from a pill. padding is the only spacing (spacing=0). */
    #workspaces, #window, #clock, #cpu, #memory, #network,
    #pulseaudio, #custom-eorzea, #custom-sep, #tray, #custom-water, #custom-meds,
    #mpris, #custom-media-prev, #custom-media-next,
    #temperature, #disk, #idle_inhibitor, #privacy {
      background: transparent;
      border-radius: 0;
      padding: 0 8px;
      margin: 0;
    }

    /* transport arrows: dim glyphs that light up on hover, console-style */
    #custom-media-prev, #custom-media-next {
      color: ${c.subtext0};
      padding: 0 4px;
    }
    #custom-media-prev:hover, #custom-media-next:hover {
      color: ${c.mauve};
    }

    /* the three json cells color by the class their script reports: day/night for
       eorzea, pending/taken for the heart, met/thirsty for the glass count. */
    #custom-eorzea.day { color: ${c.yellow}; }
    #custom-eorzea.night { color: ${c.mauve}; }
    #custom-meds.pending { color: ${c.mauve}; }
    #custom-meds.taken { color: ${c.subtext0}; }
    #custom-water.met { color: ${c.green}; }
    #custom-water.thirsty { color: ${c.subtext0}; }

    /* the capture tally light stays the reserved alarm red */
    #privacy {
      color: ${c.red};
    }

    /* workspace tape: bare numerals, brightness encodes state (dimmed vs lit accent),
       no animated pill fill, just a lit-vs-dim glyph like a terminal readout. */
    #workspaces button {
      color: ${c.subtext0};
      background: transparent;
      border-radius: 0;
      padding: 0 5px;
      margin: 0;
    }
    #workspaces button.active,
    #workspaces button.focused {
      color: ${c.mauve};
    }
    #workspaces button.urgent {
      color: ${c.red};
    }

    /* dim bracket divider, matching sketchybar sep.app drawn in a surface tone. */
    #custom-sep {
      color: ${c.surface2};
      padding: 0 4px;
    }

    #tray {
      padding: 0 6px;
    }
    ${lib.optionalString cfg.battery.enable ''
      /* BAT cell: same flat transparent console slot as the rest, laptop bars only. */
      #battery {
        background: transparent;
        border-radius: 0;
        padding: 0 8px;
        margin: 0;
      }
    ''}
  '';
}
