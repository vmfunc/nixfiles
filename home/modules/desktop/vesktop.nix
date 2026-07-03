# Vencord quickCss for a somewhat-transparent Discord, delivered through home-manager's
# programs.vesktop (it owns Library/Application Support/vesktop on darwin; a hand-written
# home.file there would fight the module for the same path). the module also installs the
# package, so vesktop is NOT listed in home/profiles/desktop-darwin.nix home.packages.
# the css is store-symlinked read-only, so the in-app quickCss editor will fail to save;
# edit it here instead.
#
# vesktop's OWN settings.json stays imperative (in-app) on purpose: declaring
# programs.vesktop.settings would freeze the whole file read-only and silently drop every
# toggle flipped in-app (arRPC for the rich-presence modules, tray, ...), a worse trade
# than two manual clicks.
# TODO(deploy): the css only shows through with window vibrancy on; in Vesktop settings
# set transparent = true and macosVibrancyStyle = "under-page" once per machine.
{ ... }:
{
  programs.vesktop = {
    enable = true;
    vencord.extraQuickCss = ''
      /* let the vibrant window show through the app frame */
      .theme-dark,
      .theme-light,
      .visual-refresh {
        --bg-overlay-app-frame: transparent !important;
      }

      /* translucent background tokens (legacy + visual-refresh names) */
      .theme-dark {
        --background-primary: rgba(30, 31, 34, 0.55) !important;
        --background-secondary: rgba(43, 45, 49, 0.55) !important;
        --background-secondary-alt: rgba(35, 36, 40, 0.6) !important;
        --background-tertiary: rgba(24, 25, 28, 0.55) !important;
        --background-floating: rgba(24, 25, 28, 0.85) !important;
        --background-message-hover: rgba(0, 0, 0, 0.1) !important;
        --channeltextarea-background: rgba(56, 58, 64, 0.5) !important;

        --bg-base-primary: rgba(30, 31, 34, 0.55) !important;
        --bg-base-secondary: rgba(43, 45, 49, 0.55) !important;
        --bg-base-tertiary: rgba(24, 25, 28, 0.55) !important;
        --bg-surface-raised: rgba(43, 45, 49, 0.55) !important;
        --bg-surface-overlay: rgba(24, 25, 28, 0.85) !important;
      }
    '';
  };
}
