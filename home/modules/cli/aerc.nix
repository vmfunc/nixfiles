# aerc: the TUI mail client (Go, actively-developed, the current pick for terminal
# mail in 2026). themed by hand to the wired variant: catppuccin is OFF for blood/copland,
# so the styleset is painted from theme.palette and rethemes with the variant, no edits.
#
# cross-file deps:
#   - theme.nix (palette spine; the styleset reads theme.palette.*, never hardcoded hex).
#   - secrets/email.yaml (sops): the IMAP/SMTP password, decrypted at activation and read
#     by aerc via *-cred-cmd. declared below so the secret only lands on hosts that import
#     this module (the macs, via home/profiles/desktop-darwin.nix).
#
# account: celeste@collar.sh over mail.camora.dev (imaps 993 / smtps 465). the password
# NEVER touches the store or the public mirror, it is `cat`-ed from the sops runtime path.
# TODO(deploy): if camora.dev does SMTP submission on 587/STARTTLS instead of implicit-TLS
# 465, change `outgoing` to `smtp://...:587` (aerc upgrades STARTTLS automatically).
{
  config,
  theme,
  ...
}:
let
  p = theme.palette;
  # sops decrypts this at activation; aerc reads the first line as the password.
  emailPass = config.sops.secrets."email-password".path;
in
{
  sops.secrets."email-password" = {
    sopsFile = ../../../secrets/email.yaml;
    key = "password";
  };

  programs.aerc = {
    enable = true;

    extraConfig = {
      # our accounts.conf is a store symlink carrying *-cred-cmd (not plaintext
      # passwords), so acknowledging it is store-readable is correct, not a leak.
      general.unsafe-accounts-conf = true;

      ui = {
        styleset-name = "wired";
        # click folders/messages/tabs; wezterm forwards mouse to the tui (SHIFT-drag
        # still does local selection via bypass_mouse_reporting_modifiers).
        mouse-enabled = true;
        threading-enabled = true;
        sidebar-width = 22;
        timestamp-format = "2006-01-02 15:04";
        this-day-time-format = "15:04";
      };

      viewer.pager = "less -R";
      # terminal-first: compose in neovim, not whatever $EDITOR happens to be.
      compose.editor = "nvim";

      # aerc reads ONLY this aerc.conf (no merge with the bundled default), so a
      # custom [ui]/[compose] also drops the default [filters] and every mimetype
      # falls through to the "no filter configured" prompt. restate them. the filter
      # scripts (colorize/html/calendar) ship in aerc's share dir, which aerc puts
      # on PATH automatically; html shells out to w3m (already in the closure).
      filters = {
        "text/plain" = "colorize";
        "text/calendar" = "calendar";
        "message/delivery-status" = "colorize";
        "message/rfc822" = "colorize";
        "text/html" = "html | colorize";
        "application/x-sh" = "colorize";
      };
    };

    extraAccounts = {
      collar = {
        source = "imaps://celeste%40collar.sh@mail.camora.dev:993";
        source-cred-cmd = "cat ${emailPass}";
        outgoing = "smtps://celeste%40collar.sh@mail.camora.dev:465";
        outgoing-cred-cmd = "cat ${emailPass}";
        from = "vmfunc <celeste@collar.sh>";
        copy-to = "Sent";
      };
    };

    # the wired (blood) styleset. brightness carries hierarchy, the plum-rose accent
    # (theme.accent slot = palette.mauve) marks active/selected, red is the lone alarm.
    stylesets.wired = ''
      *.default=true
      *.fg=${p.text}
      *.bg=${p.base}

      # selection: wildcard so EVERY row variant (unread/read/flagged/...) gets the
      # plum accent when the cursor is on it, not just msglist_default. without this
      # a selected unread row keeps its own style and you can't see the cursor.
      *.selected.fg=${p.base}
      *.selected.bg=${p.mauve}
      *.selected.bold=true

      title.fg=${p.base}
      title.bg=${p.mauve}
      title.bold=true
      header.fg=${p.mauve}
      header.bold=true

      default.fg=${p.text}
      error.fg=${p.red}
      error.bold=true
      warning.fg=${p.yellow}
      success.fg=${p.green}

      border.fg=${p.surface1}
      border.bg=${p.base}

      spinner.fg=${p.mauve}

      msglist_default.fg=${p.text}
      msglist_unread.fg=${p.text}
      msglist_unread.bold=true
      msglist_read.fg=${p.subtext0}
      msglist_flagged.fg=${p.yellow}
      msglist_flagged.bold=true
      msglist_deleted.fg=${p.overlay0}
      msglist_marked.fg=${p.base}
      msglist_marked.bg=${p.green}
      msglist_result.fg=${p.yellow}
      msglist_answered.fg=${p.green}
      msglist_forwarded.fg=${p.teal}
      msglist_gutter.fg=${p.surface1}
      msglist_pill.fg=${p.base}
      msglist_pill.bg=${p.mauve}
      msglist_thread_folded.fg=${p.peach}
      msglist_thread_context.fg=${p.subtext0}

      dirlist_default.fg=${p.subtext0}
      dirlist_unread.fg=${p.mauve}
      dirlist_unread.bold=true
      dirlist_recent.fg=${p.green}

      statusline_default.fg=${p.text}
      statusline_default.bg=${p.surface0}
      statusline_error.fg=${p.base}
      statusline_error.bg=${p.red}
      statusline_success.fg=${p.base}
      statusline_success.bg=${p.green}

      completion_default.fg=${p.text}
      completion_default.bg=${p.surface0}
      completion_description.fg=${p.subtext0}
      completion_gutter.bg=${p.surface1}
      completion_pill.bg=${p.mauve}

      part_switcher.fg=${p.text}
      part_filename.fg=${p.blue}
      part_mimetype.fg=${p.subtext0}

      selector_default.fg=${p.text}
      selector_focused.fg=${p.base}
      selector_focused.bg=${p.mauve}
      selector_chooser.fg=${p.mauve}

      tab.fg=${p.subtext0}
    '';
  };
}
