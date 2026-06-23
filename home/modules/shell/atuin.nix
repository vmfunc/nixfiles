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

      # sync target is cuttlefish's self-hosted atuin server over the tailnet
      # (magicdns suffix tailc04c2f.ts.net). live once cuttlefish is deployed and
      # running atuin-server; until then auto_sync just retries on the schedule.
      sync_address = "https://cuttlefish.tailc04c2f.ts.net";
      auto_sync = true;
      sync_frequency = "5m";

      sync.records = true;
    };
  };
}
