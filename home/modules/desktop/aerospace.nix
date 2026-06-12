{ pkgs, lib, ... }:
lib.mkIf pkgs.stdenv.hostPlatform.isDarwin {
  programs.aerospace = {
    enable = true;
    launchd.enable = true;
    settings = {
      start-at-login = false;

      # tell sketchybar to refresh when the workspace changes
      exec-on-workspace-change = [
        "/bin/bash"
        "-c"
        "${pkgs.sketchybar}/bin/sketchybar --trigger aerospace_workspace_change FOCUSED_WORKSPACE=$AEROSPACE_FOCUSED_WORKSPACE"
      ];

      enable-normalization-flatten-containers = true;
      enable-normalization-opposite-orientation-for-nested-containers = true;

      # mouse follows focus
      on-focus-changed = [ "move-mouse window-lazy-center" ];
      on-focused-monitor-changed = [ "move-mouse monitor-lazy-center" ];

      # during-aerospace-startup=false so a restart never reshuffles existing windows
      on-window-detected =
        let
          assign = name: ws: {
            "if" = {
              app-name-regex-substring = name;
              during-aerospace-startup = false;
            };
            run = "move-node-to-workspace ${toString ws}";
          };
        in
        [
          (assign "Signal" 2)
          (assign "Telegram" 2)
          (assign "Cinny" 2)
          (assign "Vesktop" 2)
          (assign "Fastmail" 2)
          (assign "Zen" 3)
          (assign "Safari" 3)
          (assign "Chromium" 3)
          (assign "Burp" 7)
          (assign "Wireshark" 7)
          (assign "Spotify" 9)
        ];

      accordion-padding = 30;
      default-root-container-layout = "tiles";
      default-root-container-orientation = "auto";

      # first connected monitor regex wins; 1-7 on the odyssey, 8-9 on the laptop
      workspace-to-monitor-force-assignment = {
        "1" = [
          "Odyssey"
          "Built-in"
        ];
        "2" = [
          "Odyssey"
          "Built-in"
        ];
        "3" = [
          "Odyssey"
          "Built-in"
        ];
        "4" = [
          "Odyssey"
          "Built-in"
        ];
        "5" = [
          "Odyssey"
          "Built-in"
        ];
        "6" = [
          "Odyssey"
          "Built-in"
        ];
        "7" = [
          "Odyssey"
          "Built-in"
        ];
        "8" = [
          "Built-in"
          "Odyssey"
        ];
        "9" = [
          "Built-in"
          "Odyssey"
        ];
      };

      # outer.top leaves room for sketchybar
      gaps = {
        inner.horizontal = 8;
        inner.vertical = 8;
        outer.left = 8;
        outer.bottom = 8;
        outer.top = 40;
        outer.right = 8;
      };

      mode.main.binding = {
        # focus
        alt-h = "focus left";
        alt-j = "focus down";
        alt-k = "focus up";
        alt-l = "focus right";

        # move
        alt-shift-h = "move left";
        alt-shift-j = "move down";
        alt-shift-k = "move up";
        alt-shift-l = "move right";

        # resize
        alt-minus = "resize smart -50";
        alt-equal = "resize smart +50";

        # layouts
        alt-slash = "layout tiles horizontal vertical";
        alt-comma = "layout accordion horizontal vertical";

        # stacking
        alt-v = "layout tiles vertical";
        alt-shift-v = "layout tiles horizontal";
        alt-shift-f = "flatten-workspace-tree";
        alt-ctrl-h = "join-with left";
        alt-ctrl-j = "join-with down";
        alt-ctrl-k = "join-with up";
        alt-ctrl-l = "join-with right";
        alt-f = "fullscreen";
        alt-shift-space = "layout floating tiling";

        alt-enter = "exec-and-forget open -n -a WezTerm";
        alt-shift-q = "close";
        alt-space = "exec-and-forget open -a Raycast";
        alt-shift-d = "exec-and-forget open -a Raycast";

        alt-b = "exec-and-forget open -a Safari";
        alt-m = "exec-and-forget ${pkgs.wezterm}/bin/wezterm start --always-new-process -- ${pkgs.ncspot}/bin/ncspot";
        alt-c = "exec-and-forget ${pkgs.wezterm}/bin/wezterm start --always-new-process -- ${pkgs.clipse}/bin/clipse";
        alt-shift-s = "exec-and-forget screencapture -i -c";

        # screen recording toggle (system audio, no mic); same key stops and saves
        alt-ctrl-s = "exec-and-forget ${pkgs.record}/bin/record";

        # media keys
        alt-shift-period = "exec-and-forget osascript -e 'set volume output volume (output volume of (get volume settings) + 10)' -e 'do shell script \"/run/current-system/sw/bin/sketchybar --trigger volume_change\"'";
        alt-shift-comma = "exec-and-forget osascript -e 'set volume output volume (output volume of (get volume settings) - 10)' -e 'do shell script \"/run/current-system/sw/bin/sketchybar --trigger volume_change\"'";
        alt-shift-m = "exec-and-forget osascript -e 'set volume output muted (not (output muted of (get volume settings)))' -e 'do shell script \"/run/current-system/sw/bin/sketchybar --trigger volume_change\"'";

        # workspaces
        alt-1 = "workspace 1";
        alt-2 = "workspace 2";
        alt-3 = "workspace 3";
        alt-4 = "workspace 4";
        alt-5 = "workspace 5";
        alt-6 = "workspace 6";
        alt-7 = "workspace 7";
        alt-8 = "workspace 8";
        alt-9 = "workspace 9";

        alt-shift-1 = "move-node-to-workspace 1";
        alt-shift-2 = "move-node-to-workspace 2";
        alt-shift-3 = "move-node-to-workspace 3";
        alt-shift-4 = "move-node-to-workspace 4";
        alt-shift-5 = "move-node-to-workspace 5";
        alt-shift-6 = "move-node-to-workspace 6";
        alt-shift-7 = "move-node-to-workspace 7";
        alt-shift-8 = "move-node-to-workspace 8";
        alt-shift-9 = "move-node-to-workspace 9";

        alt-tab = "workspace-back-and-forth";
        alt-shift-tab = "move-workspace-to-monitor --wrap-around next";

        alt-shift-c = "reload-config";
        alt-shift-r = "mode resize";
        alt-shift-semicolon = "mode service";
      };

      mode.resize.binding = {
        h = "resize width -50";
        j = "resize height +50";
        k = "resize height -50";
        l = "resize width +50";
        enter = "mode main";
        esc = "mode main";
      };

      mode.service.binding = {
        esc = [
          "reload-config"
          "mode main"
        ];
        r = [
          "flatten-workspace-tree"
          "mode main"
        ];
        f = [
          "layout floating tiling"
          "mode main"
        ];
        backspace = [
          "close-all-windows-but-current"
          "mode main"
        ];
        equal = [
          "balance-sizes"
          "mode main"
        ];
      };
    };
  };
}
