# nixfiles

my nix-darwin + home-manager config. two hosts, both aarch64-darwin macs: otter
(MacBook Pro) and coral (M5 Pro). serial experiments lain rice; theme variants
(macchiato | copland | blood) live in `theme.nix`.

```sh
just switch   # rebuild + activate this host (nh picks the host by hostname)
just check    # fmt + per-host build gate
```

theme lives in `theme.nix`; one file per program under `home/modules/`.
architecture + rules in `CLAUDE.md`, the full nix style in `docs/nix-style.md`.
