# xournal++: the pdf-annotation half of the ink stack (the arxiv workflow).
# save convention: annotated pdfs + their .xopp sources live in <vault>/papers,
# long-form ink in <vault>/ink, so obsidian sync carries both everywhere and
# obsidian/ios render the pdfs natively. config is deliberately NOT declared:
# xournal++ rewrites settings.xml on every exit, so a home.file there would
# fight the app forever. TODO(deploy): in-app, once: set the default save
# folder to <vault>/papers and the stylus as input device.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.rice.notes;
in
{
  config = lib.mkIf cfg.enable {
    home.packages = [ pkgs.xournalpp ];

    home.activation.notesInkDirs = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      run mkdir -p ${lib.escapeShellArg cfg.vault}/papers ${lib.escapeShellArg cfg.vault}/ink
    '';
  };
}
