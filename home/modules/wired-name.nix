# the wired identity: each host announces itself AS a Navi, not by its nix hostname.
# cosmetic only, the real nix hostnames (otter/coral) are NEVER renamed,
# this is the name the machine SHOWS (prompt / fastfetch / sketchybar host readout).
# cross-file deps: read via config.rice.wiredName by fastfetch.nix and nushell.nix;
# the full table is read via config.rice.wiredNames by nushell.nix's `wired` command.
# sketchybar/plugins/host.sh re-derives the SAME mapping in bash (it cannot read nix).
{
  lib,
  hostname,
  ...
}:
let
  # otter is the laptop you carry (the Navi), coral the desk machine (the layer it
  # lives in). tuna is the always-on Framework Desktop, the box that builds and
  # crunches, so it takes TACHIBANA: Tachibana General Laboratories, the lab/corp
  # behind Copland OS and the Navi hardware. unknown hosts fall back to the
  # uppercased real hostname so a new box still reads as itself, loudly.
  wiredNames = {
    otter = "NAVI";
    coral = "CYBERIA";
    tuna = "TACHIBANA";
  };
in
{
  options.rice.wiredName = lib.mkOption {
    type = lib.types.str;
    default = wiredNames.${hostname} or (lib.toUpper hostname);
    readOnly = true;
    description = "Cosmetic Navi name this host announces itself as (never the real nix hostname).";
  };

  options.rice.wiredNames = lib.mkOption {
    type = lib.types.attrsOf lib.types.str;
    default = wiredNames;
    readOnly = true;
    description = "The full hostname to Navi name table, for consumers that render every node.";
  };
}
