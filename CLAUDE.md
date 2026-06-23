# CLAUDE.md

onboarding + rules for quaver's multi-host nix-darwin + home-manager config. read this before touching anything. for the full nix style reference, see `docs/nix-style.md`.

## what this is

a flake-based, multi-host nix config (catppuccin macchiato) managed declaratively. nix is the source of truth, not imperative scripts. public mirror at git.collar.sh/quaver/nixfiles, so anything committed here is world-readable (see secrets rules below). three hosts:

- **otter**: aarch64-darwin, MacBook Pro laptop. distributed-builds *client*: offloads aarch64-darwin builds to coral.
- **coral**: aarch64-darwin, M5 Pro. always-on clamshell office desktop, remote box, and the nix build *server* otter offloads to.
- **cuttlefish**: x86_64-linux, NixOS on a Framework Laptop 12. FDE + impermanence + secure boot. deployed remotely *from otter* via deploy-rs (it cannot be built on a mac, the x86_64 closure needs a real x86_64 builder).

## architecture / mental model

the spine is `flake.nix` -> `lib/default.nix` (`mkDarwin` / `mkNixos`) -> assembled module layers. every host build flows through this:

```
commonModules = [ hosts/<host>  modules/shared  { nixpkgs.hostPlatform } ]
  darwin: + modules/darwin + mac-app-util + home-manager.darwinModules + hmModule
  nixos:  + modules/nixos  + impermanence + lanzaboote + home-manager.nixosModules + hmModule
```

`hmModule` (lib/default.nix) sets useGlobalPkgs/useUserPackages, `backupFileExtension = "hm-backup"`, threads `inputs`/`outputs`/`username`/`hostname`/`theme` as extraSpecialArgs, and imports `home/<hostname>.nix` for the user.

### the layers (by blast radius)

| path | scope | hits |
|------|-------|------|
| `hosts/<host>/default.nix` | per-machine SYSTEM deviations only | that one box |
| `modules/darwin/*` | shared darwin SYSTEM config | both macs (otter + coral) |
| `modules/nixos/*` | shared nixos SYSTEM config | cuttlefish only |
| `modules/shared/*` | cross-platform SYSTEM config | every host |
| `home/<host>.nix` | per-machine HOME entrypoint (imports profiles + host rice.* options) | that one box |
| `home/core.nix` | shell/cli HOME baseline | every host |
| `home/profiles/*` | base.nix / desktop-darwin.nix / desktop-linux.nix / security.nix | hosts that import them |
| `home/modules/<area>/*` | ONE FILE PER PROGRAM (cli/ shell/ desktop/ editor/ terminal/) | wherever imported |

`hosts/<host>` is *only* the deviations unique to that box. everything in `modules/darwin` and `modules/shared` is inherited automatically. do not branch on hostname inside a shared module, push the deviation up into the host layer or gate it behind a `rice.*` option.

### where does a new thing go?

- **system-wide, all hosts** -> `modules/shared/`
- **both macs** -> `modules/darwin/`
- **only nixos** -> `modules/nixos/`
- **one specific box** -> `hosts/<host>/default.nix`
- **per-user, all hosts** -> `home/core.nix` or a module under `home/profiles/base.nix`
- **a single program's config** -> a new file in `home/modules/<area>/`, one program per file, imported from the right profile

### rice.* option namespace

all custom options live under `rice.*` and are defined in the module that owns them, then set per-host or per-profile. e.g. `rice.autoUpdate`, `rice.backup`, `rice.theme`, `rice.dashboard`, `rice.zenTabgrouper`. a cross-platform option (`rice.autoUpdate`) must have its option *tree* defined on both darwin and nixos (modules/shared is imported by both toplevels) and fork only the *implementation*. note auto-update.nix probes `options ? launchd` to detect darwin, deliberately NOT `pkgs.stdenv.isDarwin`, to avoid the config<-pkgs infinite recursion.

