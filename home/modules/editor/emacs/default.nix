# riced doom emacs, built entirely from source by nix-doom-emacs-unstraightened.
# cross-file deps:
#   - flake.nix: emacs-overlay + nix-doom-emacs-unstraightened inputs (+ the version
#     gate WHY: we pin emacs-unstable = the 31 pretest, NOT emacs-git = 32 master,
#     because doom's module library tops out at 31-era features and its core README
#     warns against .50 builds).
#   - overlays/default.nix: threads emacs-overlay's package set onto every host's pkgs.
#   - ./doom/{init,packages,config}.el: the DOOMDIR. read-only in the store by design.
#   - theme.nix: the palette; themes/doom-wired-theme.el is GENERATED from it below so
#     blood/copland/macchiato all recolor emacs from the one source.
#
# TUNA-ONLY on purpose, do NOT lift this into profiles/base.nix. unstraightened uses
# import-from-derivation (it runs the configured emacs to export doom's pin list),
# so evaluating a host's drvPath realises that emacs build. on the two darwin macs
# that IFD is a darwin build, which the linux CI runner in eval.yml cannot realise:
# it would fail their drvPath eval (hard rule #3) and turn CI red. tuna is
# x86_64-linux, so its IFD is at least native. TODO(deploy): the forgejo eval.yml
# still builds emacs from source during tuna's drvPath eval (~20-30 min/push); if
# that outgrows the runner, move tuna's emacs eval off the per-push hot path.
{
  config,
  lib,
  pkgs,
  inputs,
  theme,
  ...
}:
let
  cfg = config.programs.doom-emacs;
  p = theme.palette;

  # def-doom-theme wants ~40 named slots as (truecolor 256 tty16) triples; on a
  # truecolor terminal (wezterm + emacs 31) column 1 is used, so blood/copland just
  # work in -nw. the tty16 column is the graceful fallback for a 16-color terminal.
  # the catppuccin slot names map 1:1 onto doom's required universal syntax classes.
  themeFile = pkgs.writeText "doom-wired-theme.el" ''
    ;;; doom-wired-theme.el --- generated from nix theme.nix -*- lexical-binding: t; no-byte-compile: t; -*-
    ;; DO NOT EDIT: regenerated on every rebuild from theme.palette (variant ${theme.variant}).
    (require 'doom-themes)
    (def-doom-theme doom-wired
      "Wired (${theme.variant}) variant, generated from nix."
      ;; (name '(truecolor 256color tty16)); a truecolor tty uses column 1.
      ((bg         '("${p.base}"     "${p.base}"     "black"))
       (bg-alt     '("${p.mantle}"   "${p.mantle}"   "black"))
       (base0      '("${p.crust}"    "${p.crust}"    "black"))
       (base1      '("${p.mantle}"   "${p.mantle}"   "brightblack"))
       (base2      '("${p.surface0}" "${p.surface0}" "brightblack"))
       (base3      '("${p.surface1}" "${p.surface1}" "brightblack"))
       (base4      '("${p.surface2}" "${p.surface2}" "brightblack"))
       (base5      '("${p.overlay0}" "${p.overlay0}" "brightblack"))
       (base6      '("${p.overlay1}" "${p.overlay1}" "brightblack"))
       (base7      '("${p.overlay2}" "${p.overlay2}" "white"))
       (base8      '("${p.subtext0}" "${p.subtext0}" "white"))
       (fg         '("${p.text}"     "${p.text}"     "brightwhite"))
       (fg-alt     '("${p.subtext1}" "${p.subtext1}" "white"))

       (grey       base5)
       (red        '("${p.red}"       "${p.red}"       "red"))
       (orange     '("${p.peach}"     "${p.peach}"     "brightred"))
       (green      '("${p.green}"     "${p.green}"     "green"))
       (teal       '("${p.teal}"      "${p.teal}"      "brightgreen"))
       (yellow     '("${p.yellow}"    "${p.yellow}"    "yellow"))
       (blue       '("${p.blue}"      "${p.blue}"      "brightblue"))
       (dark-blue  '("${p.sapphire}"  "${p.sapphire}"  "blue"))
       (magenta    '("${p.pink}"      "${p.pink}"      "brightmagenta"))
       (violet     '("${p.mauve}"     "${p.mauve}"     "magenta"))
       (cyan       '("${p.sky}"       "${p.sky}"       "brightcyan"))
       (dark-cyan  '("${p.teal}"      "${p.teal}"      "cyan"))

       ;; universal syntax classes: ALL required or doom-themes-base errors out.
       (highlight      violet)
       (vertical-bar   base0)
       (selection      base3)
       (builtin        '("${p.lavender}"  "${p.lavender}"  "magenta"))
       (comments       base6)
       (doc-comments   base7)
       (constants      '("${p.flamingo}"  "${p.flamingo}"  "red"))
       (functions      blue)
       (keywords       violet)
       (methods        cyan)
       (operators      '("${p.rosewater}" "${p.rosewater}" "white"))
       (type           yellow)
       (strings        green)
       (variables      fg)
       (numbers        '("${p.maroon}"    "${p.maroon}"    "red"))
       (region         base2)
       (error          red)
       (warning        yellow)
       (success        green)
       (vc-modified    orange)
       (vc-added       green)
       (vc-deleted     red))

      ;; face overrides: deltas only, doom-themes-base covers ~500 faces from the slots.
      (((line-number &override)          :foreground base4)
       ((line-number-current-line &override) :foreground violet :weight 'bold)
       (org-block                        :background bg-alt)
       (mode-line                        :background base2)
       (mode-line-inactive               :background bg-alt)))
  '';

  # the DOOMDIR: static config plus the generated theme. unstraightened wants a store
  # path here, so we assemble one (the config files stay read-only, edit + rebuild).
  doomDir = pkgs.runCommandLocal "doom-config" { } ''
    mkdir -p $out/themes
    cp ${./doom/init.el}         $out/init.el
    cp ${./doom/packages.el}     $out/packages.el
    cp ${./doom/config.el}       $out/config.el
    cp ${./doom/plan-kanban.el}  $out/plan-kanban.el
    cp ${themeFile}              $out/themes/doom-wired-theme.el
  '';

  # terminal emacs, lazy-starting a daemon on first use so every frame inherits the
  # calling wezterm shell's env (TERM=wezterm for undercurl, SSH_AUTH_SOCK, the lsp
  # servers on PATH). the GUI frame is deliberately never used; `e file` is the alias.
  emacsTerminal = pkgs.writeShellScriptBin "e" ''
    exec ${cfg.finalEmacsPackage}/bin/emacsclient -t -a "" "$@"
  '';
in
{
  imports = [ inputs.nix-doom-emacs-unstraightened.homeModule ];

  programs.doom-emacs = {
    enable = true;
    doomDir = "${doomDir}";
    # pgtk 31 pretest on linux; a pgtk daemon serves both a wayland gui frame (rare)
    # and the tty frames (daily). native-comp is on by default in the overlay build.
    emacs = pkgs.emacs-unstable-pgtk;
    # nix > 2.18 needs this for unstraightened's git fetches ('Cannot find Git revision')
    experimentalFetchTree = true;
    # treesit grammars are NOT auto-installed by unstraightened (its issue #82)
    extraPackages = epkgs: [ epkgs.treesit-grammars.with-all-grammars ];
    # doom's internal $PATH: search + the eglot servers/formatters/preview tools, all
    # from nix (no mason). scoped to emacs, so this never pollutes the system PATH.
    extraBinPackages = with pkgs; [
      git
      ripgrep
      fd
      # lsp servers (eglot), matching the neovim set
      nixd
      rust-analyzer
      gopls
      clang-tools
      basedpyright
      ruff
      lua-language-server
      bash-language-server
      yaml-language-server
      taplo
      zls
      asm-lsp
      vscode-langservers-extracted
      emacs-lsp-booster
      # formatters (apheleia / format-on-save)
      nixfmt
      stylua
      shfmt
      gofumpt
      rustfmt
      prettierd
      # dirvish previews + structural diff + wayland clipboard + spell backend
      difftastic
      wl-clipboard
      imagemagick
      poppler-utils
      ffmpegthumbnailer
      mediainfo
      enchant
      hunspellDicts.en_US
    ];
  };

  # the `e` wrapper doubles as the default editor: a real binary, so git/aerc/etc get
  # the terminal frame too, not just interactive shells. mkForce overrides the
  # nvim default that base.nix/core.nix set (tuna-only; the macs keep neovim).
  home.packages = [ emacsTerminal ];
  home.sessionVariables = {
    EDITOR = lib.mkForce "${emacsTerminal}/bin/e";
    VISUAL = lib.mkForce "${emacsTerminal}/bin/e";
  };

  # `emacs` at the interactive prompt is the raw pgtk binary, which opens a GUI
  # window. azzie wants terminal-only, so route the bare command to the `e` tty
  # wrapper too (the real binary is still reachable as `command emacs` / full path
  # for the rare GUI need). merges into the shared nushell aliases, tuna-only.
  programs.nushell.shellAliases.emacs = "e";

  # keep emacs off the niri/fuzzel app launcher: azzie wants it terminal-only. the
  # provideEmacs binaries ship emacs.desktop/emacsclient.desktop; shadow them hidden.
  xdg.desktopEntries = lib.mkIf pkgs.stdenv.hostPlatform.isLinux {
    emacs = {
      name = "Emacs";
      noDisplay = true;
      exec = "emacs %F";
    };
    emacsclient = {
      name = "Emacs (Client)";
      noDisplay = true;
      exec = "emacsclient %F";
    };
  };
}
