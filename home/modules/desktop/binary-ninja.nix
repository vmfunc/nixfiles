# Binary Ninja: the licensed disassembler/decompiler, themed to the wired variant.
# cross-platform: the macs and tuna (linux) both get the theme + the MCP plugin,
# only the user-dir path differs (~/Library/Application Support/Binary Ninja on
# darwin, ~/.binaryninja on linux).
#
# the APP itself is NOT managed by nix on either platform. nixpkgs packages neither
# the free nor the commercial BN, and the licensed build is a manual download from
# her account (CLAUDE.md rule 12, doubly). the linux build extracts to ~/binaryninja
# and gets launched from there.
# TODO(deploy): install the commercial Binary Ninja from binary.ninja (login > download).
#   macs: drop the .app in /Applications; uninstall the free cask if present
#   (`brew uninstall --cask binary-ninja-free`) so the two .apps don't collide.
#   tuna: extract the linux tarball to ~/binaryninja, run ~/binaryninja/binaryninja once
#   to register the license, then Plugins > MCP Server > Start Server.
# this module owns the colorscheme (a generated .bntheme, selectable in Preferences >
# Theme as "Wired Blood") + the MCP plugin symlink.
#
# cross-file deps: theme.nix (palette spine). every color is derived from theme.palette
# and re-rendered to RGB at build time, so a variant swap (blood/copland/macchiato) moves
# the BN theme with everything else, no hardcoded hex.
{
  config,
  lib,
  pkgs,
  theme,
  ...
}:
let
  p = theme.palette;

  # BN's user dir differs by platform; both are under $HOME so both stay home.file.
  bnDir =
    if pkgs.stdenv.hostPlatform.isDarwin then
      "Library/Application Support/Binary Ninja"
    else
      ".binaryninja";

  # BN wants colors as [ r g b ] integer arrays. "#rrggbb" -> [r g b].
  toRGB = hex: [
    (lib.fromHexString (builtins.substring 1 2 hex))
    (lib.fromHexString (builtins.substring 3 2 hex))
    (lib.fromHexString (builtins.substring 5 2 hex))
  ];

  # the named palette the theme body references. accent = the wired plum-rose.
  colors = lib.mapAttrs (_: toRGB) {
    inherit (p)
      base
      mantle
      surface0
      surface1
      surface2
      overlay0
      text
      subtext0
      red
      green
      yellow
      blue
      peach
      teal
      lavender
      ;
    accent = p.mauve;
  };

  bnTheme = {
    name = "Wired Blood";
    style = "Fusion";
    inherit colors;

    # Qt widget chrome.
    palette = {
      Window = "base";
      WindowText = "text";
      Base = "base";
      AlternateBase = "mantle";
      ToolTipBase = "mantle";
      ToolTipText = "text";
      Text = "text";
      Button = "surface0";
      ButtonText = "text";
      BrightText = "accent";
      Link = "accent";
      Highlight = "accent";
      HighlightedText = "base";
      Light = "surface2";
    };

    # disassembly / decompiler / graph roles. brightness carries hierarchy, the accent
    # marks addresses + keywords + the active token, red is the lone alarm.
    theme-colors = {
      addressColor = "accent";
      modifiedColor = "red";
      insertedColor = "green";
      notPresentColor = "overlay0";
      selectionColor = "surface1";
      outlineColor = "accent";
      backgroundHighlightDarkColor = "base";
      backgroundHighlightLightColor = "surface0";
      boldBackgroundHighlightDarkColor = "surface1";
      boldBackgroundHighlightLightColor = "surface2";
      alphanumericHighlightColor = "blue";
      printableHighlightColor = "yellow";
      graphBackgroundDarkColor = "mantle";
      graphBackgroundLightColor = "base";
      graphNodeDarkColor = "surface0";
      graphNodeLightColor = "surface0";
      graphNodeOutlineColor = "surface2";
      trueBranchColor = "green";
      falseBranchColor = "red";
      unconditionalBranchColor = "accent";
      altTrueBranchColor = "teal";
      altFalseBranchColor = "peach";
      altUnconditionalBranchColor = "blue";
      registerColor = "accent";
      numberColor = "yellow";
      codeSymbolColor = "blue";
      dataSymbolColor = "lavender";
      stackVariableColor = "subtext0";
      importColor = "green";
      instructionHighlightColor = "surface1";
      tokenHighlightColor = "accent";
      annotationColor = "subtext0";
      opcodeColor = "overlay0";
      linearDisassemblyFunctionHeaderColor = "mantle";
      linearDisassemblyBlockColor = "base";
      linearDisassemblyNoteColor = "surface0";
      linearDisassemblySeparatorColor = "surface1";
      stringColor = "yellow";
      typeNameColor = "teal";
      fieldNameColor = "blue";
      keywordColor = "accent";
      uncertainColor = "peach";
      scriptConsoleOutputColor = "text";
      scriptConsoleErrorColor = "red";
      scriptConsoleEchoColor = "accent";
      blueStandardHighlightColor = "blue";
      greenStandardHighlightColor = "green";
      cyanStandardHighlightColor = "teal";
      redStandardHighlightColor = "red";
      magentaStandardHighlightColor = "accent";
      yellowStandardHighlightColor = "yellow";
      orangeStandardHighlightColor = "peach";
      whiteStandardHighlightColor = "text";
      blackStandardHighlightColor = "base";
    };
  };

  # BN's prebuilt ELFs need an FHS loader (steam-run, from programs.steam). its
  # python-plugin deps come from nix on PYTHONPATH, NOT BN's bundled pip (which
  # cannot install on NixOS). extend this withPackages list as plugins need more;
  # pypresence is for the Discord Rich Presence plugin. pure-python deps work across
  # BN's embedded python version; a compiled dep would need to match it. lazy: the
  # env is only forced on linux (where bnLauncher is used).
  bnPython = pkgs.python3.withPackages (ps: with ps; [ pypresence ]);
  bnLauncher = pkgs.writeShellScriptBin "binaryninja" ''
    export PYTHONPATH="${bnPython}/${pkgs.python3.sitePackages}''${PYTHONPATH:+:$PYTHONPATH}"
    exec steam-run ${config.home.homeDirectory}/binaryninja/binaryninja "$@"
  '';

  # psifertex's Discord Rich Presence plugin (BN founder). it just `import
  # pypresence`s, which the launcher puts on PYTHONPATH, so no BN pip / venv needed.
  discordPlugin = pkgs.fetchFromGitHub {
    owner = "psifertex";
    repo = "discordpresence";
    rev = "35a5aefed0a0fba637ae36a9eebd3e771eb71277";
    hash = "sha256-XG7PsJMR+TQqYn8u5KsYsgUiC1NRPplh3mmB1kYpcRU=";
  };
