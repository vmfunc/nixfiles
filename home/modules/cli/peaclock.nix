# peaclock, the sits-there block clock for an ambient pane. digital view, block
# segments in the accent over faint ghost segments (inactive-bg surface0, the CRT
# afterglow read), background left clear so the translucent wezterm glass shows
# through the clock. colored by hand from theme.palette (wired variants;
# catppuccin.enable is false there), so a theme.nix variant swap recolors it.
# config is peaclock's own command-per-line grammar (see `peaclock --help`), NOT
# ini/toml; there is no check flag, so the smoke test is running it in a pty.
# deps: imported from home/profiles/base.nix next to cava.nix (the other ambient).
{ pkgs, theme, ... }:
let
  p = theme.palette;
  # peaclock hard-defaults its config dir to ~/.peaclock; wrap it onto the XDG
  # path (upstream's own readme suggests this exact aliasing, done here as a
  # wrapper so every caller gets it, not just interactive shells).
  peaclock = pkgs.writeShellScriptBin "peaclock" ''
    exec ${pkgs.peaclock}/bin/peaclock \
      --config-dir "''${XDG_CONFIG_HOME:-$HOME/.config}/peaclock" "$@"
  '';
in
{
  home.packages = [ peaclock ];

  xdg.configFile."peaclock/config".text = ''
    mode clock
    view digital
    date '%a %b %d'
    set hour-24 on
    set seconds on
    set date on
    # fill the pane, keeping terminal-cell-aware square-ish blocks
    set auto-size on
    set auto-ratio on
    ratio 2 1

    # accent blocks over ghost segments; the lone accent rule as everywhere else
    style active-bg ${p.mauve}
    style inactive-bg ${p.surface0}
    style colon-bg ${p.mauve}
    style date ${p.subtext0}
    style background clear
    style text ${p.text}
    style prompt ${p.mauve}
    style success ${p.green}
    style error ${p.red}
  '';
}
