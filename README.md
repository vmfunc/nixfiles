# nixfiles

my nix-darwin + nixos + home-manager config. three hosts: otter and coral (macs,
aarch64-darwin) and cuttlefish (framework laptop 12, nixos). serial experiments
lain rice; theme variants (macchiato | copland | blood) live in `theme.nix`.

```sh
just switch   # rebuild + activate this host (nh picks darwin/nixos + host by hostname)
just check    # fmt + per-host build gate
just deploy   # atomic remote deploy of cuttlefish from otter (deploy-rs)
```

theme lives in `theme.nix`; one file per program under `home/modules/`.
architecture + rules in `CLAUDE.md`, the full nix style in `docs/nix-style.md`.
