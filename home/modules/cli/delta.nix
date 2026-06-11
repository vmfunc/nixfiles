{ pkgs, theme, ... }:
{
  home.packages = [ pkgs.delta ];

  programs.git.settings = {
    core.pager = "delta";
    interactive.diffFilter = "delta --color-only";
    delta = {
      navigate = true; # n/N to hop between files
      "line-numbers" = true;
      "side-by-side" = true;
      "file-style" = "bold ${theme.palette.mauve}";
      "file-decoration-style" = "${theme.palette.mauve} ul";
      "hunk-header-decoration-style" = "${theme.palette.overlay0} box";
      "line-numbers-left-style" = theme.palette.overlay0;
      "line-numbers-right-style" = theme.palette.overlay0;
      "line-numbers-minus-style" = theme.palette.red;
      "line-numbers-plus-style" = theme.palette.green;
      "zero-style" = "syntax";
    };
  };
}
