{ username, ... }:
{
  system.defaults = {
    NSGlobalDomain = {
      InitialKeyRepeat = 15;
      KeyRepeat = 2;
      ApplePressAndHoldEnabled = false;
      AppleInterfaceStyle = "Dark";
      _HIHideMenuBar = true; # sketchybar replaces it
      NSAutomaticWindowAnimationsEnabled = false;
      NSWindowResizeTime = 0.001;
      NSDocumentSaveNewDocumentsToCloud = false;

      NSAutomaticCapitalizationEnabled = false;
      NSAutomaticDashSubstitutionEnabled = false;
      NSAutomaticPeriodSubstitutionEnabled = false;
      NSAutomaticQuoteSubstitutionEnabled = false;
      NSAutomaticSpellingCorrectionEnabled = false;
      NSWindowShouldDragOnGesture = true;
    };

    dock = {
      autohide = true;
      autohide-delay = 0.0;
      autohide-time-modifier = 0.15;
      show-recents = false;
      static-only = true;
      mru-spaces = false;
      tilesize = 44;
      orientation = "bottom";
      expose-animation-duration = 0.1;
    };

    finder = {
      AppleShowAllExtensions = true;
      FXPreferredViewStyle = "Nlsv";
      ShowPathbar = true;
      ShowStatusBar = true;
      _FXShowPosixPathInTitle = true;
      CreateDesktop = false;
    };

    WindowManager = {
      EnableStandardClickToShowDesktop = false;
      StandardHideDesktopIcons = true;
      StandardHideWidgets = true;
      StageManagerHideWidgets = true;
      HideDesktop = true;
    };

    # tiling needs separate spaces per display
    spaces.spans-displays = false;

    loginwindow.GuestEnabled = false;

    # desktop is hidden so default screenshot location would vanish them; the dir
    # is created by home.activation.screenshotsDir (home/profiles/desktop-darwin.nix)
    screencapture = {
      type = "png";
      disable-shadow = true;
      location = "/Users/${username}/workspace/screenshots";
    };

    # no typed system.defaults option for this domain; stop .DS_Store litter on USB + network shares
    CustomUserPreferences."com.apple.desktopservices" = {
      DSDontWriteUSBStores = true;
      DSDontWriteNetworkStores = true;
    };
  };
}
