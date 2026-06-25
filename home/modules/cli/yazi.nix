{ pkgs, theme, ... }:
{
  programs.yazi = {
    enable = true;
    enableNushellIntegration = true;

    plugins = {
      inherit (pkgs.yaziPlugins) git full-border starship;
    };

    # catppuccin is OFF for the wired variants, so yazi lost its flavor. paint the core UI from
    # theme.palette (mauve = gold accent for the cursor/hovered/active tab, surface1 = selection
    # bg, red = cut/danger). no hardcoded hex, every variant recolors from the spine.
    theme = {
      mgr = {
        cwd = {
          fg = theme.palette.mauve;
        };
        hovered = {
          fg = theme.palette.base;
          bg = theme.palette.mauve;
        };
        preview_hovered = {
          underline = true;
        };
        find_keyword = {
          fg = theme.palette.yellow;
          italic = true;
        };
        find_position = {
          fg = theme.palette.peach;
          bg = "reset";
          italic = true;
        };
        marker_selected = {
          fg = theme.palette.green;
          bg = theme.palette.green;
        };
        marker_copied = {
          fg = theme.palette.yellow;
          bg = theme.palette.yellow;
        };
        marker_cut = {
          fg = theme.palette.red;
          bg = theme.palette.red;
        };
        tab_active = {
          fg = theme.palette.base;
          bg = theme.palette.mauve;
        };
        tab_inactive = {
          fg = theme.palette.text;
          bg = theme.palette.surface1;
        };
        border_style = {
          fg = theme.palette.overlay1;
        };
      };
      status = {
        separator_open = "";
        separator_close = "";
        mode_normal = {
          fg = theme.palette.base;
          bg = theme.palette.mauve;
          bold = true;
        };
        mode_select = {
          fg = theme.palette.base;
          bg = theme.palette.green;
          bold = true;
        };
        mode_unset = {
          fg = theme.palette.base;
          bg = theme.palette.peach;
          bold = true;
        };
        progress_label = {
          fg = theme.palette.text;
          bold = true;
        };
        progress_normal = {
          fg = theme.palette.mauve;
          bg = theme.palette.surface1;
        };
        progress_error = {
          fg = theme.palette.red;
          bg = theme.palette.surface1;
        };
      };
      input = {
        border = {
          fg = theme.palette.mauve;
        };
        selected = {
          bg = theme.palette.surface1;
        };
      };
      pick = {
        border = {
          fg = theme.palette.mauve;
        };
        active = {
          fg = theme.palette.mauve;
          bold = true;
        };
      };
      confirm = {
        border = {
          fg = theme.palette.mauve;
        };
        title = {
          fg = theme.palette.mauve;
        };
      };
      completion = {
        border = {
          fg = theme.palette.mauve;
        };
      };
    };

    initLua = ''
      require("git"):setup()
      require("full-border"):setup()
      require("starship"):setup()
    '';
  };
}
