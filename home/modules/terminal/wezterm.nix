# wezterm, the lain pixel terminal. shared across all three hosts (base.nix), so
# every option here must be safe on darwin + wayland/niri. the 2026-07 pin is a
# nightly build, so nightly-only options (text_min_contrast_ratio, the *_font
# overlays, wayland blur, mux_enable_ssh_agent) are live.
#
# the protocol block is what makes terminal emacs (kkp.el) and the neovim VSCode
# chord layer receive C-S-p / C-. / C-/ distinctly, and term="wezterm" is the one
# line that unlocks undercurl (Smulx) for editor diagnostics. cross-file dep:
# home/modules/editor/emacs (kkp) and editor/neovim.nix both rely on this.
{
  theme,
  username,
  lib,
  pkgs,
  ...
}:
let
  p = theme.palette;

  # same vendored lain image the desktop uses (wallpaper.nix),
  # rendered faint behind the base tint below so the terminal stays readable.
  wallpaper = ../desktop/wallpaper.jpg;
  cap =
    s: (lib.toUpper (builtins.substring 0 1 s)) + (builtins.substring 1 (builtins.stringLength s) s);
  colorScheme = "Catppuccin ${cap theme.flavor}";

  # any non-macchiato variant turns the catppuccin module off, so the built-in "Catppuccin *"
  # scheme no longer exists: drive every color inline from the palette + the 16 ANSI instead.
  # macchiato keeps the scheme and only overrides cursor/selection on top of it.
  inlinePalette = theme.variant != "macchiato";
  luaList = xs: "{ " + lib.concatMapStringsSep ", " (c: "'${c}'") xs + " }";
  schemeLua = lib.optionalString (!inlinePalette) "config.color_scheme = '${colorScheme}'";
  colorsLua =
    if inlinePalette then
      ''
        config.colors = {
          foreground = '${p.text}',
          background = '${p.base}',
          cursor_bg = '${p.mauve}',
          cursor_border = '${p.mauve}',
          cursor_fg = '${p.crust}',
          selection_bg = '${p.surface1}',
          selection_fg = '${p.text}',
          ansi = ${luaList (lib.sublist 0 8 theme.ansi16)},
          brights = ${luaList (lib.sublist 8 8 theme.ansi16)},
        }''
    else
      ''
        config.colors = {
          cursor_bg = '${p.mauve}',
          cursor_border = '${p.mauve}',
          cursor_fg = '${p.crust}',
          selection_bg = '${p.surface1}',
          selection_fg = '${p.text}',
        }'';

  # palette-driven color keys layered onto config.colors for BOTH variants (the
  # macchiato branch sets a partial colors table, these extend it). the tab strip,
  # quick-select labels, copy-mode highlights, split line and bell all recolor when
  # the theme variant flips.
  extraColorsLua = ''
    config.colors.tab_bar = {
      background = '${p.crust}',
      active_tab = { bg_color = '${p.surface0}', fg_color = '${p.mauve}', intensity = 'Bold' },
      inactive_tab = { bg_color = '${p.mantle}', fg_color = '${p.overlay1}' },
      inactive_tab_hover = { bg_color = '${p.surface1}', fg_color = '${p.subtext1}' },
      new_tab = { bg_color = '${p.crust}', fg_color = '${p.overlay0}' },
      new_tab_hover = { bg_color = '${p.crust}', fg_color = '${p.mauve}' },
    }
    config.colors.split = '${p.surface2}'
    config.colors.visual_bell = '${p.yellow}'
    config.colors.quick_select_label_bg = { Color = '${p.mauve}' }
    config.colors.quick_select_label_fg = { Color = '${p.crust}' }
    config.colors.quick_select_match_bg = { Color = '${p.surface1}' }
    config.colors.quick_select_match_fg = { Color = '${p.text}' }
    config.colors.copy_mode_active_highlight_bg = { Color = '${p.mauve}' }
    config.colors.copy_mode_active_highlight_fg = { Color = '${p.crust}' }
    config.colors.copy_mode_inactive_highlight_bg = { Color = '${p.surface1}' }
    config.colors.copy_mode_inactive_highlight_fg = { Color = '${p.subtext0}' }
  '';
