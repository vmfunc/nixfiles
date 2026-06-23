# neovim, for a VSCode refugee

You don't have to memorize vim. **Tap `<Space>` and wait** — a menu (which-key)
pops up showing every command. The chords below are the VSCode ones you already
know, wired to do the same thing.

## the muscle-memory map

| in VSCode you pressed… | here it's… | does |
|---|---|---|
| `Ctrl+S` | `Ctrl+S` | save (works in insert mode too) |
| `Ctrl+P` | `Ctrl+P` | find/open files |
| `Ctrl+Shift+P` | `Ctrl+Shift+P` or `<Space>fp` | command palette |
| `Ctrl+Shift+F` | `Ctrl+Shift+F` or `<Space>fg` | search in all files (grep) |
| `Ctrl+B` | `Ctrl+B` | toggle the file-tree sidebar |
| `Ctrl+/` | `Ctrl+/` or `<Space>/` | toggle comment (works on a selection too) |
| `` Ctrl+` `` | `` Ctrl+` `` | open a terminal (bottom split); `Esc` leaves it |
| `Ctrl+.` | `Ctrl+.` or `<Space>ca` | code action (quick fix) |
| `F2` | `F2` or `<Space>cr` | rename symbol everywhere |
| `F12` / go-to-def | `gd` | go to definition |
| `Shift+F12` / refs | `gr` | find references |
| hover docs | `K` | hover documentation |
| problems panel | `<Space>xx` | Trouble diagnostics panel |
| next/prev problem | `]d` / `[d` | jump between diagnostics (`]e`/`[e` = errors only) |
| `Ctrl+W` close tab | `Ctrl+W` | close the current buffer |
| switch tabs | `Shift+L` / `Shift+H` | next / previous buffer |
| IntelliSense | `Ctrl+Space` | trigger completion (`Tab`/`Shift+Tab` cycle, `Enter` accepts) |

## the `<Space>` menus (press Space, then…)

- `<Space>f…` **find** — `ff` files · `fg` grep · `fb` buffers · `fr` recent · `fs` symbols · `fd` diagnostics
- `<Space>c…` **code** — `ca` action · `cr` rename · `cf` format · `cd` line diagnostic
- `<Space>g…` **git** — `gb` blame · `gp` preview hunk · `gs` stage hunk · `gr` reset hunk · `gd` diff
- `<Space>x…` **problems** — `xx` panel · `xt` TODO list
- `<Space>b…` **buffers** — `bd` close · `bo` close others
- `<Space>e` focus the tree · `<Space>q` quit

## things that just happen

- **format on save** — automatic, per language (nixfmt, stylua, ruff, gofumpt, rustfmt, clang-format, prettierd, shfmt). No keypress.
- **autocomplete** pops as you type; docs show beside it. `Enter` accepts.
- **git gutter** shows changes; `]h`/`[h` jump between hunks.
- **`s` + 2 letters** (flash) jumps your cursor anywhere on screen.
- **`af`/`if`** in visual/operator mode = a/inner function (`daf` deletes a whole function).

## one gotcha (terminals)

`Ctrl+Shift+P`, `Ctrl+.`, and `Ctrl+/` need your terminal to send "CSI-u" key
encoding. WezTerm does. If a chord ever doesn't register, the `<Space>` fallback
always works — every VSCode chord has a `<Space>` twin above.

managed in `home/modules/editor/neovim.nix`; nix owns every plugin + LSP, so
this rebuilds identically on every host (otter, coral, cuttlefish).
