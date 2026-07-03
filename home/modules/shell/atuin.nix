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

      # sync target is cuttlefish's self-hosted atuin server over the tailnet
      # (magicdns suffix tailc04c2f.ts.net). plain http on purpose: the server binds
      # tailnet-only and wireguard already encrypts the transport, there is no cert
      # to terminate. live once cuttlefish is deployed and running atuin-server;
      # until then auto_sync just retries on the schedule.
      sync_address = "http://cuttlefish.tailc04c2f.ts.net:8888";
      auto_sync = true;
      sync_frequency = "5m";

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
