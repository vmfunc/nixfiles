{ theme, ... }:
{
  programs.delta = {
    enable = true;
    # wires pager.{diff,log,show,blame} + interactive.diffFilter into git's config
    # with store-path binaries, so git never depends on delta being on PATH.
    enableGitIntegration = true;
    options = {
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
