# rice.theme.*: readOnly mirror of the theme.nix specialArg so modules read
# config.rice.theme.colors instead of re-importing the raw attrset. also the ONLY
# file that flips catppuccin.enable (macchiato variant only; wired variants color by hand).
{
  lib,
  config,
  theme,
  ...
}:
let
  onMacchiato = config.rice.theme.variant == "macchiato";
in
{
  options.rice.theme = {
    variant = lib.mkOption {
      type = lib.types.enum [
        "macchiato"
        "copland"
        "blood"
      ];
      default = theme.variant;
      readOnly = true;
      description = "Active rice palette variant (from theme.nix). Flip it in theme.nix.";
    };
    flavor = lib.mkOption {
      type = lib.types.enum [
        "latte"
        "frappe"
        "macchiato"
        "mocha"
      ];
      default = theme.flavor;
      readOnly = true;
      description = "Catppuccin flavor (from theme.nix).";
    };
    accent = lib.mkOption {
      type = lib.types.str;
      default = theme.accent;
      readOnly = true;
      description = "Accent colour name, a key in `colors`.";
    };
    colors = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = theme.palette;
      readOnly = true;
      description = "Full #rrggbb palette, from theme.nix.";
    };
    accentHex = lib.mkOption {
      type = lib.types.str;
      default = theme.accentHex;
      readOnly = true;
      description = "The chosen accent as #rrggbb.";
    };
  };

  # catppuccin's native module can only emit ITS OWN flavor colors, not arbitrary hex, so it
  # drives the macchiato variant but goes OFF for wired (where bat/wezterm/neovim are colored
  # by hand from theme.palette/theme.ansi16). this is the whole variant gate.
  # autoEnable is pinned explicitly: upstream is moving port auto-enroll from `enable` (soon
  # a global kill switch) to `autoEnable`, and leaving it unset would flip macchiato behavior
  # with the upstream default (plus a warning at every eval until it is set).
  config.catppuccin = {
    enable = onMacchiato;
    autoEnable = onMacchiato;
    flavor = config.rice.theme.flavor;
    accent = config.rice.theme.accent;
  };
}
