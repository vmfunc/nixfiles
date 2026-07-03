{ theme, ... }:
{
  # catppuccin is OFF for the wired variants. eza's native theme.yml lets us paint straight from
  # theme.palette (no hardcoded hex), so the listing follows the active variant instead of eza's
  # cold blue/green defaults. mauve = accent, text = fg, green = success/exec, red = danger,
  # subtext0/overlay1 = dim metadata.
  programs.eza = {
    enable = true;
    colors = "auto";
    theme = {
      filekinds = {
        normal = {
          foreground = theme.palette.text;
        };
        directory = {
          foreground = theme.palette.mauve;
        };
        symlink = {
          foreground = theme.palette.blue;
        };
        executable = {
          foreground = theme.palette.green;
        };
        special = {
          foreground = theme.palette.peach;
        };
      };
      perms = {
        user_read = {
          foreground = theme.palette.text;
        };
        user_write = {
          foreground = theme.palette.yellow;
        };
        user_execute_file = {
          foreground = theme.palette.green;
        };
        group_read = {
          foreground = theme.palette.subtext0;
        };
        group_write = {
          foreground = theme.palette.yellow;
        };
        other_read = {
          foreground = theme.palette.subtext0;
        };
        other_write = {
          foreground = theme.palette.yellow;
        };
        special_user_file = {
          foreground = theme.palette.peach;
        };
        special_other = {
          foreground = theme.palette.overlay1;
        };
        attribute = {
          foreground = theme.palette.subtext0;
        };
      };
      size = {
        major = {
          foreground = theme.palette.text;
        };
        minor = {
          foreground = theme.palette.subtext0;
        };
        number_byte = {
          foreground = theme.palette.text;
        };
        number_kilo = {
          foreground = theme.palette.text;
        };
        number_mega = {
          foreground = theme.palette.mauve;
        };
        number_giga = {
          foreground = theme.palette.peach;
        };
        number_huge = {
          foreground = theme.palette.red;
        };
        unit_byte = {
          foreground = theme.palette.subtext0;
        };
        unit_kilo = {
          foreground = theme.palette.subtext0;
        };
        unit_mega = {
          foreground = theme.palette.mauve;
        };
        unit_giga = {
          foreground = theme.palette.peach;
        };
        unit_huge = {
          foreground = theme.palette.red;
        };
      };
      users = {
        user_you = {
          foreground = theme.palette.mauve;
        };
        user_other = {
          foreground = theme.palette.subtext0;
        };
        group_yours = {
          foreground = theme.palette.text;
        };
        group_other = {
          foreground = theme.palette.subtext0;
        };
      };
      git = {
        new = {
          foreground = theme.palette.green;
        };
        modified = {
          foreground = theme.palette.yellow;
        };
        deleted = {
          foreground = theme.palette.red;
        };
        renamed = {
          foreground = theme.palette.blue;
        };
        typechange = {
          foreground = theme.palette.peach;
        };
        ignored = {
          foreground = theme.palette.overlay1;
        };
        conflicted = {
          foreground = theme.palette.red;
        };
      };
      git_repo = {
        branch_main = {
          foreground = theme.palette.text;
        };
        branch_other = {
          foreground = theme.palette.mauve;
        };
        git_clean = {
          foreground = theme.palette.green;
        };
        git_dirty = {
          foreground = theme.palette.red;
        };
      };
      punctuation = {
        foreground = theme.palette.overlay1;
      };
      date = {
        foreground = theme.palette.subtext0;
      };
      inode = {
        foreground = theme.palette.subtext0;
      };
      header = {
        foreground = theme.palette.mauve;
      };
    };
  };
}
