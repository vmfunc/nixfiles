# nixfiles

> mirror. the canonical repo is [git.collar.sh/quaver/nixfiles](https://git.collar.sh/quaver/nixfiles); the github copy is read-only and may lag.

my nix-darwin + home-manager config. three hosts: otter (MacBook Pro) and coral
(M5 Pro), both aarch64-darwin macs, plus tuna, an x86_64-linux Framework Desktop
(Strix Halo) running niri on a bleeding-edge RE kernel. serial experiments lain
rice; theme variants (macchiato | copland | blood) live in `theme.nix`.

```sh
just switch   # rebuild + activate this host (nh picks the host by hostname)
just check    # fmt + per-host build gate
```

theme lives in `theme.nix`; one file per program under `home/modules/`.
architecture + rules in `CLAUDE.md`, the full nix style in `docs/nix-style.md`.
