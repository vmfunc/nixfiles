# rust-cli: project CLAUDE.md

rust cli scaffold. conventions are baked into the toolchain; this is the pointer + project deltas.

## Read first

- **`~/.config/claude/rust-guide.md`**: the authoritative Rust conventions.
  This file is a pointer + the project-specific deltas, not a replacement.

## The rules that bite (from the guide)

- **Hierarchy:** correct > safe > clear > fast.
- **Errors:** `anyhow` for this binary (context chains via `.context()`),
  `thiserror` for any library crate you split out. `?` to propagate, never
  `let _ = ...` or a silent swallow. No `unwrap()` outside tests/`main` setup,
  and when you do, `expect("why this can't fail")` with a reason.
- **Toolchain (every commit):** `rustfmt`, `cargo clippy -- -D warnings`,
  `cargo test`, `cargo audit`. `cargo geiger` for unsafe-heavy work. All on PATH
  in the devShell. `rustflags = ["-D","warnings"]` is set in `.cargo/config.toml`.
- **unsafe is a contract.** Every `unsafe` block gets a `// Safety:` comment
  stating the invariant, scoped to exactly the lines that need it.
- **Security:** `subtle` for constant-time compares, `zeroize` for secret
  material, `.get(range)` over indexing on untrusted input, checked/saturating
  arithmetic on untrusted sizes (release wraps silently otherwise).
- **Limits:** fns ≤ 50 lines, nesting ≤ 4, params ≤ 6, files ≤ 800 lines.
  `pub(crate)` aggressively.

## Layout (grow into it)

```
src/main.rs        # thin: parse args, call run(), context the error
src/lib.rs         # if it grows a real API: public surface + re-exports
src/error.rs       # thiserror types once there's a library half
tests/             # integration tests via the public API
fuzz/              # cargo-fuzz targets (needs nightly + cargo-fuzz; not in the
                   #   default shell, add a nightly toolchain when you write one)
```

## Build / run

- `nix develop` (or direnv) → pinned stable toolchain + cargo-{audit,deny,nextest,geiger}.
- `cargo run -- --help`, `cargo nextest run`, `cargo clippy -- -D warnings`.
- Release profile (lto / codegen-units=1 / panic=abort / strip) is in `Cargo.toml`.
