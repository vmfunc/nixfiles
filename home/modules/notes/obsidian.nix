# obsidian: the vault spine (rice.notes.*). the vault is a PLAIN FOLDER of
# markdown at rice.notes.vault, so every tool in the stack meets it on disk:
# obsidian (gui + ios), obsidian.nvim (editor/neovim.nix), xournal++/rnote ink
# (notes/xournalpp.nix), the ~/.plan mirror (notes/plan-mirror.nix) and the ocr
# sidecars (notes/ink-ocr.nix). cross-device sync is Obsidian Sync (e2e), which
# also carries the attachments and .obsidian settings, so the vault is NOT
# nix-managed content, only scaffolded once.
# TODO(deploy): per box, one-time in the gui: sign into Obsidian Sync, connect
# the remote vault, and turn on the community plugins (excalidraw) under
# settings -> community plugins (restricted mode off).
# linux-only package for now; the macs get obsidian via homebrew when the
# darwin half is wired (their profile does not import this module yet).
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
  options.rice.notes = {
    enable = lib.mkEnableOption "obsidian vault spine";
    vault = lib.mkOption {
      type = lib.types.str;
      default = "${config.home.homeDirectory}/vault";
      description = "absolute path of the obsidian vault (a plain markdown tree)";
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = lib.optionals pkgs.stdenv.hostPlatform.isLinux [ pkgs.obsidian ];

    # the tree must exist before first launch of obsidian/nvim; content is owned
    # by obsidian sync + the one-time scaffold, so only ever mkdir, never write.
    home.activation.notesVault = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      run mkdir -p ${lib.escapeShellArg cfg.vault}
    '';
  };
}
