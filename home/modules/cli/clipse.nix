# clipse clipboard manager: theme + config json painted straight from theme.palette
# (clipse's json has no catppuccin integration, per the CLAUDE.md raw-theme allowlist)
# plus the history listener (launchd agent on the macs, systemd user unit on linux).
# aerospace.nix binds alt-c to the TUI on the macs; niri.nix binds it on tuna.
{
  config,
  lib,
  pkgs,
  theme,
  ...
}:
let
  isDarwin = pkgs.stdenv.hostPlatform.isDarwin;
  p = theme.palette;

  # clipse 1.2.x renamed the key to `useCustom` (nixpkgs ships 1.2.1 now); the old
  # `useCustomTheme` is silently ignored and the whole theme falls back to the default
  customTheme = {
    useCustom = true;

    # title bar
    TitleFore = p.crust;
    TitleBack = p.mauve;
    TitleInfo = p.subtext0;

    # list rows
    NormalTitle = p.text;
    DimmedTitle = p.overlay1;
    SelectedTitle = p.mauve;
    NormalDesc = p.subtext0;
    DimmedDesc = p.overlay0;
    SelectedDesc = p.lavender;
    StatusMsg = p.green;
    PinIndicatorColor = p.yellow;

    # selected-row borders
    SelectedBorder = p.mauve;
    SelectedDescBorder = p.mauve;

    # filter / search
    FilteredMatch = p.peach;
    FilterPrompt = p.green;
    FilterInfo = p.subtext0;
    FilterText = p.text;
    FilterCursor = p.mauve;

    # help footer
    HelpKey = p.overlay2;
    HelpDesc = p.overlay0;

    # pagination dots + preview
    PageActiveDot = p.mauve;
    PageInactiveDot = p.surface2;
    DividerDot = p.overlay0;
    PreviewedText = p.text;
    PreviewBorder = p.mauve;
  };

  clipseConfig = {
    allowDuplicates = false;
    historyFile = "clipboard_history.json";
    maxHistory = 100;
    logFile = "clipse.log";
    themeFile = "custom_theme.json";
    tempDir = "tmp_files";
    keyBindings = { };
    imageDisplay = {
      type = "basic";
      scaleX = 9;
      scaleY = 9;
      heightCut = 2;
    };
  };
in
{
  home.packages = [ pkgs.clipse ];

  xdg.configFile = {
    "clipse/custom_theme.json".text = builtins.toJSON customTheme;
    "clipse/config.json".text = builtins.toJSON clipseConfig;
  };

  # -listen-shell is the in-process blocking listener; -listen detaches and would
  # respawn-loop under a keepalive supervisor. macs get the launchd agent, linux the
  # systemd user unit; both run the SAME blocking listener under graphical-session.
  launchd.agents.clipse = lib.mkIf isDarwin {
    enable = true;
    config = {
      ProgramArguments = [
        "${pkgs.clipse}/bin/clipse"
        "-listen-shell"
      ];
      RunAtLoad = true;
      KeepAlive = true;
      ProcessType = "Background";
      LowPriorityIO = true;
      StandardOutPath = "${config.home.homeDirectory}/Library/Logs/clipse.log";
      StandardErrorPath = "${config.home.homeDirectory}/Library/Logs/clipse.log";
    };
  };

  systemd.user.services.clipse = lib.mkIf (!isDarwin) {
    Unit = {
      Description = "clipse clipboard history listener";
      PartOf = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart = "${pkgs.clipse}/bin/clipse -listen-shell";
      Restart = "always";
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };
}