### theme

`theme.nix` is a plain `rec` attrset of colors (flavor=macchiato, accent=mauve). imported once in `lib/default.nix` and threaded everywhere as the `theme` specialArg. reachable two ways, both live: directly as `theme.palette.<name>` / `theme.flavor` / `theme.accentHex`, and via the readOnly `rice.theme.*` options in `home/modules/theme.nix` (whose defaults *are* the theme attrset). `home/modules/theme.nix` is the only file that flips on `catppuccin.enable`. modules reach into the raw `theme` specialArg only where catppuccin has no native integration (nushell ansi, gh-dash, starship palette, clipse json, fastfetch). **this repo is macchiato. do not "fix" it to any other flavor regardless of global prefs.**

### pkgs/ + overlays/

`pkgs/default.nix` callPackages quaver's custom packages (cozy shell CLIs like `case`/`plan`/`gate-check`, plus an RE/security toolchain: frida-mcp, ghidrecomp, pyghidra-mcp, r2mcp, re-harness, record, zen-tabgrouper). surfaced two ways, both darwin-gated: as flake `packages.<darwin>` and merged into nixpkgs via the `additions` overlay so any module can reach them by attr name. `overlays/default.nix` is `{ additions, modifications }`, consumed in `modules/shared/nixpkgs.nix`. `modifications` pins/patches upstream (qemu from the nixpkgs-qemu input, sif/john hashes). pinned inputs carry a WHY comment and a revert condition.

### secrets

sops-nix. `secrets/` holds ciphertext only (`anthropic.yaml`, `filevault.yaml`, `nix.yaml`, `restic.yaml`), encrypted via `secrets/.sops.yaml` to a single age recipient. consume via `sops.secrets.<name>.path`, never inline plaintext. since the mirror is public, plaintext secrets in the tree are a leak, not a style nit.

## daily commands

`nh` picks darwin/nixos from the OS and the host from hostname automatically.

| recipe | what |
|--------|------|
| `just switch` | rebuild + activate this host |
| `just build` | build only, no activation |
| `just check` | local gate: treefmt check + this host builds clean (full `nix flake check` chokes on cuttlefish IFD, see gotchas) |
| `just fmt` | `nix fmt` every nix file |
| `just lint` | statix check + deadnix --fail + shellcheck on sketchybar plugins (mirrors CI lint.yml exactly) |
| `just scan` | gitleaks secret scan before pushing public |
| `just gate` | disclosure tripwire over ~/pentest (darwin-only, `#gate-check`) |
| `just deploy` | atomic remote deploy of cuttlefish from otter (deploy-rs, magic-rollback) |
| `just gc` | `nh clean all --keep 5 --keep-since 7d` |
| `just dev` | dev shell (nixd, nixfmt, statix, deadnix, nh, just, sops, ssh-to-age, age) |

## STRICT RULES (non-negotiable)

these are gates, not suggestions. CI enforces all of them (`.forgejo/workflows`: check.yml = treefmt, eval.yml = otter + cuttlefish drvPath, lint.yml = statix + deadnix + shellcheck).

