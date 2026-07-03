{
  config,
  lib,
  theme,
  ...
}:
{
  # catppuccin is OFF for the wired variants, so atuin lost its themed palette. ship a custom
  # atuin theme built from theme.palette and point the [theme] section at it. no hardcoded
  # hex, every variant regenerates this file.
  xdg.configFile."atuin/themes/wired.toml".text = ''
    [theme]
    name = "wired"

    [colors]
    AlertInfo = "${theme.palette.green}"
    AlertWarn = "${theme.palette.yellow}"
    AlertError = "${theme.palette.red}"
    Annotation = "${theme.palette.overlay1}"
    Base = "${theme.palette.text}"
    Guidance = "${theme.palette.subtext0}"
    Important = "${theme.palette.mauve}"
    Title = "${theme.palette.mauve}"
  '';

  programs.atuin = {
    enable = true;
    enableNushellIntegration = true;
    daemon.enable = true;
    flags = [ "--disable-up-arrow" ];
    settings = {
      style = "compact";
      inline_height = 14;
      show_preview = true;
      enter_accept = false;
      keymap_mode = "vim-insert";
      filter_mode_shell_up_key_binding = "session";

      # atuin runs local-only: the self-hosted sync server lived on cuttlefish, which
      # is gone, and no other host runs atuin-server yet. flip auto_sync back on (and
      # set sync_address) once a server is stood up again, e.g. on the coming linux box.
      auto_sync = false;

      sync.records = true;
    }
    # on macchiato the catppuccin hm module sets its own settings.theme.name, and two
    # definitions of the same leaf collide; the wired theme file only owns the slot
    # when catppuccin is off.
    // lib.optionalAttrs (config.rice.theme.variant != "macchiato") {
      theme.name = "wired";
    };
  };
}
