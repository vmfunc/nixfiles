# gh-dash through the hm module: it installs the package AND registers it as a gh
# extension (via programs.gh.extensions), which is what makes `gh dash` (and the prs
# alias) actually resolve; a bare package in home.packages never registers and gh
# answers `unknown command "dash"`. programs.gh is enabled here for that registration.
{ theme, ... }:
{
  programs.nushell.shellAliases.prs = "gh dash";

  programs.gh = {
    enable = true;
    # git.nix resets credential.helper to the sops-populated store file on purpose;
    # the gh helper would shadow it for github.com, so keep gh out of git auth.
    gitCredentialHelper.enable = false;
    # hm owns ~/.config/gh/config.yml now; carry the one non-default the imperative
    # config had so `gh co` keeps working.
    settings.aliases.co = "pr checkout";
  };

  programs.gh-dash = {
    enable = true;
    settings = {
      prSections = [
        {
          title = "Mine";
          filters = "is:open author:@me";
        }
        {
          title = "Soft Machine";
          filters = "is:open org:Soft-Machine-io";
        }
        {
          title = "Needs my review";
          filters = "is:open review-requested:@me";
        }
      ];
      issuesSections = [
        {
          title = "Mine";
          filters = "is:open author:@me";
        }
        {
          title = "Assigned";
          filters = "is:open assignee:@me";
        }
      ];
      defaults = {
        preview = {
          open = true;
          width = 60;
        };
        prsLimit = 20;
        issuesLimit = 20;
      };
      theme.colors = {
        text = {
          primary = theme.palette.text;
          secondary = theme.palette.subtext0;
          inverted = theme.palette.crust;
          faint = theme.palette.overlay0;
          warning = theme.palette.peach;
          success = theme.palette.green;
          error = theme.palette.red;
        };
        background.selected = theme.palette.surface0;
        border = {
          primary = theme.palette.mauve;
          secondary = theme.palette.surface1;
          faint = theme.palette.surface0;
        };
      };
    };
  };
}
