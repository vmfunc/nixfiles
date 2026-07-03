# Binary Ninja: the licensed disassembler/decompiler, themed to the wired variant.
#
# the APP itself is NOT managed by nix. homebrew only ships binary-ninja-free (a separate
# binary with no license entry), and the COMMERCIAL build is a manual download from her
# account, so it lives in /Applications by hand (CLAUDE.md rule 12, doubly).
# TODO(deploy): install the commercial Binary Ninja from binary.ninja (login > download),
# drop it in /Applications; uninstall the free cask if present (`brew uninstall --cask
# binary-ninja-free`) so the two .apps don't collide.
# this module owns ONLY the colorscheme: a generated .bntheme dropped where BN scans for
# user themes (~/Library/Application Support/Binary Ninja/themes/), selectable in
# Preferences > Theme as "Wired Blood".
#
# cross-file deps: theme.nix (palette spine). every color is derived from theme.palette
# and re-rendered to RGB at build time, so a variant swap (blood/copland/macchiato) moves
# the BN theme with everything else, no hardcoded hex.
{
  lib,
  pkgs,
  theme,
  ...
}:
let
  p = theme.palette;

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
in
{
  home.file = {
    "Library/Application Support/Binary Ninja/themes/Wired Blood.bntheme".text =
      builtins.toJSON bnTheme;

    # the MCP server half: the in-BN plugin (fosdickio) runs an HTTP server on :9009.
    # it's stdlib-only (deps: None), so symlinking the fetched source straight into the
    # plugins dir is enough, no pip into BN's python. the Claude-side bridge is the
    # binja-mcp package (pkgs/binja-mcp). reusing .src here keeps a single pinned rev.
    # after a switch: reload BN plugins (or restart BN), then Plugins > MCP Server >
    # Start Server. register the client once: `claude mcp add binja -- binja-mcp`.
    "Library/Application Support/Binary Ninja/plugins/binary_ninja_mcp".source = pkgs.binja-mcp.src;
  };
}
