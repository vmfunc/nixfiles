# gaming / MMO setup (tuna)

the declarative half lives in `modules/nixos/gaming.nix` (launchers, proton-ge,
ntsync, steamos sysctls, vkbasalt, mangohud, runelite) and the two home modules
`home/modules/desktop/{vkbasalt,mangohud}.nix`. this doc is the *other* half:
the mods and shaders that live INSIDE a wine/proton prefix and cannot be nix
packaged. every step here is a one-time, stateful, in-prefix action. nix owns
the tooling; the prefix owns the mods.

reach a prefix with the tools nix already installed:
- steam titles (ffxiv via steam, pso2): `protontricks <appid> --gui`
- lutris / umu / xivlauncher: `winetricks` against that prefix, or the app's own
  wine settings.

---

## FFXIV (XIVLauncher)

`xivlauncher` is in the system set. first launch builds its own wine prefix at
`~/.xlcore` (game at `~/.xlcore/ffxiv/game`). log in with the square account;
Dalamud auto-installs.

### plugins (in-app, code-reviewed, low risk)

the goatcorp Dalamud framework + its main plugin repo are code-reviewed and have
no reported bans. install from inside the game with `/xlplugins`:

- **Penumbra** — mod loader. does NOT touch the real game files (redirects at
  runtime), so it is clean and reversible. this is the base every visual mod
  sits on.
- **Glamourer** — appearance/outfit overrides, pairs with Penumbra.
- **Mare Synchronos** — syncs your modded appearance to other Mare users.
- QoL worth having: **Simple Tweaks**, **mini cactpot solver**, **Chat2**,
  **Wondrous Tails Solver**, **Auto Retainer** (careful: retainer automation is
  a grayer area than the cosmetic set).

mods themselves (gear, textures, VFX) come from xivmodarchive / heliosphere and
import into Penumbra's mod directory. keep that dir on the fast NVMe, not a
network mount.

> automation note: XIV rotation-solver plugins exist in third-party Dalamud
> repos. they are NOT code-reviewed, they fall in the automation bucket SE bans
> for, and you asked to keep them off the WHM main. deliberately not set up here.

### ReShade shaders (in-prefix, gposingway)

two shader paths coexist on this box:

1. **vkbasalt** (already declarative) — CAS + reshade-fx at the vulkan layer,
   outside the game's dll space. launch ffxiv with `ENABLE_VKBASALT=1` in the
   xivlauncher env / steam launch options. `Home` toggles, `Shift_R+F12` is the
   mangohud key so they do not clash. good for cheap sharpening + color, no depth
   effects (no MXAO/DoF) because vkbasalt has no depth buffer.

2. **in-prefix ReShade + gposingway** — for the depth-aware community presets
   (proper AO, DoF, the gpose look). steps:
   - install ReShade **with addon support** into `~/.xlcore/ffxiv/game`
     (RESHADE_ADDON_SUPPORT=1). the reshade-linux installer script or the
     `gposingway-linux` tool (github.com/Kekemui/gposingway-linux) automates it.
   - the common failure is `d3dcompiler_47.dll`: install it into the prefix with
     `winetricks -q d3dcompiler_47`, then copy it into BOTH
     `~/.xlcore/ffxiv/game` and `~/.xlcore/wineprefix/drive_c/windows/system32`.
     without this, shaders fail to compile.
   - drop the **gposingway** zip (github.com/gposingway/gposingway) into the game
     dir, overwriting `ReShade.ini`.
   - xivlauncher auto-detects ReShade and sets the WINEDLLOVERRIDES itself. if
     using Dalamud too, set ReShade handling to "Hook OnPresent" in the
     Experimental tab so the ImGui overlay renders.

---

## PSO2 (JP, via the ARKS-Layer Tweaker)

no nix package for the game or the tweaker exists. `pso2tricks` (in the system
set) bootstraps it:

```
pso2tricks --tweaker          # pulls the tweaker into ~/pso2_files
pso2tricks -p ngs <pso2_bin>  # english patch (ngs | both)
```

