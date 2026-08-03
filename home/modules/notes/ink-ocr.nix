# ink-ocr (rice.inkOcr.enable, default off; minnow only): handwriting exports
# in <vault>/ink get a searchable markdown sidecar (<name>.ocr.md), so obsidian
# search and grep reach into the ink. v1 is HONEST about its engine: tesseract,
# which is decent on neat print and weak on cursive; the sidecar carries its
# tool tag so a later TrOCR-class local model can re-run and overwrite. svg
# (rnote/excalidraw exports) is rasterised via resvg first; png is fed as-is.
# enabled on ONE box only on purpose: a single writer into the synced vault
# means two hosts never race near-identical sidecars through obsidian sync.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.rice.inkOcr;
  notes = config.rice.notes;

  ocrTick = pkgs.writeShellScript "ink-ocr-tick" ''
    set -eu
    ink=${lib.escapeShellArg notes.vault}/ink
    [ -d "$ink" ] || exit 0
    tmpdir=$(${pkgs.coreutils}/bin/mktemp -d)
    trap '${pkgs.coreutils}/bin/rm -rf "$tmpdir"' EXIT
    ${pkgs.findutils}/bin/find "$ink" -type f \( -name '*.svg' -o -name '*.png' \) -print0 |
      while IFS= read -r -d "" f; do
        side="''${f%.*}.ocr.md"
        # sidecar newer than the ink = already current, skip
        if [ -e "$side" ] && [ "$side" -nt "$f" ]; then continue; fi
        img="$f"
        case "$f" in
          *.svg)
            img="$tmpdir/page.png"
            ${pkgs.resvg}/bin/resvg "$f" "$img" || continue
            ;;
        esac
        text=$(${pkgs.tesseract}/bin/tesseract "$img" stdout 2>/dev/null || true)
        {
          printf -- '---\nsource: "%s"\ngenerated: %s\ntool: tesseract (ink-ocr v1)\n---\n\n' \
            "''${f##*/}" "$(${pkgs.coreutils}/bin/date -Iseconds)"
          printf '%s\n' "$text"
        } >"$side"
      done
  '';
in
{
  options.rice.inkOcr.enable = lib.mkEnableOption "ocr sidecars for ink exports in the vault";

  config = lib.mkIf cfg.enable {
    systemd.user.services.ink-ocr = {
      Unit.Description = "ocr new ink exports into searchable sidecars";
      Service = {
        Type = "oneshot";
        ExecStart = "${ocrTick}";
        # ocr is bursty cpu on a battery box; keep it polite
        Nice = 10;
      };
    };
    systemd.user.timers.ink-ocr = {
      Unit.Description = "hourly ink ocr sweep";
      Timer = {
        OnStartupSec = "5m";
        OnUnitActiveSec = "1h";
      };
      Install.WantedBy = [ "timers.target" ];
    };
  };
}
