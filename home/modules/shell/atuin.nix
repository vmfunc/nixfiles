{ ... }:
{
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

      # sync
      # replace <tailnet> with the magicdns suffix once tailscale is up
      sync_address = "https://cuttlefish.<tailnet>.ts.net";
      auto_sync = true;
      sync_frequency = "5m";

      sync.records = true;
    };
  };
}