1. **formatting must pass.** `just fmt` (nixfmt via treefmt) leaves zero diff. generated shell counts too. a file that is not nixfmt-clean turns CI's check job red.
2. **lint must pass.** `statix check` and `deadnix --no-lambda-pattern-names --fail` both exit zero. statix flags eta-reducible lambdas and inherit-from opportunities; fix them, then re-run `just fmt`. shellcheck (-S warning) on sketchybar plugins must be clean.
3. **every host must still eval before commit.** run `just check` (builds this host). coral + otter eval locally; cuttlefish evals only in CI (see gotchas). a commit that breaks any host's eval is a broken commit.
4. **commit messages: `scope: lowercase summary`.** e.g. `darwin/homebrew: add android-studio cask`. lowercase, scoped, terse.
5. **NO AI attribution. ever.** no `Co-Authored-By`, no `Co-authored-by`, no Claude/Anthropic trailer, not in the commit, the body, or a PR description. anywhere.
6. **NO em dashes.** not in code comments, not in prose, not in user-facing print strings. use a comma, a period, or "...". the owner reads this output daily.
7. **comments explain WHY, never HOW.** lowercase, dense. document the gotcha, the threat model, the deliberate non-choice ("there is NO nix-darwin option for X, so we drive Y by hand"). a comment that restates the code is cruft. module files open with a header block stating purpose + cross-file deps. flag manual one-time deploy steps with the `TODO(deploy):` marker (not a soft informal note, those slip the grep).
8. **new custom options go under `rice.*`,** defined in the owning module, set in hosts/profiles.
9. **one program per file** under `home/modules/<area>/`.
10. **secrets are sops-only.** never commit a plaintext key, token, password, or recovery key. run `just scan` before any push to the public mirror.
11. **flake inputs use `.follows`** for nixpkgs (and friends) to avoid closure bloat. pinned/workaround inputs carry a WHY + revert-condition comment (see nixpkgs-qemu).
12. **a homebrew cask is NOT built by nix.** when you add one to `modules/darwin/homebrew.nix`, remember nix does not manage its lifecycle. the autostart pattern for a brew GUI app lives in a per-user launchd agent under `home/modules/desktop/` (see `music-presence.nix` / `autoraise.nix`: KeepAlive must be false for anything that `open`s and forks, or it hot-loops).
13. **after ANY change, run the gates:** `just fmt && just lint && just check`. do not commit red.

full style reference (file layout, lib idioms, the cfg/options/config option shape, cross-platform module rules, the exact statix examples, deploy + secrets discipline): `docs/nix-style.md`.

## gotchas / non-obvious

- **`statix.toml` controls which lints run.** a malformed TOML there makes `statix check` a silent no-op in both `just lint` and CI (this happened, the file had a missing comma and lint was dead). if you touch it, verify statix actually runs and still exits nonzero on a known violation.
- **cuttlefish cannot be evaluated on an aarch64 mac locally.** it is x86_64 + catppuccin IFD, so a full `nix flake check` from a mac chokes. that is why `flake.nix` exposes only `checks.<sys>.formatting` and why `just check` builds *this* host only. cuttlefish eval is covered by CI (eval.yml builds its toplevel drvPath).
- **coral is always-on and a remote nix builder.** otter's `nix.buildMachines` offloads aarch64-darwin to coral over tailscale (root-owned ssh key, since nix-daemon runs as root). coral keeps itself awake via `pmset disablesleep` driven by hand in a postActivation mkBefore script (no nix-darwin option for it).
- **`rice.autoUpdate` pulls + switches on a schedule.** it is `enable = true` on all three hosts, hourly, from the promoted `deploy` branch (`git+https://git.collar.sh/quaver/nixfiles?ref=deploy`). a bad push to that branch reaches coral and cuttlefish automatically. the darwin updater is fail-closed (no-ops until the netrc + age key exist) and pins the exact ls-remote rev so build/activate/stamp are one commit, but the deploy branch is still effectively production. push there carefully.
- **mac-app-util wires GUI apps** (Spotlight/Dock visibility for nix-installed .app bundles) on both macs via an inline home-manager sharedModule injected in `mkDarwin`.
- **deploy-rs needs sshd on the target.** cuttlefish is deployed exclusively over ssh (`sshUser = root`, `remoteBuild = true`); if the nixos side does not provide `services.openssh` + root authorized_keys, ongoing deploys fail after the initial bootstrap.
- **a few known stale markers exist** in comments and the README (it still says "a nixos box later" though coral + cuttlefish ship now). when you touch a file with a stale `<tailnet>`-style placeholder or a "future linux box" comment, fix it in passing rather than copying the drift forward.
