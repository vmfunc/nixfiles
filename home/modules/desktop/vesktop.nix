# Vencord quickCss for a somewhat-transparent Discord.
# Relies on Vesktop window vibrancy, already set in the Vencord settings:
#   transparent = true; macosVibrancyStyle = "under-page";
# Managed declaratively -> symlinked read-only from the nix store, so don't
# edit it in-app (the in-app quickCss editor will fail to save).
{ ... }:
{
  home.file."Library/Application Support/vesktop/settings/quickCss.css".text = ''
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
}
