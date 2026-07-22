;; -*- no-byte-compile: t; -*-
;; extra packages beyond the enabled doom modules. built from source by nix like
;; everything else. doom's modules already ship evil, corfu, vertico, consult,
;; embark, magit, treemacs, vterm, dirvish, dape, eglot, apheleia, doom-modeline,
;; hl-todo, indent-bars, undo-fu/vundo, gptel, and the nerd-icons-{completion,corfu,
;; dired} that the +icons flags pull in; do NOT re-declare those or the pins fight.
;;
;; github :recipe entries that are NOT on melpa/emacs-overlay MUST carry a :pin so
;; unstraightened can fetch them deterministically (it errors otherwise). bump the
;; rev by hand; deps still resolve from melpa/overlay so no IFD header-scan fires.

;; --- claude code: the ide-grade mcp bridge, not a terminal wrapper ---
;; registers emacs as claude code's IDE: buffer selections, ediff review of proposed
;; edits, flymake diagnostics, and emacs tools (xref/imenu/treesit) exposed over mcp.
;; most active of the three claude packages; the runners-up (claude-code.el, agent-
;; shell) stalled or lack the mcp bridge. vterm backend, all tty-native.
(package! claude-code-ide
  :recipe (:host github :repo "manzaltu/claude-code-ide.el")
  :pin "1de17bbadc650962a05fd68463fdff71697ec649")
;; gptel-native patch-review companion (multi-file edits reviewed as diffs)
(package! macher
  :recipe (:host github :repo "kmontag/macher")
  :pin "b6e51cb9a01c87e36d8920d947ed171bf21c8287")

;; --- discord rich presence through vesktop's arRPC socket ---
(package! elcord)

;; --- terminal / clipboard ---
(package! xclip)      ; wl-clipboard both directions locally; clipetty(+osc) over ssh
(package! mistty)     ; the shell-in-a-buffer that finally does evil motions right

;; --- rice, all verified tty-viable in a truecolor terminal ---
(package! pulsar)          ; line/region pulse on jump; explicit tty pulse support
(package! colorful-mode)   ; hex/color swatches inline (rainbow-mode successor)
(package! breadcrumb)      ; imenu/project path in the header-line, lsp-free
(package! keycast)         ; live key echo, for learning the new chord layer
(package! dimmer)          ; dim unfocused windows (fg-blend, tty-safe)
(package! olivetti)        ; centered prose via margins (tty-safe, unlike zen)
(package! zoom)            ; auto golden-ratio window sizing (golden-ratio successor)
(package! page-break-lines); render ^L as a rule
(package! org-modern)      ; org glyphs/bullets (label :box pills off for tty parity)

;; --- navigation / editing ---
(package! symbol-overlay)  ; sticky multi-symbol highlights for reading code paths
(package! move-text)       ; vscode alt-up/down line move
(package! expreg)          ; treesit-native expand-region
(package! vundo)           ; visual undo tree in box-drawing chars
(package! casual)          ; transient menus over dired/ibuffer/calc/info
(package! combobulate                                             ; ts structural editing
  :recipe (:host github :repo "mickeynp/combobulate")
  :pin "171abd0034285499d1be42c6e7945a34fbb2d641")

;; --- git ---
(package! difftastic)      ; structural (AST) diffs inside magit
(package! magit-todos)     ; TODO(deploy)/FIXME markers in the magit status buffer
(package! browse-at-remote); yank/open the forge web permalink for the line at point

;; --- checkers ---
(package! jinx)            ; jit spell-check via libenchant, visible-region only

;; --- RE / security workbench ---
(package! nhexl-mode)      ; hexl replacement that keeps undo/isearch/major-mode
(package! disaster)        ; objdump of the function at point (C/C++, RE sanity checks)
(package! nasm-mode)       ; there is no :lang asm doom module
(package! verb)            ; org-based http workbench for bounty/VDP request notebooks

;; --- whitespace hygiene ---
;; trims trailing whitespace ONLY on lines you actually touched, so a save never
;; produces a diff on untouched lines. matters on a world-readable mirror where a
;; whitespace-only churn commit is noise. doom does not ship this.
(package! ws-butler)

;; --- asm reference lookup (RE) ---
;; x86-lookup jumps a mnemonic straight to its page in the Intel SDM vol.2 PDF.
;; aarch64 (azzie's real target surface) has no melpa equivalent, so that half is
;; a hand-rolled browse-url companion in config.el (ARM DDI0602 A64 ISA reference).
(package! x86-lookup)

;; --- MCP client: drive the RE servers from gptel-in-emacs ---
;; lets gptel CALL the binja/r2/frida/ghidra MCP servers (the other direction from
;; claude-code-ide, which exposes emacs TO claude). gptel's own gptel-integrations
;; consumes this; server list + connect helper live in config.el section 17. melpa.
(package! mcp)

;; --- notes silo, separate from the .plan finger file ---
;; timestamped denote notes so quick capture + a daily journal do not fight the
;; kanban/.plan (which stays intent-only). tty-perfect, no org-agenda baggage.
(package! denote)

;; --- compiler explorer (RE / exploit codegen) ---
;; beardbolt: godbolt inside emacs. source in one pane, generated asm in the other,
;; live source<->asm line highlight. the fast rmsbolt fork; NOT on melpa, so pinned.
;; needs a compiler on the daemon exec-path (gcc, added in default.nix). bump rev by
;; hand; deps (rmsbolt-free) resolve fine so no IFD header-scan fires.
(package! beardbolt
  :recipe (:host github :repo "joaotavora/beardbolt")
  :pin "828fbddeb3145139f9d7eca4336f7c970a331d9d")

;; --- dired-driven shell (RE workflow glue) ---
;; template a shell command over the marked dired files: `strings`/`file`/`objdump`
;; over a folder of binaries in one keystroke, with the marks spliced into <<f>>.
(package! dwim-shell-command)

;; --- reading (native, tty-viable) ---
;; nov = EPUB reader in a buffer; started from the shell via the `novel` nushell def.
(package! nov)

;; --- feeds / dictation ---
(package! elfeed)          ; infosec feed triage (project-zero, oss-security, ...)
;; local dictation via the whisper.cpp azzie already runs on tuna (jptv); no self-install
(package! whisper
  :recipe (:host github :repo "natrys/whisper.el")
  :pin "d09b23d999ee120e98adf50fa809f8b8a5c165e6")
