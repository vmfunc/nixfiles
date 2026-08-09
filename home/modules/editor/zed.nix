# zed: the rust/gpu code editor ("zen for code"). plain package; the terminal-first
# editors (neovim/helix/doom) stay the daily drivers, zed is the gui option for when
# a project wants one. scoped via desktop-linux (all linux desktops).
{ pkgs, ... }:
{
  home.packages = [ pkgs.zed-editor ];
}
