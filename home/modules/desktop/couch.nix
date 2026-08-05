# couch mode (rice.couch.*, default off; minnow): the "this laptop is now an
# appliance" surface for convertible/couch posture. `couch` throws a fullscreen
# big-icon touch launcher over the session (nwg-drawer on the layer-shell
# overlay, fed by the normal .desktop entries), sized for fingers, dismissed by
# launching or tapping outside. media strip and a jellyfin tile can graft on
# later once a media server exists to point at.
#
# the drawer is a GTK3 app, so its whole look is one stylesheet and nothing else:
# nwg-drawer ships a stock blue-grey sheet that reads nothing like this rice, so
# we write our own from rice.theme.colors and a theme.nix variant swap recolors
# the launcher with everything else. it exposes exactly four #ids
# (category-button, pinned-box, files-box, math-label); every other surface has
# to be reached through its GTK type selector, which is why the sheet below is
# written against `window`/`entry`/`button`/`flowboxchild` rather than names.
#
# cross-file deps: theme.nix owns rice.theme.colors; niri.nix binds Mod+Shift+O
# and waybar/islands.nix renders custom/couch; the icon-theme the tiles draw from
# is gtk.iconTheme in niri.nix (Papirus-Dark), same set fuzzel and mako use.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.rice.couch;
  c = config.rice.theme.colors;

  # rice.look is the one corner switch the whole set reads (niri, mako, fuzzel).
  # square in the hairline console register, generously rounded in soft: at this
  # icon size a tile needs real radius or it reads as a spreadsheet cell.
  soft = config.rice.look == "soft";
  radius = px: toString (if soft then px else 0) + "px";

  # nwg-drawer resolves -s against its own config dir, so the sheet has to LIVE
  # at ~/.config/nwg-drawer/. it also copies its stock sheet in on first run when
  # the file is absent, which the home-manager symlink pre-empts.
  styleName = "drawer.css";

  style = ''
    /* the field. sheer rather than opaque so the wallpaper still reads through:
       this is a surface thrown OVER the session, and the session should still be
       visible enough to remember it is there. f0-equivalent, matching fuzzel. */
    window {
      background-color: alpha(${c.base}, 0.94);
      color: ${c.text};
      font-family: "JetBrainsMono Nerd Font", "Symbols Nerd Font";
      font-size: 13px;
    }

    /* the search field: a bare slab, not a widget. one hairline, accent only when
       it has focus, and sized for a thumb rather than a caret. */
    entry {
      background-color: alpha(${c.surface0}, 0.9);
      color: ${c.text};
      border: 1px solid ${c.surface1};
      border-radius: ${radius 14};
      padding: 12px 18px;
      margin: 18px 24px 10px 24px;
      font-size: 16px;
      caret-color: ${c.mauve};
      box-shadow: none;
      transition: border-color 200ms ease, background-color 200ms ease;
    }
    entry:focus {
      border-color: alpha(${c.mauve}, 0.7);
      background-color: alpha(${c.surface0}, 1.0);
    }
    entry selection {
      background-color: alpha(${c.mauve}, 0.35);
      color: ${c.text};
    }

    /* app tiles. the grid cell carries the hit target, the button inside it
       carries the paint, so the tap area stays finger-sized even where the icon
       is small. no border in the resting state: a page of outlined boxes is a
       form, and this is meant to read as a shelf. */
    flowboxchild {
      background: none;
      border-radius: ${radius 18};
      padding: 0;
    }
    flowboxchild:selected {
      background: none;
    }

    button, image {
      background: none;
      border: none;
      box-shadow: none;
      color: ${c.text};
    }

    flowboxchild button {
      border-radius: ${radius 18};
      padding: 14px 8px;
      transition: background-color 180ms ease, color 180ms ease;
    }

    /* hover and touch-press are the SAME state on a tablet (there is no pointer
       to hover with), so both land on one wash rather than two intensities. */
    flowboxchild button:hover,
    flowboxchild button:active,
    flowboxchild:selected button {
      background-color: alpha(${c.surface0}, 0.95);
      color: ${c.text};
    }

    /* keyboard/dpad focus gets the accent ring the wash alone cannot carry. gtk
       draws its own dotted focus outline otherwise, which looks like damage. */
    flowboxchild button:focus,
    flowboxchild:selected button {
      box-shadow: inset 0 0 0 1px alpha(${c.mauve}, 0.55);
      outline: none;
    }

    /* labels sit back a tone: the ICON is the target, the name is the caption. */
    flowboxchild button label {
      color: ${c.subtext0};
      font-size: 12px;
      margin-top: 6px;
    }
    flowboxchild button:hover label,
    flowboxchild:selected button label {
      color: ${c.text};
    }

    /* category filters read as chips along the top, the one row on this surface
       that is navigation rather than content. */
    #category-button {
      background-color: alpha(${c.surface0}, 0.75);
      color: ${c.subtext0};
      border: 1px solid alpha(${c.surface1}, 0.9);
      border-radius: 999px;
      padding: 6px 16px;
      margin: 4px 6px;
      font-size: 12px;
    }
    #category-button:hover {
      background-color: alpha(${c.surface1}, 0.95);
      color: ${c.text};
    }
    #category-button:checked,
    #category-button:active {
      background-color: alpha(${c.mauve}, 0.18);
      border-color: alpha(${c.mauve}, 0.55);
      color: ${c.mauve};
    }

    /* pinned apps are the top shelf, separated by a hairline instead of the stock
       dotted-gray rule (the one thing in the default sheet that reads as a 90s
       dialog). */
    #pinned-box {
      padding-bottom: 14px;
      margin-bottom: 6px;
      border-bottom: 1px solid alpha(${c.surface1}, 0.9);
    }

    /* file-search results: a card, since unlike the app grid it appears and
       disappears and needs an edge to say where it starts. */
    #files-box {
      background-color: alpha(${c.surface0}, 0.55);
      border: 1px solid alpha(${c.surface1}, 0.9);
      border-radius: ${radius 16};
      padding: 10px;
      margin: 6px 0;
    }

    /* the calculator answer is the one thing here that is a RESULT, so it is the
       one thing allowed the accent. */
    #math-label {
      color: ${c.mauve};
      font-weight: 700;
      font-size: 17px;
    }

    /* a scrollbar over an appliance surface should be a hint, not a control. */
    scrollbar {
      background: none;
      border: none;
    }
    scrollbar slider {
      background-color: alpha(${c.overlay0}, 0.7);
      border: none;
      border-radius: 999px;
      min-width: 6px;
      min-height: 40px;
    }
    scrollbar slider:hover {
      background-color: alpha(${c.overlay2}, 0.9);
    }

    separator {
      background-color: alpha(${c.surface1}, 0.9);
      min-height: 1px;
      min-width: 1px;
    }

    tooltip {
      background-color: ${c.mantle};
      color: ${c.text};
      border: 1px solid ${c.surface1};
      border-radius: ${radius 10};
    }
  '';

  couch = pkgs.writeShellScriptBin "couch" ''
    # -ovl paints the whole output so it reads as an appliance, not a popup.
    # -s names the sheet in ~/.config/nwg-drawer (written by this module); it is
    # nwg-drawer's own default name, passed anyway so the file is findable from
    # the command that uses it.
    exec ${pkgs.nwg-drawer}/bin/nwg-drawer \
      -c ${toString cfg.columns} -is ${toString cfg.iconSize} -spacing 24 -ovl \
      -s ${styleName}
  '';
in
{
  options.rice.couch = {
    enable = lib.mkEnableOption "couch mode (fullscreen touch launcher)";
    columns = lib.mkOption {
      type = lib.types.int;
      default = 4;
      description = "icon grid columns; 4 fits a 12-inch panel at 1.25 scale";
    };
    iconSize = lib.mkOption {
      type = lib.types.int;
      default = 128;
      description = "icon size in px; finger-sized, not cursor-sized";
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [
      pkgs.nwg-drawer
      couch
    ];

    xdg.configFile."nwg-drawer/${styleName}".text = style;
  };
}