in
{
  # term="wezterm" propagates over ssh, so ship the terminfo everywhere it might be
  # read locally. remote hosts that lack it still need the SetEnv escape hatch, but
  # locally this guarantees Smulx (undercurl) and truecolor resolve on every box.
  home.file.".terminfo".source = "${pkgs.wezterm.terminfo}/share/terminfo";

  programs.wezterm = {
    enable = true;
    extraConfig = ''
      local wezterm = require 'wezterm'
      local config = wezterm.config_builder()
      local act = wezterm.action

      -- some options below are nightly-only wezterm features. this config is shared
      -- across hosts whose wezterm may be older (or a still-running older process
      -- that hot-reloaded the config), so set those through try_set: an unknown
      -- field degrades to a no-op instead of throwing "not a valid Config field"
      -- and erroring the whole config (config_builder aborts on the first one).
      local function try_set(key, value)
        pcall(function() config[key] = value end)
      end

      ${schemeLua}
      -- CozetteVector: the Lain pixel-terminal face (scalable build of the Cozette bitmap,
      -- crisp at any size). JetBrainsMono NF backstops glyph/Nerd-icon coverage.
      config.font = wezterm.font_with_fallback {
        'CozetteVector',
        'JetBrainsMono Nerd Font',
        'Symbols Nerd Font',
      }
      config.font_size = 14.0
      config.line_height = 1.1

      config.window_background_opacity = 0.92
      config.macos_window_background_blur = 30
      -- wayland twin of the macos blur: niri >= 26.04 speaks ext-background-effect-v1.
      -- a no-op on darwin and on compositors without the protocol. nightly-only
      -- (landed 2026-07-13), so guarded for older wezterm builds.
      try_set('wayland_window_background_blur', true)
      config.window_decorations = 'NONE'
      config.window_padding = { left = 16, right = 16, top = 14, bottom = 12 }
      -- center content so a non-cell-multiple window never leaves a hard gutter (nightly)
      try_set('window_content_alignment', { horizontal = 'Center', vertical = 'Center' })
      config.hide_tab_bar_if_only_one_tab = true
      config.use_fancy_tab_bar = false
      config.tab_bar_at_bottom = true
      config.show_new_tab_button_in_tab_bar = false
      config.tab_max_width = 24
      config.adjust_window_size_when_changing_font_size = false

      -- breathing bar cursor: eased blink, not a hard on/off. emacs/evil still drives
      -- its own per-state shape over DECSCUSR when focused; this is the fallback.
      config.default_cursor_style = 'BlinkingBar'
      config.cursor_blink_rate = 700
      config.cursor_blink_ease_in = 'EaseIn'
      config.cursor_blink_ease_out = 'EaseOut'
      config.animation_fps = 30

      config.front_end = 'WebGpu'
      -- 60 over 120: WebGpu redraws continuously, and 120fps roughly doubled idle
      -- gpu/fan for no visible gain at terminal cadence. 60 is plenty for scrollback.
      config.max_fps = 60
      config.scrollback_lines = 10000
      config.audible_bell = 'Disabled'
      -- a soft amber flare on the CURSOR for the bell instead of a full-screen flash
      config.visual_bell = {
        fade_in_function = 'EaseIn',
        fade_in_duration_ms = 75,
        fade_out_function = 'EaseOut',
        fade_out_duration_ms = 300,
        target = 'CursorColor',
      }

      --  TERMINAL PROTOCOLS
      -- term="wezterm" unlocks Smulx (curly/colored underlines for editor squiggles)
      -- and 24-bit color caps that xterm-256color lacks. kitty keyboard is what makes
      -- terminal emacs (kkp.el) + nvim's chord layer receive C-S-p / C-. / C-/ as
      -- distinct events; it stays inert until an app requests it, so nushell/yazi keep
      -- legacy encoding. csi-u stays off: the kitty protocol supersedes it.
      config.term = 'wezterm'
      config.enable_kitty_keyboard = true
      config.enable_csi_u_key_encoding = false
      config.enable_kitty_graphics = true      -- yazi/mpv inline images (already default)
      config.detect_password_input = true
      config.unicode_version = 14              -- honor emoji presentation selectors (default 9)
      config.use_ime = true                    -- niri zwp_text_input_v3 / JP input
      config.macos_forward_to_ime_modifier_mask = 'SHIFT|CTRL' -- JP IME on the macs, no-op elsewhere
      config.bypass_mouse_reporting_modifiers = 'SHIFT'
      config.mouse_wheel_scrolls_tabs = true
      -- mouse QoL (all long-stable options): hover a split to focus it, a
      -- focus-click doesn't also get sent to the app, and switching pane auto-unzooms.
      config.pane_focus_follows_mouse = true
      config.swallow_mouse_click_on_pane_focus = true
      config.unzoom_on_switch_pane = true
      -- nightly flipped this on: wezterm rewrites SSH_AUTH_SOCK in local panes to a
      -- self-managed symlink. azzie has a deliberate agent topology (gpg-agent ssh,
      -- tailnet keys), so keep the real socket, do not let wezterm indirect it.
      config.mux_enable_ssh_agent = false
      -- floor per-cell fg/bg contrast so the wallpaper + tint never eats dim text
      -- (comments, inactive panes). 4.5 = WCAG AA; only rewrites cells below it. nightly.
      try_set('text_min_contrast_ratio', 4.5)
      config.notification_handling = 'SuppressFromFocusedPane'

      --  OVERLAY CHROME in the pixel face + palette (catppuccin module is off on wired)
      -- the *_font overlays are nightly-only, so guarded; sizes/colors are stable.
      try_set('command_palette_font', wezterm.font 'CozetteVector')
      config.command_palette_font_size = 14.0
      config.command_palette_rows = 12
      config.command_palette_bg_color = '${p.surface0}'
      config.command_palette_fg_color = '${p.text}'
      try_set('char_select_font', wezterm.font 'CozetteVector')
      config.char_select_font_size = 14.0
      config.char_select_bg_color = '${p.surface0}'
      config.char_select_fg_color = '${p.text}'
      try_set('pane_select_font', wezterm.font 'CozetteVector')
      config.pane_select_font_size = 24
      config.pane_select_fg_color = '${p.mauve}'
      config.pane_select_bg_color = '${p.crust}'

      -- faint wallpaper behind a Catppuccin base tint (readable, ricey)
      config.background = {
        {
          source = { File = '${wallpaper}' },
          horizontal_align = 'Center',
          vertical_align = 'Middle',
          hsb = { brightness = 0.04, saturation = 0.9, hue = 1.0 },
        },
        {
          source = { Color = '${p.base}' },
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
      try_set('quick_select_remove_styling', true)  -- drop bg styling while labels show (nightly)

      --  HYPERLINKS: extend, never replace, the compiled-in defaults
      config.hyperlink_rules = wezterm.default_hyperlink_rules()
      table.insert(config.hyperlink_rules, {
        regex = [[\bCVE-\d{4}-\d{4,7}\b]],
        format = 'https://nvd.nist.gov/vuln/detail/$0',
      })
      -- ctrl-click a `path:line` from ripgrep/compiler output straight into the editor
      table.insert(config.hyperlink_rules, {
        regex = [[(\S+\.(?:rs|c|h|cpp|nix|lua|go|py|el|zig|sh|ts|js)):(\d+)]],
        format = 'file-line://$1:$2',
      })
      wezterm.on('open-uri', function(window, pane, uri)
        local path, line = uri:match('file%-line://(.+):(%d+)')
        if not path then return true end
        -- tuna edits in terminal emacs, the macs still in nvim
        local args = (wezterm.hostname() == 'tuna')
          and { 'emacsclient', '-t', '-a', "", '+' .. line, path }
          or { 'nvim', '+' .. line, path }
        window:perform_action(act.SpawnCommandInNewTab {
          args = args,
          cwd = pane:get_current_working_dir(),
        }, pane)
        return false
      end)

      --  RETRO TAB TITLES: process-aware nerd icon + palette accent on the active tab
      local tab_icons = {
        nu = wezterm.nerdfonts.oct_terminal,
        nvim = wezterm.nerdfonts.custom_neovim,
        emacs = wezterm.nerdfonts.custom_emacs,
        emacsclient = wezterm.nerdfonts.custom_emacs,
        yazi = wezterm.nerdfonts.md_folder_open,
        zellij = wezterm.nerdfonts.cod_split_horizontal,
        git = wezterm.nerdfonts.dev_git,
        lazygit = wezterm.nerdfonts.dev_git,
        cargo = wezterm.nerdfonts.dev_rust,
        node = wezterm.nerdfonts.md_nodejs,
        ssh = wezterm.nerdfonts.md_lan_connect,
      }
      wezterm.on('format-tab-title', function(tab, tabs, panes, cfg, hover, max_width)
        local pane = tab.active_pane
        local proc = (pane.foreground_process_name or ""):match('([^/\\]+)$')
        local title = (tab.tab_title and #tab.tab_title > 0) and tab.tab_title
          or proc or pane.title
        local icon = tab_icons[proc] or wezterm.nerdfonts.oct_chevron_right
        title = wezterm.truncate_right(title, max_width - 5)
        local fg = tab.is_active and '${p.mauve}'
          or (hover and '${p.subtext1}' or '${p.overlay1}')
        local bg = tab.is_active and '${p.surface0}' or '${p.mantle}'
        return {
          { Background = { Color = bg } },
          { Foreground = { Color = fg } },
          { Text = ' ' .. icon .. ' ' .. title .. ' ' },
        }
      end)

      --  STATUS BAR: a mauve leader dot on the left; workspace + clock on the right
      wezterm.on('update-status', function(window, pane)
        local mode = window:active_key_table()
        window:set_left_status((window:leader_is_active() or mode) and wezterm.format {
          { Foreground = { Color = '${p.mauve}' } },
          { Text = '  ' .. (mode or wezterm.nerdfonts.md_record) .. '  ' },
        } or "")
        local cells = {}
        local ws = window:active_workspace()
        if ws ~= 'default' then cells[#cells + 1] = ws end
        for _, b in ipairs(wezterm.battery_info()) do
          cells[#cells + 1] = string.format('%.0f%%', b.state_of_charge * 100)
        end
        cells[#cells + 1] = wezterm.strftime '%H:%M'
        local items = {}
        for _, c in ipairs(cells) do
          items[#items + 1] = { Foreground = { Color = '${p.overlay1}' } }
          items[#items + 1] = { Text = ' ' .. c .. '  ' }
        end
        window:set_right_status(wezterm.format(items))
      end)

      --  KEYS
      -- tmux-style pane management under a CTRL-a leader (1s timeout). CTRL-a is
      -- free in zellij's default keymap (its prefixes are Ctrl p/n/t/o/g/h/b/s/q),
      -- so nesting wezterm-leader inside a zellij session never eats a zellij key.
      config.leader = { key = 'a', mods = 'CTRL', timeout_milliseconds = 1000 }
      config.keys = {
        -- editors own C-S-p (command palette) and C-S-f (search); disable wezterm's
        -- defaults so the chord reaches emacs/nvim (re-homed under LEADER below).
        -- C-S-Space stays QuickSelect (azzie relies on it), so it is left registered.
        { key = 'P', mods = 'CTRL|SHIFT', action = act.DisableDefaultAssignment },
        { key = 'F', mods = 'CTRL|SHIFT', action = act.DisableDefaultAssignment },
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
        -- re-homed editor chords + tmux muscle memory
        { key = 'p', mods = 'LEADER', action = act.ActivateCommandPalette },       -- was C-S-p
        { key = '/', mods = 'LEADER', action = act.Search 'CurrentSelectionOrEmptyString' }, -- was C-S-f
        { key = '[', mods = 'LEADER', action = act.ActivateCopyMode },             -- tmux [
        { key = ']', mods = 'LEADER', action = act.PasteFrom 'Clipboard' },        -- tmux ]
        -- pane picker (labels from quick_select_alphabet), swap, rotate
        { key = 'Space', mods = 'LEADER', action = act.PaneSelect },
        { key = 's', mods = 'LEADER', action = act.PaneSelect { mode = 'SwapWithActive' } },
        { key = 'o', mods = 'LEADER', action = act.RotatePanes 'Clockwise' },
        -- workspaces: fuzzy switcher, and a rename prompt (tmux choose/rename-session)
        { key = 'w', mods = 'LEADER', action = act.ShowLauncherArgs { flags = 'FUZZY|WORKSPACES' } },
        { key = '$', mods = 'LEADER|SHIFT', action = act.PromptInputLine {
            description = 'rename workspace',
            action = wezterm.action_callback(function(_, _, linput)
              if linput and #linput > 0 then
                wezterm.mux.rename_workspace(wezterm.mux.get_active_workspace(), linput)
              end
            end),
        } },
        -- modal resize table: LEADER r, then hjkl, Esc/C-g to exit (mode shows in status)
        { key = 'r', mods = 'LEADER', action = act.ActivateKeyTable {
            name = 'resize_pane', one_shot = false, timeout_milliseconds = 1500 } },
        -- LEADER, CTRL-a sends a literal CTRL-a (keeps readline/nu/zellij start-of-line)
        { key = 'a', mods = 'LEADER|CTRL', action = act.SendKey { key = 'a', mods = 'CTRL' } },
      }

      --  KEY TABLES: modal pane resize + vim-flavored copy mode
      config.key_tables = {
        resize_pane = {
          { key = 'h', action = act.AdjustPaneSize { 'Left', 3 } },
          { key = 'j', action = act.AdjustPaneSize { 'Down', 3 } },
          { key = 'k', action = act.AdjustPaneSize { 'Up', 3 } },
          { key = 'l', action = act.AdjustPaneSize { 'Right', 3 } },
          { key = 'Escape', action = 'PopKeyTable' },
          { key = 'g', mods = 'CTRL', action = 'PopKeyTable' },
        },
      }
      -- extend the default copy_mode table with search + a line-yank that quits.
      -- wezterm.gui is nil under a mux server, so guard it.
      local defs = wezterm.gui and wezterm.gui.default_key_tables() or {}
      local cm = defs.copy_mode or {}
      for _, k in ipairs {
        { key = '/', mods = 'NONE',  action = act.CopyMode 'EditPattern' },
        { key = 'n', mods = 'NONE',  action = act.CopyMode 'NextMatch' },
        { key = 'N', mods = 'SHIFT', action = act.CopyMode 'PriorMatch' },
        { key = 'Y', mods = 'SHIFT', action = act.Multiple {
            act.CopyMode { SetSelectionMode = 'Line' },
            act.CopyTo 'ClipboardAndPrimarySelection',
            act.CopyMode 'Close', act.ScrollToBottom } },
      } do table.insert(cm, k) end
      config.key_tables.copy_mode = cm

      --  DOMAINS: SSH:<host> / SSHMUX:<host> for every Host in ~/.ssh/config (tailnet
      -- boxes reachable on demand). no unix mux / auto-attach: zellij owns multiplexing.
      config.ssh_domains = wezterm.default_ssh_domains()

      config.inactive_pane_hsb = { saturation = 0.8, brightness = 0.6 }
      config.window_frame = {
        font = wezterm.font { family = 'JetBrainsMono Nerd Font', weight = 'Bold' },
        font_size = 12.0,
      }

      -- colors: full inline palette on wired, cursor/selection overrides on macchiato,
      -- then the shared tab-bar / quick-select / copy-mode / bell keys on top
      ${colorsLua}
      ${extraColorsLua}

      return config
    '';
  };
}
