# cheatsheet

the stuff you forget and want in one place: rebuild commands, open ports, keybinds,
and how to actually drive the software this config installs. tuna-centric (the niri
box); the mac-only bits are noted. for architecture + rules see `CLAUDE.md`, for the
gaming/JP/RE deep dives see `docs/gaming.md`, `docs/ragnarok.md`, `docs/nix-style.md`.

## rebuild + gates

| cmd | what |
|---|---|
| `just switch` | rebuild + activate this host (nh picks by hostname); shows a Discord rich presence ("Playing nixpkgs" -> the drv currently building) while it runs, fail-open if Discord is down |
| `just build` | build only, no activation |
| `just check` | treefmt check + this host builds clean |
| `just fmt` | nixfmt every nix file |
| `just lint` | statix + deadnix + shellcheck (mirrors CI) |
| `just scan` | gitleaks secret scan before pushing public |
| `just gc` | `nh clean all --keep 5 --keep-since 7d` |
| `just dev` | dev shell (nixd, nixfmt, statix, deadnix, nh, just, sops, age) |

always green before commit: `just fmt && just lint && just check`.

## opt-in toggles (rice.*)

set per-host (tuna in `hosts/tuna/default.nix`), most default off. current tuna state:

| option | state | what |
|---|---|---|
| `rice.gaming.enable` | on | steam + proton-ge + gamescope + gamemode + ntsync |
| `rice.retro.enable` | on | emulation (retroarch/pcsx2/np2kai...) + old-net toys |
| `rice.ime.enable` | on | fcitx5 + mozc-ut japanese input |
| `rice.mediaServers.manga.enable` | on | suwayomi manga server (tailnet-only) |
| `rice.steamOld.enable` | on | millennium-wrapped steam (builds from source) |
| `rice.pso2Macro.enable` | on | pso2 ydotool auto-attack macro (ToS-risk) |
| `rice.llm.enable` | on | local llm stack |

flip one, then `just switch`. steamOld reverting to `false` gives you plain steam back.

## open ports (tuna)

| port | proto | why | scope |
|---|---|---|---|
| 22 | tcp | ssh (key-only) | all interfaces |
| 22000 | tcp/udp | syncthing sync | all |
| 21027 | udp | syncthing LAN discovery | all |
| 1990, 2021 | udp | bambu lab printer SSDP discovery | all |
| 5353 | udp | mDNS/avahi (printer + host resolution) | all |
| 27036 | tcp | steam remote play | all (remotePlay.openFirewall) |
| 27031-27036 | udp | steam remote play | all |
| 4567 | tcp | suwayomi manga web UI | **tailscale0 only** |

llm (ollama) and suwayomi bind services listen locally / on the tailnet; only 4567 is
punched, and only on the tailnet. everything else the box needs rides tailscale.

## keybinds

niri (Mod = Super). the live searchable list is `Mod+/` (parsed from the config).

| key | action |
|---|---|
| `Mod+Return` | terminal |
| `Mod+Space` / `Ctrl+Space` / `Mod+D` | launcher (fuzzel) |
| `Mod+Q` | close window |
| `Mod+H/L` `Mod+J/K` | focus column left/right, window down/up (arrows too) |
| `Mod+Shift+H/L/J/K` | move column / window |
| `Mod+Shift+Up/Down` | focus workspace up/down |
| `Mod+Ctrl+J/K` | move column to workspace down/up |
| `Mod+Alt+J/K` | walk the workspace strip |
| `Mod+1..9` | focus workspace N |
| `Mod+Minus/Equal` | column width -/+ ; `Mod+Shift+` same for height |
| `Mod+R` | cycle preset column widths |
| `Mod+F` / `Mod+Shift+F` | maximize column / fullscreen window |
| `Mod+Alt+L` | lock (swaylock) |
| `Mod+Shift+E` | power menu |

in-app overlays / tools:

| key | app | note |
|---|---|---|
| `Shift_R+F12` | mangohud | toggle the HUD (needs `mangohud %command%` or `MANGOHUD=1`) |
| `Shift_R+F11` | mangohud | toggle logging |
| `Home` | vkbasalt | toggle shaders (needs `ENABLE_VKBASALT=1`) |
| `Scroll_Lock` | pso2-attack-loop | start/stop the macro (self-toggles); bind it in niri |

