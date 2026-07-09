# newsboat: terminal RSS/atom reader, the hikikomori-canonical way to follow
# every JP blog / booru / site without opening a browser. colored to the plum
# accents of the blood rice with named terminal colors (newsboat has no hex, so
# it can't read theme.palette directly). feeds are yours to add in `urls`.
# deps: consumed via home/profiles/base.nix (cross-platform).
{ ... }:
{
  programs.newsboat = {
    enable = true;
    autoReload = true;
    reloadThreads = 8;

    # add feeds here, e.g. { url = "https://..."; tags = [ "anime" ]; }
    urls = [ ];

    extraConfig = ''
      # plum-accented scheme to match the blood variant.
      color background          default default
      color listnormal          default default
      color listfocus           color0  magenta
      color listnormal_unread   magenta default bold
      color listfocus_unread    color0  magenta bold
      color info                color0  magenta bold
      color article             default default

      # vim-ish keys + sane reload/behaviour.
      bind-key j down
      bind-key k up
      bind-key G end
      bind-key g home
      show-read-feeds no
      confirm-exit no
      cleanup-on-quit yes
      text-width 100
    '';
  };
}
