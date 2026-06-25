# ghostty.nix — the Lain CRT terminal.
#
# ghostty rendered as a warm amber Copland-OS tube: every color is read from the
# `theme` specialArg (palette + the 16 ANSI from theme.ansi16) exactly like
# wezterm.nix, so the copland/blood/macchiato variants all retheme with no edits
# here. the CRT look (subtle scanlines + phosphor bloom + vignette) is driven by a
# shipped fragment shader (./crt.glsl) wired through ghostty's custom-shader.
#
# cross-file deps: theme.nix (palette + ansi16), home/modules/terminal/crt.glsl,
# home/modules/terminal/wezterm.nix (the nu launch path is kept in lockstep).
# darwin-only: the macs run ghostty; gate so a nixos eval never pulls it in.
{
  theme,
  username,
  pkgs,
  lib,
  ...
}:
let
  # ghostty wants palette entries as "INDEX=#hex"; map the theme's 16 ANSI in order.
  paletteEntries = lib.imap0 (i: hex: "${toString i}=${hex}") theme.ansi16;

  # ship the CRT shader into the ghostty config dir so custom-shader can find it by an
  # absolute path under $XDG_CONFIG_HOME (ghostty resolves relative paths from there too,
  # but absolute keeps it unambiguous regardless of cwd at launch).
  shaderPath = "ghostty/shaders/crt.glsl";
in
lib.mkIf pkgs.stdenv.hostPlatform.isDarwin {
  xdg.configFile.${shaderPath}.source = ./crt.glsl;

  programs.ghostty = {
    enable = true;
    # nixpkgs refuses to build ghostty on aarch64-darwin, so install it via a homebrew
    # cask (modules/darwin/homebrew.nix) and let home-manager manage ONLY the config.
    # package = null also skips the `ghostty +validate-config` activation hook (no binary).
    package = null;

    settings = {
      # colors: all from the theme so every variant stays correct. background/foreground
      # take ghostty bare hex; cursor + selection map onto the same palette slots wezterm uses.
      background = theme.palette.base;
      foreground = theme.palette.text;
      cursor-color = theme.palette.mauve;
      cursor-text = theme.palette.crust;
      selection-background = theme.palette.surface1;
      selection-foreground = theme.palette.text;
      palette = paletteEntries;

      # Cozette is the pixel face for the CRT; JetBrainsMono NF backstops glyph coverage.
      font-family = [
        "Cozette"
        "JetBrainsMono Nerd Font"
      ];
      font-size = 14;

      # tasteful breathing room around the grid; balanced so the vignette has a margin to seat in.
      window-padding-x = 14;
      window-padding-y = 12;
      window-padding-balance = true;

      # the CRT pass: scanlines + phosphor bloom + vignette, calibrated subtle in the glsl.
      custom-shader = "${shaderPath}";
      # animation off: this shader is static (no iTime), so don't spin the GPU idling on it.
      custom-shader-animation = false;

      # launch the same nushell wezterm does (where all the rice shell config lives), not zsh.
      command = "/etc/profiles/per-user/${username}/bin/nu --login --interactive";

      mouse-hide-while-typing = true;
      window-decoration = true;
      confirm-close-surface = false;
    };
  };
}
