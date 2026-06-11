{ pkgs, ... }:
{
  programs.yazi = {
    enable = true;
    enableNushellIntegration = true;

    plugins = {
      inherit (pkgs.yaziPlugins) git full-border starship;
    };

    initLua = ''
      require("git"):setup()
      require("full-border"):setup()
      require("starship"):setup()
    '';
  };
}