run the tweaker under proton-ge via Heroic or umu (arks-layer's linux guide).
use the **GloriousEggroll** proton build (already the extraCompatPackage) — it
carries the file-read patch PSO2 needs. GameGuard (nProtect) tolerates proton
but is hostile to injected DLLs.

### mods (in game dir)

sources: nexusmods.com/phantasystaronline2newgenesis and pso2mod.com. the common
categories:
- **ReShade / graphics** — same story as XIV. use the addon build if a preset
  needs depth (most GShade-derived ones do). vkbasalt is the lower-risk option
  since it never injects into the game process.
- **texture / costume / skin mods** — swap files in the `pso2_bin/data` ICE
  archives with the tweaker's file-mod support.
- **UI / font mods** — replace the global fonts / UI textures (e.g. the line-height
  font fix). tweaker handles these.

GameGuard risk tiers, honestly: file-swap mods and vkbasalt are low risk (no
process injection). in-prefix ReShade injects a dll, which is a gamble. anything
that reads/writes game memory is an instant flag.

### automation (opt-in, `rice.pso2Macro`, off by default)

realistic PSO2 auto-rotation is not a plugin like XIV's; it is keystroke macros.
the wired-up method is `modules/nixos/pso2-macro.nix`, gated behind
`rice.pso2Macro.enable` (default OFF, not enabled on any host). turn it on:

```nix
rice.pso2Macro.enable = true;   # then just switch, then relogin (group)
```

that gives you `ydotoold` (hardened root systemd service), your user in the
`ydotool` group, `/dev/uinput` at boot, and a `pso2-attack-loop` command. bind it
in niri (`Scroll_Lock { spawn "pso2-attack-loop"; }`); it self-toggles and only
fires while a PSO2 window is focused.

WHY ydotool and not AutoHotkey-in-prefix: ydotool injects at the linux kernel
`/dev/uinput` layer, BELOW the wine/proton prefix, so the in-prefix anti-cheat
cannot see the injector (no in-prefix process, no memory access, no hooked API).
AHK runs inside the same NT namespace the anti-cheat scans, which is exactly where
it gets caught. this is niri/wayland-only; there is no X11 injection path here.

three things that will bite you:
- **gamescope hides the window.** tuna runs `gamescopeSession.enable = true`, so
  if PSO2 launches under gamescope, niri sees "gamescope", not the game, and the
  focus gate NEVER matches (the loop silently idles). launch PSO2 in plain proton
  (windowed/borderless, no gamescope), then run `niri msg --json focused-window`
  with the game up and paste its real app_id/title into `PSO2_MATCH` in the script.
- **keycodes are raw linux KEY_\* codes**, not characters. `30`=KEY_A etc. map
  them to your in-game binds with `sudo evtest`.
- **relogin after the first switch** so the `ydotool` group membership lands in
  your niri session (or `newgrp ydotool`), else the CLI gets EACCES on the socket.

anti-cheat, honest: current NGS moved off nProtect GameGuard onto Wellbia
(XIGNCODE3 lineage) around 2024, Global then JP. either way it runs Windows-side
inside the prefix, so host uinput is invisible to its tamper scan. BUT confirm JP
NGS even launches under proton first, JP's variant has historically been the
stubborn one; if the game itself will not boot under proton, the macro is moot.
the ban vector is NOT tamper detection, it is behavioral: metronome timing,
superhuman uptime, and player reports. the jitter + focus-gate blunt that but do
not erase it. solo, attended, short sessions only; never in group content or
anywhere other players can watch and report. it is a ToS violation regardless of
how undetectable the injection is. your account, your call.

> public-mirror note: this file and the module name ToS-violating automation under
> your handle in a world-readable tree. decide before pushing whether that belongs
> in the public mirror (rename, private overlay, or drop).

---

## OG MMOs

### RuneLite (Old School RuneScape) — declarative

`runelite` is in the system set, launch it directly. RuneLite IS the modded
client: plugins (the plugin-hub) are managed in-app, not by nix. nothing else to
do.

### osu! — declarative

`osu-lazer-bin` (in the gaming set) is the prebuilt lazer client. skins, rulesets
and tournament client are managed in-app. nothing else to do.

### Ragnarok Online — see docs/ragnarok.md

RO is a stateful wine/Lutris install (no nix package), so it has its own guide:
**docs/ragnarok.md**. short version: the most active 2026 server is **uaRO**
(pre-renewal, ~5k concurrent), installed via its official Lutris script; it is a
strict unmodified-client server (custom GRFs banned, EN built in). NovaRO is the
runner-up for the renewal crowd.

---

## making Steam look old (Millennium, `rice.steamOld`, off by default)

now wired, via the pinned `nixos-millennium` flake input and
`modules/nixos/steam-millennium.nix`, gated behind `rice.steamOld.enable`
(default OFF). turn it on:

```nix
rice.steamOld.enable = true;    # then just switch
```

that swaps `programs.steam.package` for the Millennium-loader build, so plain
`programs.steam.enable = true` (from gaming.nix) now boots Steam through
Millennium. then launch Steam and pick a retro skin (e.g. **Classic Steam
Library** for the 2013/2015 look) from the Millennium theme store under Steam >
settings. that skin choice persists in `~/.config/millennium/config.json`.

WHY it is default-off and why it is NOT auto-enabled:
- **it builds from source.** the module deliberately does NOT add nixos-millennium's
  third-party cachix (a machine-wide binary-cache trust root we do not pull in
  silently on a security box), so flipping it on means a one-time local build of
  the millennium loader + steam-fhs wrap. if you would rather pull prebuilt, add
  their cachix to `nix.settings.substituters` + `trusted-public-keys` by hand,
  after deciding you trust it.
- **it is fragile.** Millennium injects a loader into the self-updating Steam
  client, so a steam client update can transiently break the skin until Millennium
  catches up. revert is one line: set `rice.steamOld.enable = false`, switch, and
  Steam runs unmodified again.

zero-fragility alternatives that need none of the above:
- **old Big Picture**: add `-oldbigpicture` to Steam's launch flags.
- **legacy skins**: the non-CEF windows still honor skins in
  `~/.steam/steam/skins/`, selectable under Settings > Interface (does not touch
  the modern React library).

TODO(deploy): if you want the skin itself declarative too, package the
Classic-Steam-Library repo as a theme derivation (pname + `cp -r . $out`) and set
`programs.steam.theme` via the nixos-millennium home-manager module; left out for
now because the theme repo would not pin cleanly at setup time.

## retro / emulation (rice.retro)

`rice.retro.enable` (on for tuna) installs the emulation + retro-computing set:
retroarch (unified), dolphin-emu, pcsx2, ppsspp, melonds, scummvm,
dosbox-staging, plus cool-retro-term / blightmud / syncterm.

- **BIOS files** are stateful and not shipped by nix. pcsx2 wants a PS2 BIOS
  dump, dolphin runs bootless but wants Wii NAND for some titles, retroarch PS1
  cores want the PS1 BIOS. drop them in each emulator's system dir
  (`~/.config/PCSX2/bios`, retroarch's `system/`). dump from your own hardware.
- **cool-retro-term** ships gorgeous built-in CRT profiles (Default Amber /
  Green, IBM DOS, Apple ][). the amber one is the copland-OS look. a custom
  blood-palette profile is a GUI save inside the app (its profile format is a
  baked QML blob, not a config file), so tweak the sliders once and save.
- **blightmud** for text MUDs, **syncterm** for the BBSes still on telnet/ssh.

## overlays / tooling recap

- **mangohud** — perf HUD, themed to the blood palette. opt in per game with
  `mangohud %command%` (steam) or `MANGOHUD=1`. toggle `Shift_R+F12`.
- **vkbasalt** — shader layer. opt in with `ENABLE_VKBASALT=1`. toggle `Home`.
- **goverlay** — GUI if the hand-rolled mangohud/vkbasalt configs need visual
  tweaking. it writes the same conf files the nix modules render, so treat its
  output as scratch; fold anything you want to keep back into the nix modules.
- **protontricks / winetricks** — the prefix escape hatch every section above
  leans on.
