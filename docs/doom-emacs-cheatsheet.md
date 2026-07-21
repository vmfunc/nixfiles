# doom emacs, for a VSCode refugee

tuna's default editor. lives in the terminal: `e <file>` (or just `e`) opens a
frame in wezterm, lazy-starting a daemon the first time so every frame inherits the
shell's env. `EDITOR`/`VISUAL` point at it too, so git and aerc drop you here. the
GUI frame exists but is hidden from the app launcher on purpose.

You don't have to memorize emacs. **Tap `SPC` and wait**: which-key pops up showing
every command under that prefix. Evil (vim keys) is on, with the VSCode chords you
already know wired over the top. Most fancy chords need the kitty keyboard protocol,
which wezterm now sends (`enable_kitty_keyboard`), so they arrive distinct in the
terminal; the `SPC` mirrors always work regardless.

## the muscle-memory map

| in VSCode you pressed… | here it's… | does |
|---|---|---|
| `Ctrl+S` | `Ctrl+S` | save (works in insert mode too) |
| `Ctrl+P` | `Ctrl+P` | find/open files in the project |
| `Ctrl+Shift+P` | `Ctrl+Shift+P` or `SPC :` | M-x command palette |
| `Ctrl+Shift+F` | `Ctrl+Shift+F` or `SPC s p` | search in all files (ripgrep) |
| `Ctrl+B` | `Ctrl+B` | toggle the treemacs file-tree sidebar |
| `Ctrl+/` | `Ctrl+/` | toggle comment (works on a selection too) |
| `` Ctrl+` `` | `` Ctrl+` `` | toggle a vterm terminal |
| `Ctrl+.` | `Ctrl+.` or `SPC c a` | code action (quick fix) |
| `F2` | `F2` or `SPC c r` | rename symbol everywhere |
| `F12` / go-to-def | `g d` | go to definition |
| `Shift+F12` / refs | `g r` | find references |
| hover docs | `K` | hover documentation |
| `Ctrl+click` | `Ctrl+click` | go to definition under the pointer |
| problems panel | `SPC c x` | flymake diagnostics list |
| next/prev problem | `] d` / `[ d` | jump between diagnostics |
| `Ctrl+W` close tab | `Ctrl+W` | kill the current buffer |
| switch tabs | `Shift+L` / `Shift+H` | next / previous buffer |
| `Alt+Up` / `Alt+Down` | `Alt+Up` / `Alt+Down` | move the line up / down |
| IntelliSense | `Ctrl+Space` | trigger corfu completion (`Tab` cycles) |
| `Ctrl+D` multi-cursor | `M-d` | evil-multiedit: match+select next occurrence |

## the `SPC` menus (press Space, then…)

- `SPC f…` **files**: `f` find file · `r` recent · `p` project · `s` save
- `SPC s…` **search**: `p` grep project · `s` in-buffer · `i` imenu symbols
- `SPC c…` **code**: `a` action · `r` rename · `x` diagnostics · `f` format · `d` docs
- `SPC g…` **git**: `g` magit status · `b` blame · the difftastic (`M-d` in magit) structural diff
- `SPC o…` **open**: `c` claude · `s` mistty shell · `p` project sidebar
- `SPC a…` **claude** (see below)
- `SPC p…` **project** · `SPC b…` **buffers** · `SPC w…` **windows** (the old evil `C-w` map)

## claude code, out of the box (`SPC a`)

Not a terminal wrapper: `claude-code-ide.el` registers emacs as Claude Code's IDE
over MCP, so the already-installed CLI sees your buffer selection, opens its proposed
edits as an ediff for you to review, reads your flymake diagnostics, and can call
emacs tools (xref, imenu, treesit). Runs the real Claude TUI in a vterm.

- `SPC a a` menu · `SPC a c` start a session in this project · `SPC a r` resume · `SPC a C` continue
- `SPC a t` toggle the window · `SPC a p` send a prompt · `SPC a s` @-mention the selection
- `SPC a l` list sessions · `SPC a q` stop

`gptel` (`SPC RET`) is alongside for quick in-buffer rewrites, and `macher` reviews
multi-file LLM edits as diffs before applying.

## discord rich presence

Shows "Editing <buffer> · <mode>" through Vesktop's arRPC. Files under `~/pentest`
and `~/cases` show as `[redacted]` so project names never leak. It drops when the
last terminal frame closes. **Two one-time toggles** or it silently never appears:
in Vesktop enable "Rich Presence via arRPC", and in Discord set Activity Privacy →
"Share your detected activities with others".

## things that just happen

- **format on save**: apheleia, per language (nixfmt, stylua, ruff, gofumpt,
  rustfmt, clang-format, prettierd, shfmt, taplo). No keypress.
- **true undercurl** under diagnostics, from wezterm's `term=wezterm` terminfo.
- **icons in the terminal**: nerd-icons render from wezterm's font, no images needed.
- **the theme** is generated from `theme.nix`, so flipping the blood/copland/macchiato
  variant recolors emacs with everything else.

## the good extras worth knowing

- `s` (avy-style flash jump is doom's; here `g z`/`g Z` are symbol-overlay highlights)
- `g U` visual undo tree (vundo) · `M-$` fix spelling (jinx)
- `SPC o s` a real shell-in-a-buffer (mistty) with evil motions over scrollback
- `C-o` in dired/ibuffer/calc/info opens a casual transient menu of its powers
- RE kit: `nhexl-mode` (hex), `C-c d` objdump the function at point (disaster),
  `nasm-mode`, `verb` (http workbench), `elfeed` (infosec feeds)
- `expreg`: in visual state, tap `v` to expand the selection by syntax node

> built from source by nix-doom-emacs-unstraightened, pinned to the emacs 31 pretest.
> config is a read-only nix store path: edit `home/modules/editor/emacs/doom/` and
> rebuild, not in place. tuna-only (see the module header for why).
