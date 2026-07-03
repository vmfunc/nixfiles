# fzf + the fd/bat commands it should use. home-manager exports these values only
# through home.sessionVariables (plus posix initExtra hooks), and the only shell on
# these boxes is nushell, so they reach a live shell via nushell.nix's session-var
# mirror. hm's own fzf nushell integration wires ctrl-t/ctrl-r/alt-c into config.nu
# and reads the FZF_* vars from the environment at keypress time, so the fd walkers
# and bat preview below stay the one source of truth.
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
