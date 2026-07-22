# fuzzel launcher for the niri desktop (tuna), in the lain console register the rest
# of the set speaks: SQUARE corners with the 2px accent outline (the exact frame niri
# draws on windows and mako on notifications; the old radius-12 bubble was the one
# rounded panel in the rice and read pasted-in), sheer near-black base, no prompt
# glyph. the input line is a bare field with a dim placeholder, raycast-style, and
# the match counter sits on the right like waybar's FIELD:value meta. colors come
# from rice.theme.colors so a theme.nix variant swap recolors the launcher with the
# rest of the rice.
# cross-file deps: niri.nix binds Mod+Space / Ctrl+Space / Mod+D to `fuzzel` and drops
# the standalone package (this module installs it via programs.fuzzel.enable). theme.nix
# owns rice.theme.colors; the icon-theme name must match gtk.iconTheme in niri.nix
# (Papirus-Dark), same set mako feeds its notification icons from.
{ config, pkgs, ... }:
let
  c = config.rice.theme.colors;
  # fuzzel wants RRGGBBAA with no leading '#'. alpha "f2" is the same sheer the mako
  # panel uses, so the two surfaces read as one material over the wallpaper.
  rgba = alpha: hex: "${builtins.substring 1 6 hex}${alpha}";
in
{
  programs.fuzzel = {
    enable = true;
    settings = {
      main = {
        font = "JetBrainsMono Nerd Font:size=13";
        # no prompt glyph: the empty field + placeholder IS the prompt. the quoted
        # empty string survives ini serialization; fuzzel's default "> " returns
        # otherwise.
        prompt = ''""'';
        placeholder = "search the wired";
        # match desktop categories + keywords on top of the stock
        # filename,name,generic set, so "game" or "emulator" surfaces apps whose
        # name never says it. the flat-search half of the Mod+A category drawer
        # in niri.nix.
        fields = "filename,name,generic,categories,keywords";
        # desktop-file Actions= entries become their own launchable rows ("Zen -
        # Private Window", "Steam - Big Picture"), the closest native thing to
        # folders fuzzel has.
        show-actions = true;
        # dmenu overlays (power menu, app drawer, emoji) shrink to their actual
        # line count instead of floating five entries in a ten-line box. dmenu
        # mode only, the app list is unaffected.
        minimal-lines = true;
        # every launch lands in its own transient user scope: gui apps hang off
        # systemd instead of the compositor tree, `systemctl --user status` stays
        # readable, and one crashing app cannot drag siblings down. --collect
        # reaps failed scopes so they never pile up in --failed. the Mod+A drawer
        # in niri.nix wraps its gtk-launch the same way for parity.
        launch-prefix = "${pkgs.systemd}/bin/systemd-run --user --scope --collect --quiet --";
        # NN/NNN on the right edge of the input line, the console's meta readout.
        match-counter = true;
        icon-theme = "Papirus-Dark";
        icons-enabled = true;
        layer = "overlay";
        width = 44;
        lines = 10;
        horizontal-pad = 24;
        vertical-pad = 20;
        inner-pad = 12;
        line-height = 26;
        # icons sized well under the line box: markers, not tiles. full-bleed icons
        # next to mono text is the gnome-launcher look the rest of the set avoids.
        image-size-ratio = 0.7;
      };
      border = {
        width = 2;
        # square. niri went square + outline borders; radius here has to be 0 or
        # fuzzel breaks the frame language of the whole set.
        radius = 0;
      };
      # near-black sheer panel, soft-grey text. the accent only touches what matters:
      # the matched characters and the frame. the selection bar stays a quiet surface
      # slab so brightness, not hue, carries the hierarchy (the wired palette rule).
      colors = {
        background = rgba "f2" c.base;
        text = rgba "ff" c.text;
        input = rgba "ff" c.text;
        placeholder = rgba "ff" c.overlay2;
        match = rgba "ff" c.mauve;
        selection = rgba "ff" c.surface1;
        selection-text = rgba "ff" c.text;
        selection-match = rgba "ff" c.mauve;
        counter = rgba "ff" c.overlay2;
        border = rgba "ff" c.mauve;
      };
    };
  };
}
