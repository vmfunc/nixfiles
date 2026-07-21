;;; init.el -*- lexical-binding: t; -*-
;; doom module selection for quaver's terminal-first emacs. built from source by
;; nix-doom-emacs-unstraightened against the emacs 31 pretest (see the module's
;; header for the version gate: doom does NOT support emacs 32 master yet).
;;
;; every module here was vetted for TTY viability: this emacs lives in `emacsclient
;; -t` inside wezterm, so GUI-only modules (pdf, ligatures, smooth-scroll, zen's
;; mixed-pitch, +childframe flags) are deliberately absent. the wins that used to be
;; GUI-only (corfu/posframe popups) now work in the terminal via emacs 31 tty child
;; frames, so we get them for free without the shims.

(doom! :completion
       (corfu +orderless +icons +dabbrev)  ; the 2026 doom default; company is gone
       (vertico +icons)

       :ui
       doom
       dashboard                     ; ascii banner path is the tty path
       (emoji +unicode)
       hl-todo
       indent-guides                 ; now jdtsmith/indent-bars (char fallback in tty)
       modeline
       ophints
       (popup +defaults)
       treemacs                      ; the C-b vscode explorer target
       (vc-gutter +pretty)           ; margin fallback wired in config for tty
       window-select
       workspaces

       :editor
       (evil +everywhere)
       file-templates
       fold
       (format +onsave)              ; apheleia
       multiple-cursors              ; evil-multiedit on M-d (not C-d, that is scroll)
       snippets
       word-wrap

       :emacs
       (dired +dirvish +icons)
       electric
       (ibuffer +icons)
       tramp
       undo                          ; undo-fu + undo-fu-session + vundo
       vc

       :term
       vterm                         ; nix-prebuilt module; claude-code-ide backend

       :checkers
       (syntax +flymake +icons)      ; flymake pairs cleanest with eglot, popon in tty

       :tools
       debugger                      ; dape (gdb>=14 speaks DAP natively, tty-clean)
       direnv
       editorconfig
       (eval +overlay)
       llm                           ; gptel, wired to claude in config.el (+ macher)
       lookup
       (lsp +eglot +booster)         ; eglot + emacs-lsp-booster, no lsp-ui childframes
       (magit +forge)
       make
       tree-sitter                   ; built-in treesit; grammars injected via nix

       :os
       (:if (featurep :system 'macos) macos)
       (tty +osc)                    ; kkp + evil-terminal-cursor-changer + clipetty

       :lang
       (cc +lsp +tree-sitter)
       data
       emacs-lisp
       (go +lsp +tree-sitter)
       (json +lsp +tree-sitter)
       (lua +lsp +tree-sitter)
       markdown
       (nix +lsp +tree-sitter)
       (org +pretty)
       (python +lsp +tree-sitter)
       (rust +lsp +tree-sitter)
       (sh +lsp +tree-sitter +fish)
       (yaml +lsp +tree-sitter)
       (zig +lsp +tree-sitter)

       :config
       (default +bindings +smartparens))
