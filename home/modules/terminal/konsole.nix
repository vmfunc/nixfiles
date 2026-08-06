# konsole, the plasma tablet session's terminal (rice.tablet.plasmaSession).
# stock konsole boots bash on the default scheme, so the one terminal in tablet
# posture missed the whole rice: this ships a `wired` profile that launches the
# same nushell wezterm/ghostty do (starship + all shell config ride along) and a
# colorscheme generated from the `theme` specialArg, so every variant flip
# rethemes konsole with no edits here. there is NO programs.konsole in
# home-manager (never merged upstream), so the profile + colorscheme land as
# plain xdg data files.
#
# cross-file deps: theme.nix (palette + ansi16); wezterm.nix (nu launch path,
# font face and the 0.85 sheer are kept in lockstep); modules/nixos/tablet.nix
# owns the plasma session this exists for.
{
  theme,
  username,
  lib,
  pkgs,
  ...
}:
let
  p = theme.palette;

  # kconfig color entries are decimal "r,g,b", not hex.
  rgb =
    hex:
    lib.concatMapStringsSep "," (i: toString (lib.fromHexString (builtins.substring i 2 hex))) [
      1
      3
      5
    ];

  # theme.ansi16 in konsole's naming: 0-7 -> ColorN, 8-15 -> ColorNIntense.
  # Faint mirrors the normal 8: the palettes already carry hierarchy in their
  # brightness ladder, a second hand-dimmed ramp would just drift from the theme.
  ansiSections =
    lib.listToAttrs (
      lib.imap0 (i: hex: {
        name = "Color${toString (lib.mod i 8)}" + lib.optionalString (i >= 8) "Intense";
        value.Color = rgb hex;
      }) theme.ansi16
    )
    // lib.listToAttrs (
      lib.imap0 (i: hex: {
        name = "Color${toString i}Faint";
        value.Color = rgb hex;
      }) (lib.sublist 0 8 theme.ansi16)
    );

  colorScheme = lib.generators.toINI { } (
    ansiSections
    // {
      Background.Color = rgb p.base;
      BackgroundIntense.Color = rgb p.base;
      BackgroundFaint.Color = rgb p.base;
      Foreground.Color = rgb p.text;
      ForegroundIntense.Color = rgb p.text;
      ForegroundFaint.Color = rgb p.subtext0;
      General = {
        Description = "wired ${theme.variant}";
        # same sheer as wezterm's window_background_opacity; kwin's blur effect
        # composites behind it under plasma, so text stays readable.
        Opacity = 0.85;
        Blur = true;
      };
    }
  );

  profile = lib.generators.toINI { } {
    General = {
      Name = "wired";
      Parent = "FALLBACK/";
      # launch the same nushell wezterm does (all the rice shell config lives
      # there), not the login bash.
      Command = "/etc/profiles/per-user/${username}/bin/nu --login --interactive";
      # breathing room around the grid, the wezterm padding's konsole twin.
      TerminalMargin = 14;
    };
    Appearance = {
      ColorScheme = "wired";
      # CozetteVector at wezterm's size; the 10-field QFont string is the legacy
      # form QFont::fromString still accepts, safer than chasing qt6's 16 fields.
      Font = "CozetteVector,14,-1,5,50,0,0,0,0,0";
    };
    Scrolling = {
      HistorySize = 10000;
      # 2 = hidden: fingers flick to scroll in tablet posture, the bar is noise.
      ScrollBarPosition = 2;
    };
    "Cursor Options" = {
      # 1 = i-beam, the accent-colored breathing bar the other terminals run.
      CursorShape = 1;
      UseCustomCursorColor = true;
      CustomCursorColor = rgb p.mauve;
    };
    "Terminal Features".BlinkingCursorEnabled = true;
  };
in
# linux-only insurance: imported solely from minnow today, but kdePackages is
# linux territory; a stray darwin import stays a no-op instead of an eval break.
lib.mkIf (!pkgs.stdenv.hostPlatform.isDarwin) {
  xdg.dataFile."konsole/wired.profile".text = profile;
  xdg.dataFile."konsole/wired.colorscheme".text = colorScheme;

  # konsolerc must stay MUTABLE: konsole rewrites it at runtime (window state,
  # menu toggles), so a store symlink would be replaced on first run and then
  # backup-churned by every switch. kwriteconfig6 surgically pins just the
  # default-profile key and leaves the rest of the file to konsole.
  home.activation.konsoleDefaultProfile = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    run ${pkgs.kdePackages.kconfig}/bin/kwriteconfig6 --file konsolerc \
      --group "Desktop Entry" --key DefaultProfile wired.profile
  '';
}
