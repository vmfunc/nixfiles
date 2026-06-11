{ theme, ... }:
{
  programs.nushell.shellAliases.prs = "gh dash";

  xdg.configFile."gh-dash/config.yml".text = ''
    prSections:
      - title: Mine
        filters: is:open author:@me
      - title: Soft Machine
        filters: is:open org:Soft-Machine-io
      - title: Needs my review
        filters: is:open review-requested:@me
    issuesSections:
      - title: Mine
        filters: is:open author:@me
      - title: Assigned
        filters: is:open assignee:@me
    defaults:
      preview:
        open: true
        width: 60
      prsLimit: 20
      issuesLimit: 20
    theme:
      colors:
        text:
          primary: "${theme.palette.text}"
          secondary: "${theme.palette.subtext0}"
          inverted: "${theme.palette.crust}"
          faint: "${theme.palette.overlay0}"
          warning: "${theme.palette.peach}"
          success: "${theme.palette.green}"
          error: "${theme.palette.red}"
        background:
          selected: "${theme.palette.surface0}"
        border:
          primary: "${theme.palette.mauve}"
          secondary: "${theme.palette.surface1}"
          faint: "${theme.palette.surface0}"
  '';
}
