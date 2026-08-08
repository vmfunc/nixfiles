# konsole: stock, except see-through.
#
# deliberately NOT riced. konsole is the plasma tablet session's terminal and
# azzie wants it to look like konsole; the lain rice lives in wezterm/ghostty.
# the ONE deviation is transparency, and konsole only exposes that through a
# colorscheme's Opacity key, so a colorscheme is the minimum this module can
# ship.
#
# rather than hand-write a palette (which would be "a theme" again), the stock
# Breeze scheme is extracted at BUILD time out of konsole's own library, where
# it lives as an uncompressed qt resource, and only Opacity/Blur are rewritten.
# so the colors track konsole's upstream instead of drifting from it, and a
# konsole update that changes Breeze is picked up on the next rebuild. if
# upstream ever compresses that resource the extraction fails LOUDLY at build
# time (the grep count check below) instead of silently shipping a half scheme.
#
# cross-file deps: modules/nixos/tablet.nix owns the plasma session this is for;
# desktop/kwin.nix ALSO sheers konsole's whole window (this alpha alone left
# the tab bar / titlebar solid), so the two layers stack: glyphs fade only to
# the kwin values, the background multiplies both and reads sheerer.
{
  lib,
  pkgs,
  ...
}:
let
  opacity = "0.85";

  konsolePkg = pkgs.kdePackages.konsole;

  # the stock scheme, minus its Opacity=1, plus ours. `strings` because the
  # resource is embedded in the shared library, not shipped as a file.
  breezeTransparent =
    pkgs.runCommand "konsole-breeze-transparent.colorscheme" { nativeBuildInputs = [ pkgs.binutils ]; }
      ''
        lib=$(echo ${konsolePkg}/lib/libkonsoleprivate.so.*)
        strings -n 3 "$lib" | awk '
          /^Description=Breeze$/ { found = NR }
          { line[NR] = $0 }
          END {
            for (i = found; i > 0; i--) if (line[i] == "[Background]") { s = i; break }
            for (i = found; i <= NR; i++) if (line[i] ~ /^Wallpaper=/) { e = i; break }
            for (i = s; i <= e; i++) print line[i]
          }' > scheme

        # a real Breeze scheme has 30+ sections; anything less means the
        # extraction drifted and the colors would be wrong.
        sections=$(grep -c '^\[' scheme)
        if [ "$sections" -lt 25 ]; then
          echo "konsole Breeze extraction found only $sections sections, upstream layout changed" >&2
          exit 1
        fi

        sed -e 's/^Opacity=.*/Opacity=${opacity}/' \
            -e 's/^Description=Breeze$/Description=Breeze Transparent/' scheme > "$out"
        # blur so the sheer reads as glass; kwin has the effect pinned on
        # (desktop/plasma.nix).
        echo 'Blur=true' >> "$out"
      '';
in
# linux-only insurance: imported solely from minnow today, but kdePackages is
# linux territory; a stray darwin import stays a no-op instead of an eval break.
lib.mkIf (!pkgs.stdenv.hostPlatform.isDarwin) {
  xdg.dataFile."konsole/breeze-transparent.colorscheme".source = breezeTransparent;

  # the profile exists ONLY to point at that scheme. no font, no shell override,
  # no margins, no scrollbar or cursor tweaks: everything konsole does not see
  # here it decides for itself, which is the point.
  xdg.dataFile."konsole/transparent.profile".text = lib.generators.toINI { } {
    General = {
      Name = "Transparent";
      Parent = "FALLBACK/";
    };
    Appearance.ColorScheme = "breeze-transparent";
  };

  # konsolerc must stay MUTABLE: konsole rewrites it at runtime (window state,
  # menu toggles), so a store symlink would be replaced on first run and then
  # backup-churned by every switch. kwriteconfig6 surgically pins just the
  # default-profile key and leaves the rest of the file to konsole.
  home.activation.konsoleDefaultProfile = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    run ${pkgs.kdePackages.kconfig}/bin/kwriteconfig6 --file konsolerc \
      --group "Desktop Entry" --key DefaultProfile transparent.profile
  '';
}