> IME conflict, known: fcitx5's default toggle is `Ctrl+Space`, which niri already
> binds to the launcher, so it won't reach the IME. rebind fcitx5's trigger (via
> `fcitx5-configtool`) to the physical 半角/全角 key or `Ctrl+Shift+Space`.

## gaming

- **steam / proton**: launch options worth knowing. `mangohud %command%` (HUD),
  `ENABLE_VKBASALT=1 %command%` (shaders), `gamemoderun %command%` (renice + gpu pin).
  proton-ge is the default compat tool; ntsync is on for the newer wine sync path.
- **pso2 (JP)**: `pso2tricks --tweaker` pulls the ARKS-Layer tweaker; `pso2tricks -p ngs <pso2_bin>`
  applies the english patch. run the tweaker under proton-ge via heroic/umu. auto-attack:
  `pso2-attack-loop` (paste the real window app_id into `PSO2_MATCH` first, and launch PSO2
  WITHOUT gamescope or the focus-gate never matches). ToS-risk, solo/attended only.
- **osu!**: `osu-lazer` (source build, not the -bin appimage). skins/rulesets in-app.
- **ragnarok (uaRO)**: see `docs/ragnarok.md`. lutris + wine, `winetricks dotnet48 vcrun2019 corefonts`.
- **emulators**: `retroarch` (unified), `pcsx2`/`dolphin-emu`/`ppsspp`/`melonds`, `np2kai` (PC-98),
  `openmsx`. VN/doujin runtimes: `renpy`, `onscripter`, `easyrpg-player`. BIOS files are yours to drop in.
- **steam-old skin**: steamOld is on, so steam boots through Millennium; pick "Classic Steam Library"
  from the Millennium theme store in-app for the 2013/2015 look.

## japanese media + immersion

- **watch JP tv**: `streamlink <url> best` pipes into mpv (NHK World is the free daily driver;
  geo-locked TVer/ABEMA/radiko need a JP tailscale exit-node). `hypnotix` to channel-surf a JP m3u.
  `mpv --profile=live <url>` for the low-latency profile.
- **anime**: `ani-cli` (TUI -> mpv), `trackma` (anilist/MAL), `freetube` (yt front-end),
  `syncplay` (synced watch-party).
- **manga**: `komikku` / `manga-tui` (readers), `hakuneko` (bulk dl), suwayomi server at
  `http://tuna:4567` over tailscale, `mcomix` for local cbz/cbr.
- **immersion mining**: in mpv, the `videoclip` script cuts audio+screenshot+sentence into an
  Anki card; `autosubsync` fixes fansub timing. `normcap` OCRs any JP text on screen; `mokuro`
  for manga. `anki` + `mecab` for the cards.
- **input**: fcitx5 + mozc-ut (net-slang + proper nouns). toggle key: see the IME conflict note above.

## useful commands / custom CLIs

- **plan**: `plan add [doing|next|done] "..."`, `plan done <substr>`, `plan edit` (the `.plan`).
- **case**, **mesh**: the cozy shell CLIs (cross-platform).
- **yt-dlp / gallery-dl**: video / image-gallery archivers (embed JP subs configured).
- **newsboat**: terminal RSS (add feeds in `home/modules/cli/newsboat.nix`).
- **nh**: `nh os switch`, `nh clean`. `sops` for secrets. `just gate` (darwin: disclosure tripwire over ~/pentest).

## cli toolbox (the daily rust/go set, all source-built)

- **files / nav**: `broot` + `xplr` (tree/file tuis), `sad` (find-replace w/ diff), `choose` (cut/awk),
  `ast-grep` (syntax-tree search/rewrite), `sd` (sed replacement), `sesh` (session manager).
- **data**: `jless`/`jnv` (json view/explore), `qsv`+`csvlens` (csv), `fq` (jq for binary formats),
  `hexyl`/`heh` (hex view/edit), `xh`+`hurl`+`slumber`+`atac` (http/api), `websocat` (websockets).