in
{
  home.file = {
    "${bnDir}/themes/Wired Blood.bntheme".text = builtins.toJSON bnTheme;

    # the MCP server half: the in-BN plugin (fosdickio) runs an HTTP server on :9009.
    # it's stdlib-only (deps: None), so symlinking the fetched source straight into the
    # plugins dir is enough, no pip into BN's python. the Claude-side bridge is the
    # binja-mcp package (pkgs/binja-mcp). reusing .src here keeps a single pinned rev.
    # after a switch: reload BN plugins (or restart BN), then Plugins > MCP Server >
    # Start Server. register the client once: `claude mcp add binja -- binja-mcp`.
    "${bnDir}/plugins/binary_ninja_mcp".source = pkgs.binja-mcp.src;
  }
  // lib.optionalAttrs pkgs.stdenv.hostPlatform.isLinux {
    # Discord Rich Presence: linux-only, pypresence is provided by the launcher's
    # PYTHONPATH here (a darwin BN would need pypresence via its own python).
    "${bnDir}/plugins/discordpresence".source = discordPlugin;
  };

  # linux: put the steam-run + PYTHONPATH launcher on PATH as `binaryninja` (CLI),
  # and give BN a .desktop so it shows in fuzzel (the manual extract ships neither).
  # both linux-only; darwin uses the .app bundle.
  home.packages = lib.optional pkgs.stdenv.hostPlatform.isLinux bnLauncher;

  xdg.desktopEntries = lib.mkIf pkgs.stdenv.hostPlatform.isLinux {
    binaryninja = {
      name = "Binary Ninja";
      genericName = "Reverse engineering platform";
      exec = "${bnLauncher}/bin/binaryninja %F";
      icon = "${config.home.homeDirectory}/binaryninja/api-docs/cpp/logo.png";
      categories = [
        "Development"
        "Utility"
      ];
      terminal = false;
    };
  };
}
