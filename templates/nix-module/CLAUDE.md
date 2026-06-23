# nix-module: project CLAUDE.md

A standalone home-manager module, written in azzie's mac-rice house style. The
deliverable is `module.nix`; the flake just wires eval/check/fmt around it.

## Read first

- **`~/.config/claude/nix-guide.md`**: the Nix conventions. Follow it.

## House style (match mac-rice/home/modules)

- Lead every module with a comment on why it exists.
- One feature namespace: `rice.<feature>` with an `lib.mkEnableOption` gate and
  the real config under `lib.mkIf cfg.enable { … }`.
- Every option typed and described (`lib.mkOption` with `type` +
  `description`, `example`/`defaultText` where it helps). No untyped attrsets
  leaking into config.
- Theme is SSOT. Colours come from `config.rice.theme.*` (the typed palette
  in `home/modules/theme.nix`: `flavor`, `accent`, `colors`, `accentHex`), never
  hardcode a hex. Read it defensively (`config.rice.theme or {}`) so the module
  still evaluates standalone, but in the real config it follows the global accent.
- Prefer `programs.<tool>` / `xdg.configFile` over hand-rolled `home.file` when a
  first-class HM option exists.
- catppuccin: the global `catppuccin` module is enabled centrally
  (theme.nix sets `catppuccin.{enable,flavor,accent}`); per-module you usually
  just set `catppuccin.<tool>.enable = false` if you're hand-rolling that tool's
  palette, like starship does.

## Workflow

- `nix fmt`: nixfmt-rfc-style (the repo formatter).
- `nix flake check`: evaluates the module against a throwaway HM config; catches
  bad option types before it hits the real flake.
- To ship: import `homeManagerModules.default` from your real config, or copy
  `module.nix` into `home/modules/<area>/<feature>.nix` and add it to the imports.

## Gotcha

Nix flake builds ignore untracked (`??`) files. If a change to `module.nix` seems
to have no effect, `git add` it first.
