{ ... }:
{
  imports = [
    ../modules/theme.nix
    ../modules/wired-name.nix

    ../modules/shell/nushell.nix
    ../modules/shell/starship.nix
    ../modules/shell/carapace.nix
    ../modules/shell/zoxide.nix
    ../modules/shell/fzf.nix
    ../modules/shell/atuin.nix
    ../modules/shell/fastfetch.nix

    ../modules/cli/packages.nix
    ../modules/cli/tealdeer.nix
    ../modules/cli/gh-dash.nix
    ../modules/cli/git.nix
    ../modules/cli/go.nix
    ../modules/cli/gpg.nix
    ../modules/cli/eza.nix
    ../modules/cli/bat.nix
    ../modules/cli/delta.nix
    ../modules/cli/btop.nix
    ../modules/cli/nix-index.nix
    ../modules/cli/restic.nix
    ../modules/cli/sops.nix
    ../modules/cli/claude.nix
    ../modules/cli/plan.nix
    ../modules/cli/nixfiles-sync.nix
    ../modules/cli/yazi.nix
    ../modules/cli/newsboat.nix
    ../modules/cli/lazygit.nix
    ../modules/cli/zellij.nix
    ../modules/cli/cava.nix
    ../modules/cli/clipse.nix
    ../modules/cli/syncthing.nix
    ../modules/cli/direnv.nix
    ../modules/cli/nh.nix

    ../modules/editor/neovim.nix
    ../modules/terminal/wezterm.nix
  ];
}
