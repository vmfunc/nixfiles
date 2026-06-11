{ pkgs, ... }:
{
  programs.fzf = {
    enable = true;
    defaultCommand = "${pkgs.fd}/bin/fd --type f --hidden --follow --exclude .git";
    defaultOptions = [
      "--height 40%"
      "--layout=reverse"
      "--border"
    ];
    fileWidgetCommand = "${pkgs.fd}/bin/fd --type f --hidden --follow --exclude .git";
    fileWidgetOptions = [ "--preview '${pkgs.bat}/bin/bat --color=always --style=numbers {}'" ];
    changeDirWidgetCommand = "${pkgs.fd}/bin/fd --type d --hidden --follow --exclude .git";
  };
}
