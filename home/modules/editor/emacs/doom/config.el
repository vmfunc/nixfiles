;;; config.el -*- lexical-binding: t; -*-
;; quaver's doom config. terminal-first (emacsclient -t in wezterm), evil on, with a
;; vscode-familiar chord layer bolted over the top (mirrors the neovim module). read
;; alongside init.el (module choices) and packages.el (extra packages). this file is
;; a read-only nix store path by design: edit it here and rebuild, not in place.
;;
;; comment convention matches the repo: WHY not HOW, no em dashes.

(setq user-full-name "quaver"
      user-mail-address "vmfunc.lc@gmail.com")

;;; ────────────────────────────────────────────────────────────────────────────
;;; 1. theme + fonts
;; the theme is generated from nix's theme.palette into themes/doom-wired-theme.el,
;; so blood/copland/macchiato all recolor it from the one source. fonts only bite in
;; a GUI frame; in the terminal wezterm's CozetteVector/JetBrainsMono NF is the face.
(setq doom-theme 'doom-wired
      doom-font (font-spec :family "JetBrainsMono Nerd Font" :size 14)
      doom-variable-pitch-font (font-spec :family "JetBrainsMono Nerd Font")
      display-line-numbers-type 'relative)  ; relative like the nvim config

;;; ────────────────────────────────────────────────────────────────────────────
;;; 2. tty polish (emacs 31 pretest; these close the gap with a GUI frame)
(setq visible-cursor nil
      xterm-set-window-title t
      ;; 31+: drive the evil per-state cursor over DECSCUSR + OSC 12/112 natively,
      ;; so evil-terminal-cursor-changer (from :os tty) has less to do
      xterm-update-cursor t
      ;; 31+: several emacsclient -t frames on one daemon without the single-kboard
      ;; wedge (bug#75056); we lazy-start a daemon per login, many tty frames attach
      multiple-terminals-merge-keyboards t
      mouse-wheel-scroll-amount '(2 ((shift) . hscroll) ((control) . text-scale))
      mouse-wheel-progressive-speed nil     ; fixed-step wheel, the closest tty gets to smooth
      scroll-conservatively 101
      scroll-margin 2)
;; corfu/posframe pick tty child frames up by themselves on 31; just prettier borders
(when (and (featurep 'tty-child-frames)
           (fboundp 'standard-display-unicode-special-glyphs))
  (standard-display-unicode-special-glyphs))
;; force nerd-icon glyphs in the terminal (they come from wezterm's font, not images)
(after! doom-modeline
  (setq doom-modeline-icon t
        doom-modeline-major-mode-icon t
        doom-modeline-buffer-state-icon t
        doom-modeline-modal-icon t))

;; kkp (kitty keyboard protocol) is loaded by :os tty and is what makes C-S-p, C-.,
;; C-/ and friends distinguishable in the terminal (needs enable_kitty_keyboard in
;; wezterm). while active, C-g is an escape seq and cannot abort a blocking
;; subprocess, so restore legacy keys around them.
(after! kkp
  (setq kkp-restore-legacy-keys-around-subprocesses t))

;; vc-gutter uses the fringe, which is GUI-only; fall back to margin diffs in the tty
(after! diff-hl
  (unless (display-graphic-p)
    (diff-hl-margin-mode +1)))

;;; ────────────────────────────────────────────────────────────────────────────
;;; 3. clipboard: wl-clipboard both ways locally on wayland, OSC 52 write over ssh
;; wezterm cannot do OSC 52 *reads* (PR #6239 unmerged), so clipetty (copy-only) is
;; correct only for remote sessions; locally xclip.el drives wl-copy/wl-paste for a
;; real system-clipboard paste.
(add-hook! 'tty-setup-hook :append
  (defun +wired/tty-clipboard-h ()
    (if (getenv "SSH_TTY")
        (when (fboundp 'global-clipetty-mode) (global-clipetty-mode +1))
      (when (fboundp 'global-clipetty-mode) (global-clipetty-mode -1))
      (when (require 'xclip nil t)
        (with-demoted-errors "xclip: %s" (xclip-mode +1))))))

;;; ────────────────────────────────────────────────────────────────────────────
;;; 4. performance (gcmh is already doom core; tune the io-bound paths)
(setq read-process-output-max (* 4 1024 1024)  ; fatter lsp/vterm pipes
      jit-lock-defer-time 0)

;;; ────────────────────────────────────────────────────────────────────────────
;;; 5. eye candy, all tty-viable
;; pulsar replaces doom's nav-flash equivalent: pulse the line on jumps, tty-aware
(use-package! pulsar
  :hook (doom-first-input . pulsar-global-mode)
  :config
  (setq pulsar-face 'pulsar-magenta
        pulsar-region-face 'pulsar-cyan
        pulsar-delay 0.045
        pulsar-iterations 8
        pulsar-tty-color "magenta")   ; named color for pulses in a non-graphic frame
  (add-hook 'next-error-hook #'pulsar-pulse-line))

;; hex/named color swatches inline; a dot prefix reads cleanly in the terminal
(use-package! colorful-mode
  :hook ((prog-mode conf-mode text-mode) . colorful-mode)
  :config
  (setq colorful-use-prefix t
        colorful-only-strings 'only-prog))

;; imenu/project breadcrumbs in the header-line, lsp-agnostic (works under eglot)
(use-package! breadcrumb
  :hook ((prog-mode text-mode) . breadcrumb-local-mode)
  :config
  (setq breadcrumb-project-max-length 0.4
        breadcrumb-imenu-max-length 0.5))

;; live key echo, handy while the new chord layer is still muscle-memory
(use-package! keycast
  :commands (keycast-mode-line-mode keycast-tab-bar-mode keycast-log-mode))

;; dim the windows you are not in (foreground blend, renders in truecolor tty)
(use-package! dimmer
  :hook (doom-first-buffer . dimmer-mode)
  :config
  (setq dimmer-fraction 0.22
        dimmer-adjustment-mode :foreground)
  (dimmer-configure-which-key)
  (dimmer-configure-magit)
  (dimmer-configure-posframe))

;; centered prose via margins (tty-safe, unlike doom :ui zen's mixed-pitch)
(use-package! olivetti
  :commands olivetti-mode
  :init (setq-default olivetti-body-width 100)
  :config (setq olivetti-style nil))

;; auto golden-ratio window sizing; exempt popups and the tree
(use-package! zoom
  :hook (doom-first-input . zoom-mode)
  :config
  (setq zoom-size '(0.618 . 0.618)
        zoom-ignored-major-modes '(dired-mode vterm-mode treemacs-mode)
        zoom-ignored-buffer-name-regexps '("^\\*doom:" "^ \\*Treemacs" "^\\*claude")))

(use-package! page-break-lines
  :hook ((prog-mode text-mode) . page-break-lines-mode))

;; org glyphs only; keep the :box "pill" look off so gui and tty frames match
(use-package! org-modern
  :hook ((org-mode . org-modern-mode)
         (org-agenda-finalize . org-modern-agenda))
  :config
  (setq org-modern-star 'replace
        org-modern-replace-stars "◉◈◇✳"
        org-modern-label-border nil
        org-modern-block-fringe nil
        org-hide-emphasis-markers t
        org-pretty-entities t))

;; hl-todo (doom module): extend with the RE/security keywords, colored from the theme
(after! hl-todo
  (setq hl-todo-keyword-faces
        (append hl-todo-keyword-faces
                `(("SAFETY"   . ,(doom-color 'green))
                  ("AUDIT"    . ,(doom-color 'orange))
                  ("SECURITY" . ,(doom-color 'red))
                  ("PWN"      . ,(doom-color 'magenta))))))

;; a lain-flavored dashboard banner. setting both var names is safe: doom reads
;; whichever its version defines, the other is inert, and the fn cannot error.
(defun +wired/dashboard-banner ()
  (let ((lines '("     present day"
                 "     present time"
                 ""
                 "  close the world  ·  open the next")))
    (dolist (line lines)
      (insert (if (fboundp '+doom-dashboard--center)
                  (+doom-dashboard--center +doom-dashboard--width line)
                line)
              "\n"))))
(setq +doom-dashboard-ascii-banner-fn #'+wired/dashboard-banner
      +dashboard-ascii-banner-fn #'+wired/dashboard-banner)

;;; ────────────────────────────────────────────────────────────────────────────
;;; 6. vscode-familiar chord layer (mirrors home/modules/editor/neovim.nix)
;; each steal notes the evil/doom default it costs and where that moved. the C-S-*,
;; C-., C-/, C-` chords only arrive distinctly under kkp + wezterm; without it some
;; degrade (documented per line). the <leader> (SPC) mirrors doom already gives stay
;; as the terminal-agnostic safety net.
(map!
 :gnvi "C-s"   #'save-buffer                       ; shadows isearch; use / or SPC s s
 :gnvi "C-p"   #'projectile-find-file              ; :n loses evil-paste-pop; SPC i y
 :gnvi "C-S-p" #'execute-extended-command          ; M-x; kkp-only, else lands as C-p
 :gnvi "C-S-f" #'+default/search-project           ; overrides doom :n fullscreen bind
 :n    "C-b"   #'+treemacs/toggle                  ; loses evil-scroll-page-up; C-u covers it
 :gnvi "C-`"   #'+vterm/toggle                     ; doom default was +popup/toggle
 :nvi  "C-/"   #'evilnc-comment-or-uncomment-lines ; the gc operator still exists
 :nvi  "C-_"   #'evilnc-comment-or-uncomment-lines ; what C-/ sends without kkp
 :n    "C-w"   #'kill-current-buffer               ; loses evil-window-map; SPC w mirrors it
 :i    "C-w"   #'evil-delete-backward-word         ; keep vscode ctrl-backspace-word in insert
 :n    [f2]    #'eglot-rename                       ; +eglot is on; prompts for the new name
 :nvi  "C-."   #'eglot-code-actions                 ; vscode quick-fix
 :n    "H"     #'previous-buffer                   ; loses evil-window-top motion
 :n    "L"     #'next-buffer                       ; loses evil-window-bottom motion
 ;; vscode alt-up/down move line; M-arrows are free in evil normal
 :nvi  [M-up]   #'move-text-up
 :nvi  [M-down] #'move-text-down)

;; C-. is also flyspell-auto-correct-word if that ever loads; take the chord back
(after! flyspell
  (define-key flyspell-mode-map (kbd "C-.") nil))

;; mouse: ctrl+click to definition, steady wheel, right-click menu (all work in tty).
;; xterm-mouse-mode must be ARMED per tty frame: enabling it once in a frameless
;; daemon sets the flag but never sends the tracking escape to later emacsclient -t
;; frames, so wezterm keeps doing its own local selection instead of forwarding
;; clicks to emacs. re-run the enable on tty-setup (fires per frame) to arm each one.
(add-hook! 'tty-setup-hook :append
  (defun +wired/arm-mouse-h ()
    (when (bound-and-true-p xterm-mouse-mode) (xterm-mouse-mode -1))
    (xterm-mouse-mode 1)))
(unless (display-graphic-p) (xterm-mouse-mode 1))
(context-menu-mode 1)
(defun +wired/mouse-goto-def (ev)
  "Ctrl+click jumps to definition, vscode-style."
  (interactive "e")
  (mouse-set-point ev)
  (call-interactively #'+lookup/definition))
(map! [C-down-mouse-1] nil                          ; kill the default buffer-menu popup
      [C-mouse-1] #'+wired/mouse-goto-def)
(after! treemacs
  (define-key treemacs-mode-map [mouse-1] #'treemacs-single-click-expand-action))

;;; ────────────────────────────────────────────────────────────────────────────
;;; 7. editing power
(use-package! symbol-overlay
  :commands (symbol-overlay-put symbol-overlay-remove-all)
  :init
  (map! :n "g z" #'symbol-overlay-put
        :n "g Z" #'symbol-overlay-remove-all))

;; treesit-native expand-region, bound to v-in-visual for the vim feel
(use-package! expreg
  :commands (expreg-expand expreg-contract)
  :init (map! :v "v" #'expreg-expand
              :v "V" #'expreg-contract))

(use-package! vundo
  :commands vundo
  :init (map! :n "g U" #'vundo))

;; structured treesit editing (sibling swaps, node navigation) on the treesit langs
(use-package! combobulate
  :hook ((python-ts-mode js-ts-mode typescript-ts-mode tsx-ts-mode yaml-ts-mode
          json-ts-mode rust-ts-mode go-ts-mode) . combobulate-mode))

;; transient menus over built-ins; C-o inside dired/ibuffer/calc surfaces them.
;; each keymap is its OWN grouped (:after :map ...) block: doom's map! does not
;; accept flat repeated :after/:map, that fails eager macro-expansion and aborts
;; the whole config.el load, killing every section below it.
(use-package! casual
  :defer t
  :init
  (map! (:after dired :map dired-mode-map :n "C-o" #'casual-dired-tmenu)
        (:after ibuffer :map ibuffer-mode-map :n "C-o" #'casual-ibuffer-tmenu)
        (:after calc :map calc-mode-map :n "C-o" #'casual-calc-tmenu)))

;;; ────────────────────────────────────────────────────────────────────────────
;;; 8. lsp / eglot
;; doom's :tools (lsp +eglot +booster) wires eglot + emacs-lsp-booster. point the
;; python server at basedpyright (matches the neovim config), servers come from nix.
(after! eglot
  (add-to-list 'eglot-server-programs
               '((python-mode python-ts-mode) . ("basedpyright-langserver" "--stdio"))))

;;; ────────────────────────────────────────────────────────────────────────────
;;; 9. claude code: the ide bridge (SPC a ...)
(use-package! claude-code-ide
  :defer t
  :init
  (map! :leader
        (:prefix ("a" . "claude")
         :desc "menu"           "a" #'claude-code-ide-menu
         :desc "start session"  "c" #'claude-code-ide
         :desc "resume"         "r" #'claude-code-ide-resume
         :desc "continue"       "C" #'claude-code-ide-continue
         :desc "toggle window"  "t" #'claude-code-ide-toggle
         :desc "send prompt"    "p" #'claude-code-ide-send-prompt
         :desc "insert @-ref"   "s" #'claude-code-ide-insert-at-mentioned
         :desc "list sessions"  "l" #'claude-code-ide-list-sessions
         :desc "stop"           "q" #'claude-code-ide-stop))
  :config
  (setq claude-code-ide-terminal-backend 'vterm     ; nix-clean; 'eat if nesting flickers
        claude-code-ide-diagnostics-backend 'auto
        claude-code-ide-window-side 'right
        claude-code-ide-window-width 100)
  (claude-code-ide-emacs-tools-setup)               ; expose xref/imenu/treesit over mcp
  (set-popup-rule! "^\\*claude-code" :ignore t))     ; the package owns its side window

;; gptel-native patch review (multi-file edits shown as diffs before applying)
(use-package! macher
  :after gptel
  :config (macher-install))

;;; ────────────────────────────────────────────────────────────────────────────
;;; 10. gptel (doom :tools llm) pointed at claude, key from auth-source, non-fatal
(after! gptel
  (setq gptel-default-mode 'org-mode)
  (ignore-errors
    (setq gptel-backend (gptel-make-anthropic "Claude"
                          :stream t
                          :key (lambda ()
                                 (or (getenv "ANTHROPIC_API_KEY")
                                     (auth-source-pick-first-password
                                      :host "api.anthropic.com"))))
          gptel-model 'claude-sonnet-4-5)))

;;; ────────────────────────────────────────────────────────────────────────────
;;; 11. discord rich presence via vesktop's arRPC socket
;; elcord finds arRPC's $XDG_RUNTIME_DIR/discord-ipc-0 with no config. two client
;; toggles are required once: Vesktop -> "Rich Presence via arRPC", and Discord ->
;; Activity Privacy -> "Share your detected activities". redact sensitive project
;; names; stay quiet when vesktop is down; drop presence when the last frame closes.
(after! elcord
  (setq elcord-quiet t
        elcord-refresh-rate 5
        elcord-idle-timer 600
        elcord-idle-message "afk"
        elcord-editor-icon "doom_icon"
        elcord-use-major-mode-as-main-icon t
        elcord-display-line-numbers nil)
  (defvar +elcord-private-dirs '("~/pentest" "~/cases")
    "Trees whose file names must never reach discord.")
  (defun +elcord-details ()
    (let ((f (buffer-file-name (buffer-base-buffer))))
      (if (and f (cl-some (lambda (d) (file-in-directory-p f (expand-file-name d)))
                          +elcord-private-dirs))
          "Editing [redacted]"
        (format "Editing %s" (buffer-name)))))
  (setq elcord-buffer-details-format-function #'+elcord-details)
  ;; upstream #98: idle timer firing while disconnected calls (cancel-timer nil)
  (defadvice! +elcord-idle-guard-a (fn &rest args)
    :around #'elcord--start-idle
    (when (bound-and-true-p elcord--update-presence-timer) (apply fn args))))

;; start it once a real frame exists (daemon-safe), and drop it when the last tty
;; client detaches so the daemon does not keep advertising to an empty room.
(defun +elcord-maybe-start ()
  (unless (or (getenv "SSH_CONNECTION") (bound-and-true-p elcord-mode))
    (elcord-mode +1)))
(if (daemonp)
    (progn
      (add-hook 'server-after-make-frame-hook #'+elcord-maybe-start)
      (add-hook! 'delete-frame-functions
        (defun +elcord-frame-deleted-h (f)
          (when (let ((rest (delq f (visible-frame-list))))
                  (or (null rest)
                      (and (null (cdr rest)) (eq (car rest) terminal-frame))))
            (when (bound-and-true-p elcord-mode) (elcord-mode -1))))))
  (add-hook 'doom-first-input-hook #'+elcord-maybe-start))

;;; ────────────────────────────────────────────────────────────────────────────
;;; 12. git power
(use-package! difftastic
  :after magit
  :config (difftastic-bindings-mode))
(use-package! magit-todos
  :after magit
  :config (magit-todos-mode 1))

;;; ────────────────────────────────────────────────────────────────────────────
;;; 13. RE / security workbench
(use-package! nhexl-mode :commands nhexl-mode)
(use-package! disaster
  :commands disaster
  :init (map! :map (c-mode-map c++-mode-map c-ts-mode-map c++-ts-mode-map)
              :n "C-c d" #'disaster))
;; nasm/asm for exploit work (no :lang asm doom module exists)
(use-package! nasm-mode
  :mode ("\\.\\(asm\\|nasm\\|s\\)\\'" . nasm-mode))
(use-package! verb
  :after org
  :config (define-key org-mode-map (kbd "C-c C-r") verb-command-map))

;;; ────────────────────────────────────────────────────────────────────────────
;;; 14. spell, feeds, dictation, shell
(use-package! jinx
  :hook ((text-mode conf-mode) . jinx-mode)
  :init (map! :desc "correct spelling" "M-$" #'jinx-correct))

(use-package! elfeed
  :commands elfeed
  :config
  (setq elfeed-feeds
        '("https://googleprojectzero.blogspot.com/feeds/posts/default"
          "https://www.openwall.com/lists/oss-security/rss/rss.xml")))

;; local dictation via the whisper.cpp azzie already runs on tuna; never self-install
(use-package! whisper
  :commands (whisper-run whisper-file)
  :config
  (setq whisper-install-whispercpp nil
        whisper-model "base.en"
        whisper-language "en"))

;; the shell-in-a-buffer for daily driving (evil motions over scrollback, TUIs work)
(use-package! mistty
  :commands (mistty mistty-in-project)
  :init (map! :leader :desc "mistty (shell buffer)" "o s" #'mistty-in-project))

;;; ────────────────────────────────────────────────────────────────────────────
;;; 15. plan kanban: an interactive board over ~/.plan (see plan-kanban.el)
(load! "plan-kanban")
(map! :leader :desc "plan kanban" "o k" #'plan-kanban)

;;; ────────────────────────────────────────────────────────────────────────────
;;; 16. cheat sheet (SPC o h): the keys that matter, kanban first
(defun +wired/cheatsheet ()
  "Pop a quick keybinding cheat sheet (kanban + the vscode chord layer)."
  (interactive)
  (with-current-buffer (get-buffer-create "*cheatsheet*")
    (let ((inhibit-read-only t)
          (hd (lambda (s) (concat "\n" (propertize s 'face `(:foreground ,(doom-color 'violet) :weight bold)) "\n")))
          (row (lambda (k d)
                 (concat "  " (propertize (format "%-15s" k) 'face `(:foreground ,(doom-color 'blue))) d "\n"))))
      (erase-buffer)
      (insert (propertize "  wired keys  ·  q to close\n" 'face 'shadow))
      (insert (funcall hd "kanban  ·  SPC o k"))
      (insert (funcall row "h  l" "move cursor between lanes"))
      (insert (funcall row "j  k" "move cursor within a lane"))
      (insert (funcall row "H  L" "move the CARD to prev / next lane"))
      (insert (funcall row "1 2 3 4" "move card to doing / next / someday / done"))
      (insert (funcall row "x" "complete card (send to done)"))
      (insert (funcall row "a  ·  C-u a" "add card  ·  add as %hidden"))
      (insert (funcall row "e / RET  D" "edit card text  ·  delete card"))
      (insert (funcall row "s  p" "plan sync  ·  plan push"))
      (insert (funcall row "g  E  q" "reload  ·  open raw ~/.plan  ·  quit"))
      (insert (funcall row "mouse" "click select · drag between lanes · right-click menu"))
      (insert (funcall hd "editor  ·  the vscode chords"))
      (insert (funcall row "C-s  C-p" "save  ·  find file in project"))
      (insert (funcall row "C-S-p  C-S-f" "command palette (M-x)  ·  grep project"))
      (insert (funcall row "C-b  C-/  C-`" "file tree  ·  comment  ·  terminal"))
      (insert (funcall row "F2  C-." "rename symbol  ·  code action"))
      (insert (funcall row "gd  gr  K" "goto def  ·  references  ·  hover docs"))
      (insert (funcall row "S-h S-l  C-w" "prev / next buffer  ·  close buffer"))
      (insert (funcall row "M-up/down  s" "move line up/down  ·  flash-jump"))
      (insert (funcall hd "windows · git · claude · tools"))
      (insert (funcall row "C-w h/l  C-w w" "move between windows  ·  cycle"))
      (insert (funcall row "SPC g g / g b" "magit status  ·  blame line"))
      (insert (funcall row "SPC a a / a c" "claude menu  ·  start session"))
      (insert (funcall row "SPC o k/o s/o h" "kanban  ·  shell (mistty)  ·  this sheet"))
      (goto-char (point-min))
      (special-mode)))
  (pop-to-buffer "*cheatsheet*"))
(map! :leader :desc "cheat sheet" "o h" #'+wired/cheatsheet)
