# the islands look: the 2026 floating-pill idiom, cross-checked against the
# hyprland hall-of-fame rices and waybar's own group/drawer docs.
#
# what makes it read as modern rather than as a strip with rounded corners:
#   1. the BAR is invisible. background transparent, margins on all sides, so the
#      pills float over the wallpaper instead of a band cutting the screen.
#   2. related readouts live in ONE pill, not one pill each. a bar of fifteen
#      identical capsules is just the strip again with more borders.
#   3. the noisy stacks (transport, hardware) collapse behind a single glyph and
#      open on hover, which is what waybar's group drawer is for.
#   4. glyphs carry the meaning, numbers carry the value. no all-caps field
#      labels; that register belongs to the console look.
#   5. state is color on the glyph, never a second element.
#
# a plain function, not a module: waybar/default.nix picks one look and hands it
# the palette, the option set and the shared data scripts.
{
  c,
  lib,
  pkgs,
  cfg,
  scripts,
  tablet ? false,
  couch ? false,
  oskSignal ? 0,
}:
let
  # a value in the accent, its glyph dimmed a step. the whole two-tone idea of the
  # console register survives here, it just lands on glyph/number instead of
  # LABEL/value.
  glyph = g: "<span color='${c.subtext0}'>${g}</span>";
in
{
  settings = {
    layer = "top";
    position = "top";
    height = 34;
    # the gap BETWEEN islands. per-pill padding is css; this is the air.
    spacing = 6;
    margin-top = 8;
    margin-left = 12;
    margin-right = 12;

    modules-left = [
      "niri/workspaces"
      "niri/window"
    ];
    modules-center = [ "clock" ];
    modules-right = [
      "custom/media-prev"
      "mpris"
      "custom/media-next"
      "group/hardware"
    ]
    ++ lib.optional cfg.water.enable "custom/water"
    ++ lib.optional cfg.meds.enable "custom/meds"
    # tablet touch targets: reachable by finger when folded (no keyboard for the
    # niri binds). only present where the tablet layer is on (minnow).
    ++ lib.optional tablet "custom/osk"
    ++ lib.optional couch "custom/couch"
    ++ [
      "custom/eorzea"
      "network"
      "pulseaudio"
    ]
    ++ lib.optional cfg.battery.enable "battery"
    ++ [
      "idle_inhibitor"
      "privacy"
      "tray"
    ];

    # cpu leads because it is the one anyone actually watches; ram, thermals and
    # disk slide out under it.
    "group/hardware" = {
      orientation = "inherit";
      drawer = {
        transition-duration = 300;
        children-class = "hardware-child";
        transition-left-to-right = false;
      };
      modules = [
        "cpu"
        "memory"
        "temperature"
        "disk"
      ];
    };

    # dots, not numerals: the count is ambient, the focused one is the only one
    # that has to be legible.
    "niri/workspaces".format = "{index}";

    "niri/window" = {
      max-length = 40;
      format = "{title}";
      # an empty pill on an empty workspace looks broken, so it collapses.
      format-empty = "";
    };

    clock = {
      format = "{:%H:%M}";
      format-alt = "{:%a %d %b  %H:%M:%S}";
      tooltip-format = "<tt><small>{calendar}</small></tt>";
    };

    cpu = {
      format = "${glyph "󰻠"} {usage}%";
      interval = 3;
    };

    memory = {
      format = "${glyph "󰍛"} {percentage}%";
      interval = 5;
    };

    # zenpower Tdie by stable PCI path, NOT thermal-zone/hwmon index (hwmonN
    # shuffles across boots, and the Tccd* channels on this die read a bogus
    # ~150 degrees, so the module must pin temp1 = Tdie specifically).
    temperature = {
      hwmon-path-abs = "/sys/devices/pci0000:00/0000:00:18.3/hwmon";
      input-filename = "temp1_input";
      critical-threshold = 90;
      format = "${glyph "󰔏"} {temperatureC}°";
      interval = 5;
    };

    disk = {
      format = "${glyph "󰋊"} {percentage_used}%";
      path = "/";
      interval = 120;
    };

    network = {
      format-wifi = "${glyph "󰤨"} {bandwidthDownBytes}";
      format-ethernet = "${glyph "󰈀"} {bandwidthDownBytes}";
      format-disconnected = "${glyph "󰤭"}";
      interval = 3;
      tooltip-format = "{ifname}: {ipaddr}";
    };

    pulseaudio = {
      format = "${glyph "{icon}"} {volume}%";
      format-muted = "${glyph "󰝟"}";
      format-icons.default = [
        "󰕿"
        "󰖀"
        "󰕾"
      ];
      on-click = "${pkgs.pavucontrol}/bin/pavucontrol";
      on-scroll-up = "${pkgs.wireplumber}/bin/wpctl set-volume @DEFAULT_AUDIO_SINK@ 2%+";
      on-scroll-down = "${pkgs.wireplumber}/bin/wpctl set-volume @DEFAULT_AUDIO_SINK@ 2%-";
    };

    "custom/water" = {
      exec = "${scripts.waterCell}";
      return-type = "json";
      format = "${glyph "󰖌"} {}";
      interval = 30;
      on-click = "sip";
      tooltip = false;
    };

    "custom/meds" = {
      exec = "${scripts.medsHeart}";
      return-type = "json";
      format = "{}";
      interval = 10;
      on-click = "meds-taken";
      tooltip = false;
    };

    # tablet touch buttons (rice.tablet / rice.couch). waybar's user-service PATH
    # carries the home.packages, so the bare command resolves. keyboard + grid
    # glyphs are md-icons checked present in the bar's nerd font, not assumed.
    #
    # osk is a real TOGGLE, not a fire-and-forget button: tablet.nix's reporter
    # answers with the keyboard's shown/hidden state, the glyph flips to
    # keyboard-off while it is up, and css lights the pill. `osk` raises
    # RTMIN+oskSignal on every tap so the cell turns in the same frame; the
    # interval is only a safety net for a keyboard killed from outside.
    "custom/osk" = {
      exec = "${scripts.oskState}";
      return-type = "json";
      format = "{}";
      signal = oskSignal;
      interval = 10;
      on-click = "osk";
      tooltip = false;
    };

    "custom/couch" = {
      format = glyph "󰕰";
      on-click = "couch";
      tooltip = false;
    };

    # sun by day, moon by night, off the alt the shared script reports. the glyphs
    # were checked against the actual JetBrainsMono Nerd Font, not assumed.
    "custom/eorzea" = {
      exec = "${scripts.eorzea}";
      return-type = "json";
      # {text}, NOT {}: waybar 0.15 refuses to mix a named field ({icon}) with
      # positional {} in one format string, and the whole cell renders empty.
      format = "${glyph "{icon}"} {text}";
      format-icons = {
        day = "󰖙";
        night = "󰖔";
      };
      interval = 20;
      tooltip = false;
    };

    mpris = {
      format = "${glyph "{status_icon}"} {dynamic}";
      format-paused = "${glyph "{status_icon}"} {dynamic}";
      format-stopped = "";
      dynamic-order = [
        "artist"
        "title"
      ];
      dynamic-len = 28;
      status-icons = {
        playing = "󰏤";
        paused = "󰐊";
        stopped = "󰓛";
      };
      tooltip-format = "{player}: {artist} - {title}";
    };

    # exec-if hides them (exec exits 1 -> empty output) whenever no player is up.
    # this is also why the transport is NOT a drawer group: an empty group still
    # draws its own box, which put a blank pill on the bar with nothing playing.
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

    idle_inhibitor = {
      format = "{icon}";
      format-icons = {
        activated = "󰅶";
        deactivated = "󰛊";
      };
      tooltip-format-activated = "staying awake";
      tooltip-format-deactivated = "idle allowed";
    };

    privacy = {
      icon-spacing = 6;
      icon-size = 13;
      modules = [
        { type = "screenshare"; }
        { type = "audio-in"; }
      ];
    };

    tray.spacing = 10;
  }
  // lib.optionalAttrs cfg.battery.enable {
    # one glyph that fills as it charges, colored by state in css. waybar picks
    # the LOWEST state threshold capacity still falls under, so these read 40-59
    # warn, 20-39 low, <20 critical; >=60 falls through to the default.
    battery = {
      interval = 30;
      states = {
        warn = 59;
        low = 39;
        critical = 19;
      };
      format = "{icon} {capacity}%";
      format-charging = "󰂄 {capacity}%";
      format-plugged = "󰚥 {capacity}%";
      format-icons = [
        "󰁺"
        "󰁻"
        "󰁽"
        "󰁿"
        "󰂁"
        "󰁹"
      ];
      tooltip-format = "{timeTo}";
    };
  };

  css = ''
    * {
      font-family: "JetBrainsMono Nerd Font", "Symbols Nerd Font";
      font-size: 12px;
      font-weight: 600;
      min-height: 0;
      /* gtk draws a focus ring on buttons otherwise, which reads as a stray
         rectangle inside a rounded pill. */
      border: none;
      box-shadow: none;
    }

    /* THE BAR ITSELF IS INVISIBLE. everything visible below is a pill floating on
       the wallpaper; the margins in settings are what let it float. */
    window#waybar {
      background: transparent;
      color: ${c.text};
    }

    /* the pill. one rule for every island so they cannot drift: a translucent
       base disc, a hairline of surface, fully rounded ends. 999px rather than a
       measured radius so the caps stay perfect at any height. */
    #workspaces, #window, #clock, #network, #pulseaudio, #battery,
    #custom-eorzea, #custom-water, #custom-meds, #idle_inhibitor,
    #privacy, #tray, .modules-right > widget > box,
    #cpu, #memory, #temperature, #disk, #mpris,
    #custom-osk, #custom-couch,
    #custom-media-prev, #custom-media-next {
      background: alpha(${c.base}, 0.72);
      border: 1px solid alpha(${c.surface1}, 0.9);
      border-radius: 999px;
      padding: 1px 12px;
      margin: 0;
      transition: background 200ms ease, color 200ms ease;
    }

    /* a group is one pill, not a pill per child: the children go flat and the box
       around them carries the disc. */
    #cpu, #memory, #temperature, #disk {
      background: transparent;
      border: none;
      padding: 1px 6px;
    }

    /* transport arrows are round buttons, not capsules: nothing but a glyph. */
    #custom-media-prev, #custom-media-next {
      color: ${c.subtext0};
      padding: 1px 9px;
    }
    #custom-media-prev:hover, #custom-media-next:hover {
      color: ${c.mauve};
      background: alpha(${c.surface0}, 0.85);
    }

    /* hover lifts the disc a step rather than moving anything, so nothing on the
       bar ever reflows under the pointer. */
    #clock:hover, #network:hover, #pulseaudio:hover, #battery:hover,
    #custom-eorzea:hover, #custom-water:hover, #custom-meds:hover,
    #idle_inhibitor:hover, #custom-osk:hover, #custom-couch:hover {
      background: alpha(${c.surface0}, 0.85);
    }

    /* the clock is the one thing read from across the room: accent ring, wider. */
    #clock {
      color: ${c.text};
      border-color: alpha(${c.mauve}, 0.55);
      padding: 1px 16px;
      font-weight: 700;
    }

    /* workspaces: dots that only the focused one fills. the pill IS the group, so
       the buttons inside it are bare. */
    #workspaces {
      padding: 1px 6px;
    }
    #workspaces button {
      background: transparent;
      border: none;
      border-radius: 999px;
      color: ${c.overlay1};
      padding: 0 7px;
      margin: 0;
      transition: color 200ms ease;
    }
    #workspaces button.active,
    #workspaces button.focused {
      color: ${c.mauve};
      background: alpha(${c.mauve}, 0.14);
    }
    #workspaces button:hover {
      color: ${c.text};
    }
    #workspaces button.urgent {
      color: ${c.red};
    }

    /* the focused-window title is context, not a readout: it sits back a tone and
       has no pill of its own until there is something in it. */
    #window {
      color: ${c.subtext0};
      background: alpha(${c.base}, 0.55);
      font-weight: 500;
    }
    window#waybar.empty #window {
      background: transparent;
      border-color: transparent;
    }

    /* drawer children slide out from under their leader. the transition-duration
       is set per group in settings; this is only what they look like. */
    .hardware-child {
      color: ${c.subtext0};
    }
    .hardware-child:hover {
      color: ${c.mauve};
    }

    #cpu { color: ${c.mauve}; }
    #memory { color: ${c.green}; }
    #temperature { color: ${c.peach}; }
    #temperature.critical { color: ${c.red}; }
    #disk { color: ${c.blue}; }
    #network { color: ${c.mauve}; }
    #network.disconnected { color: ${c.subtext0}; }
    #pulseaudio { color: ${c.mauve}; }
    #pulseaudio.muted { color: ${c.subtext0}; }
    #mpris { color: ${c.mauve}; }
    #mpris.paused { color: ${c.subtext0}; }

    /* state as color on the glyph, never a second element. */
    #custom-eorzea.day { color: ${c.yellow}; }
    #custom-eorzea.night { color: ${c.mauve}; }
    #custom-water.met { color: ${c.green}; }
    #custom-water.thirsty { color: ${c.subtext0}; }
    #custom-meds.taken { color: ${c.subtext0}; }
    /* the one thing on this bar allowed to shout. */
    #custom-meds.pending {
      color: ${c.red};
      border-color: alpha(${c.red}, 0.6);
      background: alpha(${c.red}, 0.14);
    }

    #idle_inhibitor { color: ${c.subtext0}; }
    #idle_inhibitor.activated { color: ${c.yellow}; }

    /* the tablet pair. wider padding than the readouts: these are the only cells
       on the bar meant to be hit with a FINGER, and a 12px capsule is a cursor
       target. everything else here is read, not pressed.

       and the glyphs get their own size. the md keyboard is the densest icon on
       this bar (a full key grid inside one em), and at the bar's 12px its keys
       collapse into a filled block that reads as tofu, not as a keyboard. 15px
       is where the keys resolve. the vertical padding comes back off so the
       taller line does not push these two pills out of line with the rest. */
    #custom-osk, #custom-couch {
      color: ${c.subtext0};
      font-size: 15px;
      padding: 0 16px;
    }
    /* the toggle's ON state, the one pressed-in affordance on the bar: accent
       glyph over an accent wash, same shape the meds cell uses to shout, a tone
       quieter because this one is merely true, not urgent. */
    #custom-osk.on {
      color: ${c.mauve};
      border-color: alpha(${c.mauve}, 0.55);
      background: alpha(${c.mauve}, 0.16);
    }
    #custom-osk.on:hover {
      background: alpha(${c.mauve}, 0.24);
    }

    /* the capture tally light stays the reserved alarm red */
    #privacy { color: ${c.red}; }

    #tray { padding: 1px 10px; }
    #tray menu { background: ${c.base}; color: ${c.text}; }
    ${lib.optionalString cfg.battery.enable ''
      #battery { color: ${c.green}; }
      #battery.warn { color: ${c.yellow}; }
      #battery.low { color: ${c.peach}; }
      #battery.critical { color: ${c.red}; }
      #battery.charging { color: ${c.green}; }
    ''}
  '';
}