- **git**: `gitu` (magit-style tui), `jujutsu` (jj), `git-branchless` (stacked diffs), `git-absorb`
  (autofixup), `git-cliff` (changelog), `difftastic` (structural diff).
- **system**: `glances`+`bottom` (monitors), `gdu`+`dua`+`dust` (disk), `gping` (ping graph),
  `procs`, `mprocs` (multi-proc), `pueue` (job queue), `watchexec` (run-on-change), `viddy` (watch).
- **crypto**: `rage` (age), `minisign` (ed25519 sign), `b3sum` (blake3), `rbw` (bitwarden, no electron).
- **misc**: `croc` (p2p transfer), `ouch` (any archive), `hyperfine` (bench), `tokei` (loc), `skim` (fzf),
  `gum` (shell-script ui), `vhs`+`freeze` (terminal gifs/screenshots for writeups).
- **toys**: `cbonsai`, `asciiquarium`, `genact`, `hollywood` (linux), next to `cmatrix`/`pipes-rs`.

## creative / desktop apps (tuna)

- **audio / music make**: `ardour`+`lmms` (daws), `surge-XT` (synth), `milkytracker` (.xm/.mod),
  `qpwgraph` (pipewire patchbay), `picard` (musicbrainz tagging), `amberol` (minimal player).
- **image / vector / 3d / video**: `krita`+`inkscape`, `blender`, `darktable` (raw), `aseprite`
  (pixel art), `kdenlive` (video), `rnote` (freehand notes), `gImageReader` (ocr scans).
- **reading**: `foliate` (epub), `calibre` (library), `zathura` (pdf/cbz, vim keys), `mcomix` (cbr).
- **desktop / rice**: `eww` (widgets), `hyprpicker` (color pick), `gammastep` (night shift),
  `mpvpaper` (video wallpaper), `nwg-look` (gtk theming), `wl-screenrec` (screen record).
- **system**: `mission-center`+`amdgpu_top`+`lact` (monitors / amd gpu control, strix halo),
  `gnome-disk-utility`, `filelight` (disk map).
- **comms**: `dino` (xmpp), `fractal` (matrix), `halloy` (irc), `tuba` (fediverse).

## RE / security (tuna)

- **static/dyn**: `ghidra`, `rizin`/`cutter`, `radare2`, `gdb`+`gef`, `frida-tools`, `binwalk`.
  add-ons: `imhex` (GUI hex + pattern lang), `lief` (elf/pe/mach-o programmatic), `capa`
  (capability id), `flare-floss` (string deobf), `retdec`/`detect-it-easy` (decompile / packer id),
  `checksec` (hardening audit).
- **exploit-dev / ctf**: `pwninit` (patchelf libc + template), `radamsa` (mutation fuzz),
  `aflplusplus`/`honggfuzz` (coverage fuzzers). the `nix develop .#pwn` shell has pwntools et al.
- **forensics / malware**: `volatility3` (memory dumps), `sleuthkit` (disk/fs), `yara-x`,
  `trivy` (container/fs/sbom), `zsteg` (png/bmp stego).
- **mobile**: `jadx` (dex -> java), `apktool` (smali disassemble/rebuild).
- **net recon** (home/profiles/security.nix): `nmap`, `rustscan`, `ffuf`, `nuclei`, `tshark`/`termshark`.
  more: `mitmproxy`+`zap` (intercept proxies), `masscan`/`zmap` (mass scan), `netexec` (AD/smb sweep),
  `responder` (llmnr/nbt poison), `bettercap` (mitm swiss-army), `aircrack-ng` (wifi), `dalfox`+`wapiti`
  (web scanners), `whatweb` (fingerprint), `doggo` (dns), `interactsh` (OOB ear), `maigret` (osint).
- **net HUDs**: `sniffnet` (GUI traffic map), `trippy` (traceroute), `bandwhich` (per-proc bw),
  `wavemon` (wifi), `kmon` (kernel modules, pairs with the OOT LKM work).
- **kernel**: tuna runs `linuxPackages_testing` + a custom RE config (KPROBES/UPROBES/KGDB/BPF_LSM/ntsync/
  binderfs). `/proc/config.gz` is live (IKCONFIG_PROC). OOT modules: wired / wired_nvim / wired_banner.
