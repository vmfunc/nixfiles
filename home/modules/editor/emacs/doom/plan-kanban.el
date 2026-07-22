;;; plan-kanban.el -*- lexical-binding: t; -*-
;; an interactive kanban board over azzie's ~/.plan finger file. the three finger
;; sections (▷ next / ▶ doing / ✓ done) become three lanes. cards move
;; between lanes by keyboard (h/l/H/L, 1-3), by dragging with the mouse, or from the
;; right-click menu; a/e/D add/edit/delete; s/p drive `plan sync` / `plan push`.
;;
;; the file is the source of truth. every mutation rewrites ~/.plan in the EXACT
;; format the `plan` CLI expects (2-space "  · text" bullets, canonical headers), so
;; `plan sync`/reap/publish keep working untouched. pure elisp, no extra packages:
;; a special-mode buffer with text-property cards, tty mouse via xterm-mouse-mode.

(require 'cl-lib)
(require 'subr-x)

(defgroup plan-kanban nil "Kanban over the .plan finger file." :group 'convenience)

(defvar plan-kanban-file "~/.plan" "Path to the .plan working file.")
(defvar plan-kanban-command "plan" "The `plan` CLI, for sync/push.")

;; lane order, glyph, and header text, matched to the plan CLI (package.nix).
;; next leads deliberately: the board reads queue -> in flight -> landed. the
;; someday bucket was merged into next (2026-07); legacy handling in the parser.
(defconst plan-kanban--lanes
  '((next  . "▷ next")
    (doing . "▶ doing")
    (done  . "✓ done")))
(defconst plan-kanban--open-bullet ?·)
(defconst plan-kanban--done-bullet ?×)

(defvar-local plan-kanban--model nil "Parsed board: plist (:preamble LINES :lanes ALIST).")
(defvar-local plan-kanban--idc 0 "Monotonic id counter for cards this session.")

;;; ─── faces ───────────────────────────────────────────────────────────────
;; colored from the doom theme (doom-color), so they track the rice variant.
(defun plan-kanban--col (name) (if (fboundp 'doom-color) (doom-color name) "unspecified-fg"))
(defun plan-kanban--lane-face (lane)
  (list :weight 'bold :foreground
        (plan-kanban--col (pcase lane ('next 'green) ('doing 'violet) ('done 'blue)))))

;;; ─── parse ───────────────────────────────────────────────────────────────
(defun plan-kanban--lane-of-header (line)
  "Return the lane symbol whose header LINE begins, or nil.
A legacy ~ someday header folds into next (the bucket was merged), so a stale
file or a restored .plan.age reflows cleanly instead of gluing its items onto
the previous lane's last card as notes."
  (let ((l (string-trim-left line)))
    (if (string-prefix-p "~" l) 'next
      (car (cl-find-if (lambda (c) (string-prefix-p (substring (cdr c) 0 1) l))
                       plan-kanban--lanes)))))

(defun plan-kanban--parse ()
  "Parse `plan-kanban-file' into the model, assigning fresh card ids."
  (setq plan-kanban--idc 0)
  (let ((lines (when (file-exists-p (expand-file-name plan-kanban-file))
                 (with-temp-buffer
                   (insert-file-contents (expand-file-name plan-kanban-file))
                   (split-string (buffer-string) "\n"))))
        (preamble '()) (lanes (mapcar (lambda (c) (cons (car c) nil)) plan-kanban--lanes))
        (cur nil) (item nil) (seen-header nil))
    (dolist (line lines)
      (let ((lane (and (string-match-p "^[ \t]*[▶▷~✓]" line)
                       (plan-kanban--lane-of-header line))))
        (cond
         (lane (setq cur lane item nil seen-header t))
         ((not seen-header) (push line preamble))       ; header block before lane 1
         ((string-match "^[ \t]*\\([·×]\\)[ \t]+\\(.*\\)$" line)
          (setq item (list :bullet (aref (match-string 1 line) 0)
                           :text (match-string 2 line)
                           :hidden (string-match-p "%hidden" line)
                           :notes nil :id (cl-incf plan-kanban--idc)))
          (when cur (setf (alist-get cur lanes) (append (alist-get cur lanes) (list item)))))
         ((and item (not (string-blank-p line)))         ; indented note under an item
          (setf (plist-get item :notes) (append (plist-get item :notes) (list line))))
         (t nil))))                                       ; blank lines: separators
    (list :preamble (nreverse preamble) :lanes lanes)))

;;; ─── serialize + write (format the CLI expects) ──────────────────────────
(defun plan-kanban--serialize (model)
  (let ((out (copy-sequence (plist-get model :preamble))) (first t))
    (dolist (l plan-kanban--lanes)
      (unless first (push "" out))
      (setq first nil)
      (push (cdr l) out)                                  ; canonical header
      (dolist (it (alist-get (car l) (plist-get model :lanes)))
        (push (format "  %c %s" (plist-get it :bullet) (plist-get it :text)) out)
        (dolist (n (plist-get it :notes)) (push n out))))
    (concat (string-join (nreverse out) "\n") "\n")))

(defun plan-kanban--write ()
  "Persist the in-memory model to `plan-kanban-file'."
  (let ((f (expand-file-name plan-kanban-file)))
    (write-region (plan-kanban--serialize plan-kanban--model) nil f nil 'quiet)))

;;; ─── model helpers ───────────────────────────────────────────────────────
(defun plan-kanban--find (id)
  "Return (LANE . ITEM) for card ID, or nil."
  (cl-loop for (lane . items) in (plist-get plan-kanban--model :lanes)
           for hit = (cl-find id items :key (lambda (i) (plist-get i :id)))
           when hit return (cons lane hit)))

(defun plan-kanban--remove (id)
  (dolist (cell (plist-get plan-kanban--model :lanes))
    (setcdr cell (cl-remove id (cdr cell) :key (lambda (i) (plist-get i :id))))))

(defun plan-kanban--card-at-point () (get-text-property (point) 'plan-kanban-id))

;;; ─── mutations (each: edit model, write file, redraw on the card) ─────────
(defun plan-kanban--commit (&optional keep-id)
  (plan-kanban--write)
  (plan-kanban--render (or keep-id (plan-kanban--card-at-point))))

(defun plan-kanban-move (id lane)
  "Move card ID into LANE; bullet follows the lane (done = ×, else ·)."
  (let ((it (cdr (plan-kanban--find id))))
    (when it
      (plan-kanban--remove id)
      (plist-put it :bullet (if (eq lane 'done) plan-kanban--done-bullet plan-kanban--open-bullet))
      (setf (alist-get lane (plist-get plan-kanban--model :lanes))
            (append (alist-get lane (plist-get plan-kanban--model :lanes)) (list it)))
      (plan-kanban--commit id))))

(defun plan-kanban--shift (delta)
  (let ((id (plan-kanban--card-at-point)))
    (when id
      (let* ((lane (car (plan-kanban--find id)))
             (order (mapcar #'car plan-kanban--lanes))
             (i (+ (cl-position lane order) delta)))
        (when (and (>= i 0) (< i (length order)))
          (plan-kanban-move id (nth i order)))))))

(defun plan-kanban-move-right () (interactive) (plan-kanban--shift 1))
(defun plan-kanban-move-left () (interactive) (plan-kanban--shift -1))
(defun plan-kanban-complete ()
  "Send the current card to the done lane."
  (interactive)
  (when-let* ((id (plan-kanban--card-at-point))) (plan-kanban-move id 'done)))

(defun plan-kanban--lane-at-point ()
  (or (get-text-property (point) 'plan-kanban-lane)
      (car (plan-kanban--find (plan-kanban--card-at-point)))
      'next))

(defun plan-kanban-add (&optional hidden)
  "Add a card to the lane at point. With prefix arg, mark it %hidden."
  (interactive "P")
  (let* ((lane (plan-kanban--lane-at-point))
         (text (string-trim (read-string (format "New card in %s: " lane)))))
    (unless (string-empty-p text)
      (when hidden (setq text (concat text " %hidden")))
      (setf (alist-get lane (plist-get plan-kanban--model :lanes))
            (append (alist-get lane (plist-get plan-kanban--model :lanes))
                    (list (list :bullet (if (eq lane 'done) plan-kanban--done-bullet
                                          plan-kanban--open-bullet)
                                :text text :hidden (and hidden t)
                                :notes nil :id (cl-incf plan-kanban--idc)))))
      (plan-kanban--commit))))

(defun plan-kanban-edit ()
  "Edit the text of the card at point."
  (interactive)
  (when-let* ((id (plan-kanban--card-at-point)) (it (cdr (plan-kanban--find id))))
    (let ((new (read-string "Card: " (plist-get it :text))))
      (plist-put it :text new)
      (plist-put it :hidden (string-match-p "%hidden" new))
      (plan-kanban--commit id))))

(defun plan-kanban-delete ()
  "Delete the card at point (with confirmation)."
  (interactive)
  (when-let* ((id (plan-kanban--card-at-point)) (it (cdr (plan-kanban--find id))))
    (when (yes-or-no-p (format "Delete \"%s\"? " (plist-get it :text)))
      (plan-kanban--remove id)
      (plan-kanban--commit))))

;;; ─── navigation (model-relative, then place point on the card) ────────────
(defun plan-kanban--goto (id)
  (goto-char (point-min))
  (if-let* ((m (and id (text-property-search-forward 'plan-kanban-id id t))))
      (goto-char (prop-match-beginning m))
    (goto-char (point-min))))

(defun plan-kanban--nav (lane-delta idx-delta)
  (let ((id (plan-kanban--card-at-point)))
    (when id
      (let* ((lanes (plist-get plan-kanban--model :lanes))
             (order (mapcar #'car plan-kanban--lanes))
             (lane (car (plan-kanban--find id)))
             (items (alist-get lane lanes))
             (idx (cl-position id items :key (lambda (i) (plist-get i :id))))
             (nlane (nth (max 0 (min (1- (length order))
                                     (+ (cl-position lane order) lane-delta))) order))
             (nitems (alist-get nlane lanes))
             (nidx (max 0 (min (1- (max 1 (length nitems))) (+ idx idx-delta)))))
        (when-let* ((target (nth nidx nitems)))
          (plan-kanban--goto (plist-get target :id)))))))

(defun plan-kanban-next () (interactive) (plan-kanban--nav 0 1))
(defun plan-kanban-prev () (interactive) (plan-kanban--nav 0 -1))
(defun plan-kanban-right () (interactive) (plan-kanban--nav 1 0))
(defun plan-kanban-left () (interactive) (plan-kanban--nav -1 0))

;;; ─── mouse ───────────────────────────────────────────────────────────────
(defun plan-kanban-mouse-select (ev) (interactive "e") (mouse-set-point ev))

(defun plan-kanban--lane-from-posn (posn)
  "Which lane a drop POSN landed in (by card, else by column)."
  (let ((pt (posn-point posn)))
    (or (and pt (get-text-property pt 'plan-kanban-lane))
        (let ((col (car (posn-col-row posn))))
          (nth (min (1- (length plan-kanban--lanes)) (/ col (1+ (plan-kanban--col-width))))
               (mapcar #'car plan-kanban--lanes))))))

(defun plan-kanban-drag-move (ev)
  "Drag a card (start) into the lane it is dropped on (end)."
  (interactive "e")
  (let* ((src (posn-point (event-start ev)))
         (id (and src (get-text-property src 'plan-kanban-id)))
         (lane (plan-kanban--lane-from-posn (event-end ev))))
    (when (and id lane) (plan-kanban-move id lane))))

(defun plan-kanban-mouse-menu (ev)
  "Right-click a card for an action menu. Bound to the click RELEASE (mouse-3),
not down-mouse-3: in a tty the mouse-up would otherwise dismiss the popup the
instant it opens. x-popup-menu renders a real tty menu; the return value is the
chosen item's value, dispatched below (no fragile lambda closures in the menu)."
  (interactive "e")
  (mouse-set-point ev)
  (when (plan-kanban--card-at-point)
    (let ((choice (x-popup-menu
                   ev
                   (list "Card"
                         (cons "Move to"
                               (mapcar (lambda (l) (cons (symbol-name (car l)) (car l)))
                                       plan-kanban--lanes))
                         (list "" (cons "Edit text" 'edit) (cons "Delete card" 'delete))))))
      (pcase choice
        ('edit (plan-kanban-edit))
        ('delete (plan-kanban-delete))
        ((and l (guard (assq l plan-kanban--lanes)))
         (plan-kanban-move (plan-kanban--card-at-point) l))))))

;;; ─── render ──────────────────────────────────────────────────────────────
(defun plan-kanban--col-width ()
  (max 16 (/ (- (window-body-width) 5) (length plan-kanban--lanes))))

(defun plan-kanban--pad (s width &optional face)
  (let ((cell (truncate-string-to-width (or s "") width 0 ?\s "…")))
    (if face (propertize cell 'face face) cell)))

(defun plan-kanban--card-cell (item lane width)
  (let* ((bullet (plist-get item :bullet))
         (notes (plist-get item :notes))
         (raw (concat (char-to-string bullet) " " (when notes "▸ ") (plist-get item :text)))
         (face (cond ((or (eq lane 'done) (eq bullet plan-kanban--done-bullet))
                      (list :foreground (plan-kanban--col 'base5) :strike-through t))
                     ((plist-get item :hidden) (list :foreground (plan-kanban--col 'magenta)))
                     (t 'default)))
         (map (make-sparse-keymap)))
    (define-key map [mouse-1] #'plan-kanban-mouse-select)
    (define-key map [down-mouse-3] #'ignore)            ; keep context-menu-mode off cards
    (define-key map [mouse-3] #'plan-kanban-mouse-menu) ; menu on release, not press
    (propertize (plan-kanban--pad raw width face)
                'plan-kanban-id (plist-get item :id) 'plan-kanban-lane lane
                'mouse-face 'highlight 'keymap map
                'help-echo (concat (plist-get item :text)
                                   (when notes (concat "\n" (string-join notes "\n")))))))

(defun plan-kanban--render (&optional keep-id)
  "Draw the board; restore point to card KEEP-ID if given."
  (let ((inhibit-read-only t) (w (plan-kanban--col-width))
        (lanes (plist-get plan-kanban--model :lanes)) (sep (propertize " │ " 'face 'shadow)))
    (erase-buffer)
    (insert (propertize "  ~/.plan  ·  h/l/H/L move · a add · x done · e edit · t pomodoro · s sync · ? help\n\n"
                        'face 'shadow))
    ;; lane headers with live counts
    (insert (mapconcat (lambda (l)
                         (plan-kanban--pad (format "%s (%d)" (cdr l) (length (alist-get (car l) lanes)))
                                           w (plan-kanban--lane-face (car l))))
                       plan-kanban--lanes sep) "\n")
    (insert (mapconcat (lambda (_) (plan-kanban--pad (make-string w ?─) w 'shadow)) plan-kanban--lanes sep) "\n")
    (let ((h (apply #'max 0 (mapcar (lambda (l) (length (alist-get (car l) lanes))) plan-kanban--lanes))))
      (dotimes (row h)
        (insert (mapconcat (lambda (l)
                             (let ((it (nth row (alist-get (car l) lanes))))
                               (if it (plan-kanban--card-cell it (car l) w)
                                 (plan-kanban--pad "" w))))
                           plan-kanban--lanes sep)
                "\n")))
    (goto-char (point-min))
    (when keep-id (plan-kanban--goto keep-id))))

;;; ─── commands: reload / sync / raw edit / quit ────────────────────────────
(defun plan-kanban-reload ()
  "Re-read ~/.plan from disk (picks up external edits / plan sync)."
  (interactive)
  (setq plan-kanban--model (plan-kanban--parse))
  (plan-kanban--render))

(defun plan-kanban--run (&rest args)
  (let ((buf (get-buffer-create "*plan*")))
    (make-process :name "plan" :buffer buf :command (cons plan-kanban-command args)
                  :sentinel (lambda (_p e)
                              (when (string-match-p "finished" e)
                                (with-current-buffer (get-buffer "*plan-kanban*")
                                  (plan-kanban-reload))
                                (message "plan %s done" (car args)))))))
(defun plan-kanban-sync () "Two-way sync via `plan sync', then reload." (interactive)
       (message "plan sync…") (plan-kanban--run "sync"))
(defun plan-kanban-push () "Publish + push via `plan push'." (interactive)
       (message "plan push…") (plan-kanban--run "push"))
(defun plan-kanban-open-file () (interactive) (find-file (expand-file-name plan-kanban-file)))

;;; ─── pomodoro (a .plan-native focus timer over the card at point) ─────────
;; start on the selected card; the countdown rides the GLOBAL mode line so it is
;; visible after you leave the board. work -> break -> done, each edge fires a
;; desktop notification (D-Bus; falls back to the echo area headless).
(defvar plan-kanban-pomodoro-work-minutes 25 "Focus-block length in minutes.")
(defvar plan-kanban-pomodoro-break-minutes 5 "Break length in minutes.")
(defvar plan-kanban--pomo-timer nil)     ; the 1s ticker
(defvar plan-kanban--pomo-deadline nil)  ; float-time when the current phase ends
(defvar plan-kanban--pomo-phase nil)     ; 'work | 'break
(defvar plan-kanban--pomo-task nil)      ; the card text under focus
(defvar plan-kanban--pomo-segment "")    ; the global-mode-string cell
(put 'plan-kanban--pomo-segment 'risky-local-variable t)

(defun plan-kanban--pomo-notify (title body)
  (if (and (require 'notifications nil t) (fboundp 'notifications-notify))
      (notifications-notify :title title :body body :app-name "plan")
    (message "%s: %s" title body)))

(defun plan-kanban--pomo-clear ()
  (when plan-kanban--pomo-timer (cancel-timer plan-kanban--pomo-timer))
  (setq plan-kanban--pomo-timer nil plan-kanban--pomo-deadline nil
        plan-kanban--pomo-phase nil plan-kanban--pomo-task nil
        plan-kanban--pomo-segment "")
  (setq global-mode-string (delq 'plan-kanban--pomo-segment global-mode-string))
  (force-mode-line-update t))

(defun plan-kanban--pomo-tick ()
  (let ((left (round (- plan-kanban--pomo-deadline (float-time)))))
    (if (> left 0)
        (progn
          (setq plan-kanban--pomo-segment
                (format " %s %02d:%02d %s"
                        (if (eq plan-kanban--pomo-phase 'work) "🍅" "☕")
                        (/ left 60) (mod left 60)
                        (truncate-string-to-width (or plan-kanban--pomo-task "") 24 0 nil "…")))
          (force-mode-line-update t))
      (if (eq plan-kanban--pomo-phase 'work)
          (progn
            (plan-kanban--pomo-notify "pomodoro done"
                                      (format "focused: %s. break time." plan-kanban--pomo-task))
            (setq plan-kanban--pomo-phase 'break
                  plan-kanban--pomo-deadline
                  (+ (float-time) (* 60 plan-kanban-pomodoro-break-minutes))))
        (plan-kanban--pomo-notify "break over" "back to it, petal.")
        (plan-kanban--pomo-clear)))))

(defun plan-kanban-pomodoro ()
  "Start a focus pomodoro on the card at point; the countdown shows in the mode line."
  (interactive)
  (let* ((id (plan-kanban--card-at-point))
         (it (and id (cdr (plan-kanban--find id))))
         (task (if it (plist-get it :text) "(no card)")))
    (plan-kanban--pomo-clear)
    (setq plan-kanban--pomo-task task
          plan-kanban--pomo-phase 'work
          plan-kanban--pomo-deadline (+ (float-time) (* 60 plan-kanban-pomodoro-work-minutes)))
    (unless (memq 'plan-kanban--pomo-segment global-mode-string)
      (setq global-mode-string (append global-mode-string '(plan-kanban--pomo-segment))))
    (setq plan-kanban--pomo-timer (run-at-time 0 1 #'plan-kanban--pomo-tick))
    (message "pomodoro: %d min on \"%s\"" plan-kanban-pomodoro-work-minutes task)))

(defun plan-kanban-pomodoro-stop ()
  "Cancel any running pomodoro."
  (interactive)
  (plan-kanban--pomo-clear)
  (message "pomodoro cleared"))

;;; ─── mode ────────────────────────────────────────────────────────────────
(defvar plan-kanban-mode-map
  (let ((m (make-sparse-keymap)))
    (define-key m [drag-mouse-1] #'plan-kanban-drag-move)
    (define-key m (kbd "RET") #'plan-kanban-edit)
    m)
  "Base keymap; evil motion keys are added in config below.")

(define-derived-mode plan-kanban-mode special-mode "Kanban"
  "Interactive kanban over the ~/.plan finger file."
  (setq-local truncate-lines t cursor-type 'box)
  (add-hook 'window-size-change-functions
            (lambda (_) (when (eq major-mode 'plan-kanban-mode)
                          (plan-kanban--render (plan-kanban--card-at-point))))
            nil t))

;;;###autoload
(defun plan-kanban ()
  "Open the .plan kanban board."
  (interactive)
  (let ((buf (get-buffer-create "*plan-kanban*")))
    (with-current-buffer buf
      (plan-kanban-mode)
      (setq plan-kanban--model (plan-kanban--parse))
      (plan-kanban--render))
    (pop-to-buffer-same-window buf)))

;;; ─── evil + doom keybindings ─────────────────────────────────────────────
;; special-mode buffers land in evil MOTION state; bind there so h/j/k/l are ours.
(after! evil
  (evil-set-initial-state 'plan-kanban-mode 'motion))
(map! :map plan-kanban-mode-map
      :nvm "j" #'plan-kanban-next    :nvm "k" #'plan-kanban-prev
      :nvm "l" #'plan-kanban-right   :nvm "h" #'plan-kanban-left
      :nvm "L" #'plan-kanban-move-right :nvm "H" #'plan-kanban-move-left
      :nvm "1" (cmd! (plan-kanban-move (plan-kanban--card-at-point) 'next))
      :nvm "2" (cmd! (plan-kanban-move (plan-kanban--card-at-point) 'doing))
      :nvm "3" (cmd! (plan-kanban-move (plan-kanban--card-at-point) 'done))
      :nvm "x" #'plan-kanban-complete :nvm "a" #'plan-kanban-add
      :nvm "e" #'plan-kanban-edit     :nvm "D" #'plan-kanban-delete
      :nvm "g" #'plan-kanban-reload   :nvm "s" #'plan-kanban-sync
      :nvm "p" #'plan-kanban-push     :nvm "E" #'plan-kanban-open-file
      :nvm "t" #'plan-kanban-pomodoro :nvm "T" #'plan-kanban-pomodoro-stop
      :nvm "q" #'quit-window
      :nvm "?" (cmd! (message "h/l move cursor · H/L or 1-3 move card · drag/right-click too · a add · x done · e edit · D del · t pomodoro · s sync · p push · g reload · E raw file")))

(provide 'plan-kanban)
