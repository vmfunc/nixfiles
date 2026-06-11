{
  lib,
  config,
  theme,
  ...
}:
{
  options.rice.theme = {
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
      description = "Accent colour name — a key in `colors`.";
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

  config.catppuccin = {
    enable = true;
    flavor = config.rice.theme.flavor;
    accent = config.rice.theme.accent;
  };
}
