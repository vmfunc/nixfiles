# nix style

the coding style for this repo (otter + coral + cuttlefish, nix-darwin + nixos + home-manager,
lain wired rice, variant-selectable `theme.nix`). it is grounded in what the tree already does, sharpened by nixpkgs / nix-darwin
best practice, and strict enough to enforce in review and CI. when this doc and a file disagree, the
file is probably the bug, fix the file. when nixfmt and this doc disagree, nixfmt wins, always.

the gates that must be green before any commit: `just fmt` (treefmt/nixfmt), `statix check`,
`deadnix --fail`, and a host eval (`just check`). a passing lint job that lints nothing is worse than a
red one, see [lint gates](#lint--eval-gates).

## formatting is law

- nixfmt (RFC 166, via treefmt) owns every byte of whitespace, indentation, and line wrapping. run
  `just fmt` before commit. `check.yml` fails on any unformatted `.nix`.
- never hand-fight the formatter. 2-space indent, attrset wrapping, argument-list wrapping: all
  nixfmt's call, not yours. if a construct formats ugly, the construct is wrong, not the formatter.
- this applies to generated shell too: `pkgs.writeShellScript` / `writeShellApplication` bodies are
  formatted as strings, keep them clean so shellcheck (`lint.yml`) stays green.

## file layout: blast radius decides the file

put a setting in the file whose scope matches how widely it applies. this is the single most important
rule in the repo, get it wrong and you get per-host drift.

| scope | file |
|---|---|
| unique to one box | `hosts/<host>/default.nix` |
| every host, any OS | `modules/shared/*` |
| every darwin host | `modules/darwin/*` (both macs inherit ALL of it) |
| every nixos host | `modules/nixos/*` |
| every home | `home/core.nix` |
| a class of home (darwin desktop, security box) | `home/profiles/*` |
| one program's home config | `home/modules/<area>/<program>.nix` |
| host assembly | `lib/default.nix` (`mkDarwin`/`mkNixos`) |
| custom package | `pkgs/` (`callPackage`'d, one line each in `pkgs/default.nix`) |
| upstream pin/patch | `overlays/default.nix` |
| secret | `secrets/*` (sops, ciphertext only) |

hard rules:

- **one program per file** under `home/modules/<area>/`. a trivial enable stays its own 2-3 line module
  (`btop.nix`, `eza.nix`, `zoxide.nix`), do not fold them together. a program's entire footprint must be
  greppable in one place.
- **no per-host branch inside `modules/*`.** never `if hostname == "coral"` or
  `lib.mkIf (hostname == ...)` in `modules/shared` or `modules/darwin|nixos`. both macs inherit
  `modules/darwin` identically. if it differs per host, make it a `rice.*` option set per-host, or move
  the deviation to `hosts/<host>`.
- **`default.nix` import roots are pure aggregators.** `modules/darwin/default.nix` is an imports list,
  no logic.
- **add a host as a 3-line attrset in `flake.nix`** calling `mylib.mkDarwin`/`mkNixos`
  `({hostname, username, system})`. never inline a host's module list into `flake.nix`.
- **extract on the second real divergence, not the first guess.** delete any profile no host imports and
  any `rice.*` option with one caller.

## flake.nix stays thin

`flake.nix` declares inputs and calls factories. that is it.

- all assembly lives in `lib/` (`mkDarwin`/`mkNixos`), packages in `pkgs/`, overlays in `overlays/`. no
  per-host logic, no business logic in the top-level flake.
- inlined devShells should be short. a ~55-line `pwn` shell living in `flake.nix` is a smell, lift it
  toward a `templates/`-style file (see `templates/pwn`).

## module file structure

every module is a function `{ a, b, ... }: { ... }`. two rules:

- **pull only the args you use.** `{ ... }:` for otter's home entrypoint, `{ config, lib, ... }:` for
  coral. unused-but-accepted args get an underscore (`_final`, `_`) so deadnix stays green.
- **non-trivial modules get a header comment block** stating purpose + cross-file deps + the deliberate
  non-choices. see `syncthing.nix` (the "restic is the REAL backup, syncthing is live replication" block)
  or `auto-update.nix`. one-line modules (`modules/darwin/sketchybar.nix`, `home/modules/cli/zellij.nix`) skip the header.

```nix
# cross-platform workspace replication across otter / cuttlefish / coral.
# home-manager's services.syncthing wires a launchd agent on darwin and a
# systemd user service on linux from the SAME declaration, so this one module
# is correct on every node.
{
  config,
  lib,
  hostname,
  ...
}:
```

## comments: WHY, never WHAT

- **lowercase, dense.** explain WHY, the gotcha, or the threat model. never restate the code. a comment
  that paraphrases the line below it is noise, delete it.
- **document the deliberate NON-choice.** the repo's signature: "there is NO nix-darwin option for X, so we
  drive Y by hand" (`firewall.nix` driving `socketfilterfw` because `system.defaults.alf` is broken,
  cite the issue: `nix-darwin#1243`). "no openzfs: kext panics macOS 26 (SPTM)".
- **`TODO(deploy):`** marks a manual one-time step nix cannot perform (a System Settings toggle, a
  host key, a builder key, recording a tailnet IP). these are a deploy checklist, not stale cruft. the
  eval-safe `TODO` placeholder in `syncthing.nix` (`cuttlefish = "TODO-FILL-AT-DEPLOY"`, filtered out by
  `isReal`) is the only other legitimate `TODO`. do not use `TODO` as a generic in-prose marker.
- **point at cross-file deps, don't duplicate them.** the `music-presence` cask in `homebrew.nix` says
  "autostart + rationale in home/modules/desktop/music-presence.nix".
- **no em dashes anywhere.** comma, period, or `...`. no AI attribution, no `Co-Authored-By`, not in
  comments, commits, or PRs.

## naming

- identifiers, let-bindings, and `rice.*` option names are **lowerCamelCase** (`deviceIds`,
  `realDeviceIds`, `hubVersioning`, `rice.autoUpdate`).
- filenames are **kebab-case** (`auto-update.nix`, `restic-darwin.nix`, `zen-tabgrouper.nix`).
- **UPPER_CASE is for real env vars only** (`home.sessionVariables`, sketchybar plugin tunables). never
  for nix identifiers.
- magic constants get a name in a `let`, never inlined: `thirtyDaysSeconds = 30 * 24 * 60 * 60;`,
  `luksName`, `atuinHost`/`atuinPort`. no bare magic numbers.

## lib idioms

- **conditional lists/attrs** use `lib.optional` / `optionals` / `optionalAttrs` / `optionalString`, never
  `if cond then [x] else []`.

  ```nix
  # good
  addresses = lib.optional (tailnetAddr ? ${name}) "tcp://${tailnetAddr.${name}}:22000" ++ [ "dynamic" ];
  # bad
  addresses = (if tailnetAddr ? ${name} then [ "tcp://..." ] else []) ++ [ "dynamic" ];
  ```

- **config composition** uses `mkIf` / `mkMerge`. emit several conditional definition sets from one module
  with `lib.mkMerge` rather than nesting `mkIf` inside one attr (see `zen-tabgrouper.nix`'s `home.file`).
- **`mkDefault` in a base/profile, plain value in a host** is the clean override path, exactly how
  `desktop-darwin.nix` sets `rice.backup.enable = mkDefault true` so coral (no backup drive) turns it off
  with a plain `false`. `mkForce` is last resort and carries a one-line WHY (the repo's one use:
  `auto-update.nix` clearing the systemd timer's stock `OnCalendar` before setting its own schedule).
  reach for either only when a conflict is real, not to paper over structure.
- **derive interdependent structures from one filtered source set**, never maintain parallel literals that
  can silently disagree. `syncthing.nix` filters `realDeviceIds` once, then both `devices` (via
  `mapAttrs`) and `folderDevices` (via `attrNames`) flow from it, so a folder can't reference a device
  that doesn't exist.
- **eta-reduce forwarding lambdas** (statix `eta_reduction`):

  ```nix
  # good: filterAttrs passes (name: value), isReal takes the value
  realDeviceIds = lib.filterAttrs (_name: isReal) deviceIds;
  # bad
  realDeviceIds = lib.filterAttrs (_name: id: isReal id) deviceIds;
  ```

  do NOT reduce a lambda that builds an attrset (`name: id: { inherit id; addresses = ...; }` stays).
- **inherit-from instead of restating** (statix `manual_inherit_from`): `inherit (x) y;` not `y = x.y;`,
  `inherit foo;` not `foo = foo;`.

  ```nix
  # good
  qemu = (import inputs.nixpkgs-qemu { inherit (prev.stdenv.hostPlatform) system; }).qemu;
  # statix prefers, when the whole value is pulled through unchanged:
  inherit ((import inputs.nixpkgs-qemu { inherit (prev.stdenv.hostPlatform) system; })) qemu;
  ```

- **no top-of-file `with`** (defeats static analysis). pull names with `inherit (lib) ...` or `let ... in`.
  reserve `rec` for the `mkDerivation { pname; version; }` idiom (its only current uses, all in `pkgs/`),
  not module/config files.

## custom options: the `rice.*` namespace

a custom option is an API surface. it costs a declaration, a type, a description, and a wiring site.

- **add an option only when the value is set in one layer and read in another, varies per host, or needs a
  typed contract.** `rice.backup` earns it (read by the script generator + both restic shims, set per host
  with different repo paths). inline a literal used exactly once in one file (starship's palette is inlined
  for this reason).
- **canonical module shape**, no exceptions for anything with an on/off switch:

  ```nix
  let
    cfg = config.rice.<name>;
  in
  {
    options.rice.<name> = {
      enable = lib.mkEnableOption "<what it does>";
      <opt> = lib.mkOption {
        type = lib.types.<t>;
        default = <safe choice>;
        description = "Sentence case, trailing period.";
        example = "/Volumes/EASYSTORE/restic-repo"; # add when the value is a magic path
      };
    };
    config = lib.mkIf cfg.enable { ... };
  }
  ```

- **one top-level `config = lib.mkIf cfg.enable`** gates the module. do not scatter per-option `mkIf` for
  the enable switch.
- **every `mkOption` has a type and a description.** add an `example` for magic paths or non-obvious
  strings. option descriptions are sentence-case with a trailing period; inline code comments stay
  lowercase. the default encodes the safe choice.
- options are typed `readOnly` mirrors where they expose shared data (`rice.theme.colors`), so modules read
  `config.rice.theme.colors` instead of re-importing the raw attrset.

## cross-platform modules

a module imported by both `desktop-darwin` and `desktop-linux` (or living in `modules/shared`) must
evaluate on every platform.

- **select option SHAPE from `options`, select VALUES from `pkgs.stdenv.hostPlatform`.** this is the
  trickiest pattern in the repo and `auto-update.nix` is the reference. a cross-platform module that sets
  `launchd.daemons` (darwin-only) or `system.autoUpgrade` (nixos-only) must NOT place a wrong-platform
  option path into the config tree, even under `mkIf false`: the module system validates the path before
  evaluating the condition.

  ```nix
  # good: probe options for shape (resolved before pkgs is forced)
  onDarwin = options ? launchd;
  config = if onDarwin then { launchd.daemons.x = ...; } else { systemd.services.x = ...; };
  isDarwin = pkgs.stdenv.hostPlatform.isDarwin; # ONLY for lazy values inside a chosen branch
  ```

  never branch which option paths get set on a `pkgs.*` predicate: pkgs depends on resolved config, so you
  get infinite recursion. and `mkIf false` does NOT hide an unknown option path.
- for **value-level** platform branching, the house idiom is a let-binding plus `optionals`/`mkIf`:
  `isDarwin = pkgs.stdenv.hostPlatform.isDarwin;` then gate the bits. path branching:
  `if isDarwin then "/Users/${username}" else "/home/${username}"`.
- **guard darwin-only home-manager `launchd.agents` with `lib.mkIf pkgs.stdenv.hostPlatform.isDarwin`** so
  the module still evaluates on nixos. modules imported only from a darwin profile (`autoraise.nix`,
  `music-presence.nix`) skip the guard.
- split into separate files **only when the model genuinely differs** (`restic-darwin.nix` launchd vs
  `restic-linux.nix` systemd). a thin platform split that only differs by a mount path should fold to one
  `isDarwin` branch (mirror `sops.nix`).

## home-manager

- **prefer a `programs.<name>` module over hand-writing its config** into `home.file`/`xdg.configFile`. the
  module knows the path, format, and reload semantics. before adding a `home.file`, grep the hm options for
  a `programs.*` equivalent. `home.file`/`xdg.configFile` appear in this repo only where no module exists
  (sketchybar, `.stignore`, Mozilla manifests).
- **one path, one manager.** a `home.file` key must not target a path a `programs.*` module also writes
  (hard activation collision).
- **`xdg.configFile` for anything under `~/.config`; `home.file` only for paths genuinely elsewhere** in
  `$HOME` (`~/Library`, `~/.something`). never write `"${config.home.homeDirectory}/.config/..."` as a
  file key, use `config.xdg.configHome`.
- **back files with store paths** (`source = ../path`, `writeText`, `writeShellScript`,
  `recursive = true` for dirs). `mkOutOfStoreSymlink` only for a deliberate, commented dev-loop file. the
  repo uses none, on purpose (it's a public mirror, reproducibility is the point).
- when **catppuccin overlaps a hand-tuned `programs.<prog>.settings`**, set
  `catppuccin.<prog>.enable = false` rather than fighting it with `mkForce` (see `starship.nix`).
- reference theme colors **by semantic catppuccin name through the `theme` specialArg**
  (`theme.palette.mauve`), never raw hex. even `fastfetch.nix`, whose key format wants a raw SGR body,
  derives it from `theme.palette` via a `hexToRgb` helper rather than hardcoding rgb. the one deliberate
  inline hex is the contained Copland cold-blue (`#5a8ad0`) in `nushell.nix`'s connect ritual, the single
  place that second register is allowed, and it is commented as such.

### launchd and activation

- **per-user GUI/login services -> home-manager `launchd.agents` (`.config`)**. root/privileged/
  login-independent services -> nix-darwin `launchd.daemons` (`.serviceConfig`). never put a user agent in
  nix-darwin or a root daemon in home-manager; the attribute key even differs. the one privileged service
  here (the hourly nixfiles auto-updater) is a `launchd.daemons` because only root can activate a
  generation.
- **never hand-install a plist.** feed the agent a script package built in a cross-platform module
  (`rice.backup.command` via `writeShellScript`).
- **comment every non-obvious launchd flag.** `music-presence.nix` documents why `KeepAlive` must stay
  false (`open` forks and returns 0, `KeepAlive=true` would relaunch-loop). a job whose launcher forks and
  exits with `KeepAlive=true` is a relaunch loop, forbidden.
- launchd agents set both `StandardOutPath` and `StandardErrorPath` to the same single
  `~/Library/Logs/<name>.log`.
- **`home.activation` only for side effects nix cannot express declaratively.** if `home.file`/`programs.*`
  could do it, do it there. any block that writes or deletes is `entryAfter ["writeBoundary"]` (or after
  the named block producing its input, e.g. `entryAfter ["sops-nix"]`), is idempotent (safe to run on the
  second switch), and carries a WHY comment. use `run` for user-visible steps.

  ```nix
  home.activation.screenshotsDir = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    run mkdir -p "${config.home.homeDirectory}/workspace/screenshots"
  '';
  ```

## nix-darwin system layer

- **`system.primaryUser` is set once from the `username` specialArg** in `modules/darwin/system.nix`. since
  activation runs as root, it owns every per-user `system.defaults`/activation effect. never hardcode a
  username, never expect per-user defaults to target anyone else.
- **`system.stateVersion` is a deliberate compatibility pin, not a "latest" field.** it is an int (`6`) on
  darwin. do not conflate it with nixos `system.stateVersion` / `home.stateVersion`, which are strings
  (`"25.11"`). bump only after reading `darwin-rebuild changelog`, with a one-line WHY.
- **homebrew is for casks/brews nix cannot build.** nix-darwin runs `brew bundle` at activation, so casks
  are imperative, version-floating, not in the closure, not rolled back. keep `onActivation.upgrade = false`
  and `autoUpdate = false`. `cleanup = "none"` is a deliberate non-default (non-destructive; `"zap"` would
  delete hand-installed brews) and should be commented as such. every cask with a quirk (notarization,
  kext, trust step) gets a one-line WHY or a `TODO(deploy)`.
- **prefer typed `system.defaults.*` keys.** drop to `CustomUserPreferences`/`CustomSystemPreferences` only
  for a domain with no typed option, and name the domain in a comment (the repo does this exactly once, for
  `com.apple.desktopservices`).
- **any postActivation that writes defaults must pair with `activateSettings -u`** (`|| true`) so changes
  apply without a logout. this is the #1 "my settings didn't apply" foot-gun.
- **Touch-ID sudo** via `security.pam.services.sudo_local.touchIdAuth = true; reattach = true;`. never the
  deprecated `enableSudoTouchIdAuth`, never edit `/etc/pam.d/sudo` by hand.
- **`activationScripts` are reserved for steps with NO nix-darwin option.** every step is idempotent, ends
  in `|| true`, and states the missing/broken option (with issue ref) in a comment. order with
  `mkBefore`/`mkAfter` only with a comment explaining the dependency (coral's pmset block is `mkBefore`
  because home-manager's same-phase activation aborts on the headless launchctl error and would skip an
  `mkAfter` block). pin every binary to its store path (`${pkgs.coreutils}/bin/...`) so it doesn't depend on
  launchd's minimal PATH; OS-fixed binaries (`/bin/launchctl`, `/usr/bin/stat`, `/usr/sbin/ioreg`) use
  absolute paths.

## overlays and inputs

- two overlays: **`additions`** (custom pkgs, darwin-gated via
  `prev.lib.optionalAttrs prev.stdenv.hostPlatform.isDarwin`) and **`modifications`** (pinned/patched
  upstream: qemu, john, sif).
- **overlays are `(final: prev:)`.** use `prev` for the package/stdenv/lib you build on; reach for `final`
  only when you genuinely need the composed set. gate on `prev.stdenv`, not `final.stdenv`, or you recurse
  (the comment at `overlays/default.nix:3` says exactly this). underscore unused args.
- **every pin / `overrideAttrs` hash carries a one-line WHY plus a revert condition.** the qemu pin names
  the exact assert (`HV_SYS_REG_SMCR_EL1`), the macOS version, the symptom (crash-loops the linux-builder),
  and "revert when upstream fixes it". the input and the overlay that implement one workaround stay in sync.
- **dedupe nixpkgs: every structured input gets `inputs.nixpkgs.follows = "nixpkgs"`** unless it provably
  needs its own pin (then comment why, like `nixpkgs-qemu`). a new input without `follows` re-duplicates
  nixpkgs in `flake.lock` and the closure. plain source trees use `flake = false` with a one-line reason
  (`claude-config`).
- custom packages are **one `callPackage` per line** in `pkgs/default.nix`. darwin-only exposure gates on
  `stdenv.hostPlatform.isDarwin`, not per-system attr lists. `fetchFromGitHub` uses `tag = "v${version}"`
  when a `vN` tag exists, `rev = <commit>` with a WHY when it doesn't.

## secrets

this repo is a **public mirror**. treat one plaintext slip as an incident.

- **commit only sops ciphertext + the public recipients in `.sops.yaml`.** plaintext age keys, ssh private
  keys, `keys.txt`, decrypted netrc: all `.gitignored`. `.gitleaks.toml` is configured so a plaintext leak
  under `secrets/` still trips.
- every secret file is sops-encrypted via a **path-scoped `creation_rule`** in `.sops.yaml`. add a recipient
  by adding a named anchor and widening the rule's age list, never by loosening the path pattern.
- **consume secrets only as `config.sops.secrets.<name>.path`.** never interpolate cleartext into a string
  that can reach the nix store.
- every secret consumer (or its daemon) **fails loud/closed** when the key or secret is missing (mirror
  `sops.nix`'s `checkSopsAgeKey` activation and `auto-update.nix`'s no-op-until-materialized guard).
- a **headless/impermanence nixos host** (cuttlefish wipes `@` on boot) encrypts its boot/login secrets to
  its **ssh-host-key-derived age recipient** and decrypts via `sops.age.sshKeyPaths`. never gate a
  `neededForUsers` secret on a user-homedir age key, or you brick console login on the first wiped boot
  (PROVISIONING.md must-do #1).

## deploy

- thread cross-cutting context (`theme`, `inputs`, `outputs`, `username`, `hostname`) through
  `specialArgs`/`extraSpecialArgs`. modules read it as args, never re-import `theme.nix` or hardcode a
  username.
- deploy-rs: keep `magicRollback` + `autoRollback = true` for remote hosts. set `remoteBuild = true` when
  the origin can't realize the target arch (otter -> cuttlefish, x86_64). pass `--magic-rollback=false` only
  for a deploy that deliberately changes sshd/network.
- any deploy step nix can't perform (disk by-id, host key, TPM/secure-boot enroll, first password, a
  System Settings toggle) gets a `TODO(deploy)` marker at the exact site, plus a
  `hosts/<host>/PROVISIONING.md` runbook when it's multi-step. runbooks list the brick/lockout footguns
  FIRST, then numbered steps, then accepted tradeoffs.

## lint / eval gates

green before every commit, in this order:

1. **statix.** `(_name: id: isReal id)` -> `(_name: isReal)`, `y = x.y;` -> `inherit (x) y;`. a statix
   config that fails to parse is a CI outage, not a skip: a missing comma once made `statix check` a silent
   no-op in both `just lint` and CI. treat any linter-config parse error as a hard failure.
2. **deadnix --fail.** no unused let-bindings or args. underscore-prefix args you accept but don't use.
3. **treefmt/nixfmt.** `just fmt`. apply statix fixes first, then format (the fix can re-dirty the file).
4. **eval.** `just check` builds the actual host (CI's `check.yml` only checks formatting; `eval.yml` does
   otter + coral + cuttlefish drvPath). **never add an output to flake `checks` whose eval triggers IFD for a
   foreign system** (the macchiato variant's catppuccin IFD wanted x86_64; the wired variants have it off,
   but the rule stands): it re-breaks `nix flake check` on the aarch64 macs. route foreign-system eval
   through `just check` / CI drvPath and comment the IFD source.
5. **toolchain comes from the flake devShell**, never ambient PATH (`nixd`, `nixfmt`, `statix`, `deadnix`,
   `sops`), so local and CI are byte-identical.

CI lives in `.forgejo/workflows`: `check.yml` (treefmt), `eval.yml` (otter + coral + cuttlefish, push +
workflow_dispatch since it needs the secret token), `lint.yml` (statix + `deadnix --fail` + shellcheck, on
push + pull_request + workflow_dispatch).
