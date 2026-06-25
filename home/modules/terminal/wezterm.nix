{
  inputs,
  theme,
  username,
  lib,
  ...
}:
let
  wallpaper = "${inputs.wallpapers}/${theme.wallpaperFile}";
  cap =
    s: (lib.toUpper (builtins.substring 0 1 s)) + (builtins.substring 1 (builtins.stringLength s) s);
  colorScheme = "Catppuccin ${cap theme.flavor}";

  # wired turns the catppuccin module off, so the built-in "Catppuccin *" scheme no longer
  # exists: drive every color inline from the palette + the 16 ANSI instead. macchiato keeps
  # the scheme and only overrides cursor/selection on top of it.
  wired = theme.variant == "wired";
  luaList = xs: "{ " + lib.concatMapStringsSep ", " (c: "'${c}'") xs + " }";
  schemeLua = lib.optionalString (!wired) "config.color_scheme = '${colorScheme}'";
  colorsLua =
    if wired then
      ''
        config.colors = {
          foreground = '${theme.palette.text}',
          background = '${theme.palette.base}',
          cursor_bg = '${theme.palette.mauve}',
          cursor_border = '${theme.palette.mauve}',
          cursor_fg = '${theme.palette.crust}',
          selection_bg = '${theme.palette.surface1}',
          selection_fg = '${theme.palette.text}',
          ansi = ${luaList (lib.sublist 0 8 theme.ansi16)},
          brights = ${luaList (lib.sublist 8 8 theme.ansi16)},
        }''
    else
      ''
        config.colors = {
          cursor_bg = '${theme.palette.mauve}',
          cursor_border = '${theme.palette.mauve}',
          cursor_fg = '${theme.palette.crust}',
          selection_bg = '${theme.palette.surface1}',
          selection_fg = '${theme.palette.text}',
        }'';
in
{
  programs.wezterm = {
    enable = true;
    extraConfig = ''
      local wezterm = require 'wezterm'
      local config = wezterm.config_builder()

      ${schemeLua}
      config.font = wezterm.font_with_fallback {
        'JetBrainsMono Nerd Font',
        'Maple Mono NF',
        'Symbols Nerd Font',
      }
      config.font_size = 14.0
      config.line_height = 1.1

      config.window_background_opacity = 0.92
      config.macos_window_background_blur = 30
      config.window_decorations = 'RESIZE'
      config.window_padding = { left = 16, right = 16, top = 14, bottom = 12 }
      config.hide_tab_bar_if_only_one_tab = true
      config.use_fancy_tab_bar = false
      config.tab_bar_at_bottom = true
      config.adjust_window_size_when_changing_font_size = false
      config.default_cursor_style = 'BlinkingBar'
      config.cursor_blink_rate = 500
      config.front_end = 'WebGpu'
      config.max_fps = 120
      config.scrollback_lines = 10000
      config.audible_bell = 'Disabled'

      -- faint wallpaper behind a Catppuccin base tint (readable, ricey)
      config.background = {
        {
          source = { File = '${wallpaper}' },
          horizontal_align = 'Center',
          vertical_align = 'Middle',
          hsb = { brightness = 0.04, saturation = 0.9, hue = 1.0 },
        },
        {
          source = { Color = '${theme.palette.base}' },
          width = '100%',
          height = '100%',
          opacity = 0.84,
        },
      }

      -- launch Nushell (where all the rice shell config lives) instead of zsh
      config.default_prog = { '/etc/profiles/per-user/${username}/bin/nu', '--login', '--interactive' }

      -- RE quick-select: CTRL-SHIFT-SPACE highlights every match with a 1-2 char
      -- label; type it to yank straight to the clipboard. No more mousing hex
      -- addresses / hashes / CVE ids / base64 out of disassembly.
      config.quick_select_patterns = {
        '0x[0-9a-fA-F]+',           -- hex addresses / offsets
        '[0-9a-fA-F]{7,40}',        -- git shas, md5/sha hashes
        'CVE-\\d{4}-\\d{4,7}',      -- CVE identifiers
        '[A-Za-z0-9+/]{16,}={0,2}', -- base64 blobs
      }

      -- tmux-style pane management under a CTRL-a leader (1s timeout). CTRL-a is
      -- free in zellij's default keymap (its prefixes are Ctrl p/n/t/o/g/h/b/s/q),
      -- so nesting wezterm-leader inside a zellij session never eats a zellij key.
      config.leader = { key = 'a', mods = 'CTRL', timeout_milliseconds = 1000 }
      local act = wezterm.action
      config.keys = {
        -- splits: | / - mirror the visual orientation of the cut
        { key = '|', mods = 'LEADER|SHIFT', action = act.SplitHorizontal { domain = 'CurrentPaneDomain' } },
        { key = '-', mods = 'LEADER',       action = act.SplitVertical { domain = 'CurrentPaneDomain' } },
        -- vim-style pane focus
        { key = 'h', mods = 'LEADER', action = act.ActivatePaneDirection 'Left' },
        { key = 'j', mods = 'LEADER', action = act.ActivatePaneDirection 'Down' },
        { key = 'k', mods = 'LEADER', action = act.ActivatePaneDirection 'Up' },
        { key = 'l', mods = 'LEADER', action = act.ActivatePaneDirection 'Right' },
        -- zoom / tab / close
        { key = 'z', mods = 'LEADER', action = act.TogglePaneZoomState },
        { key = 'c', mods = 'LEADER', action = act.SpawnTab 'CurrentPaneDomain' },
        { key = 'x', mods = 'LEADER', action = act.CloseCurrentPane { confirm = true } },
        -- LEADER, CTRL-a sends a literal CTRL-a (keeps readline/nu/zellij start-of-line)
        { key = 'a', mods = 'LEADER|CTRL', action = act.SendKey { key = 'a', mods = 'CTRL' } },
      }

      config.inactive_pane_hsb = { saturation = 0.9, brightness = 0.7 }
      config.window_frame = {
        font = wezterm.font { family = 'JetBrainsMono Nerd Font', weight = 'Bold' },
        font_size = 12.0,
      }

      -- colors: full inline palette on wired, cursor/selection overrides on macchiato
      ${colorsLua}

      return config
    '';
  };
}
