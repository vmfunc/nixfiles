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

### automation (you asked for this, PSO2 only)

realistic PSO2 auto-rotation is not a plugin like XIV's; it is keystroke macros.
the mechanism:

- install **AutoHotkey** into the SAME proton/wine prefix as the game
  (`protontricks <pso2-appid> -c "wine ahk_installer.exe"`, or drop a portable
  AHK build in the prefix). write an `.ahk` that loops your photon-art / normal-
  attack keybinds on a hotkey toggle. because it only sends keystrokes and never
  touches game memory or injects a dll, GameGuard sees ordinary input.
- lower-tech alternative: a wayland-level keystroke tool (`ydotool` / `wtype`)
  bound to a key, firing while the game window is focused. cruder, no per-window
  logic, but nothing runs inside the prefix at all.

the honest part, said once: keystroke macros are still against the PSO2 ToS.
enforcement on keystroke-only input is far lighter than on memory tools, but the
account risk is not zero. memory-editing / injection auto-play tools WILL get you
flagged, do not use those. your call, your account.

---

## OG MMOs

### RuneLite (Old School RuneScape) — declarative

`runelite` is in the system set, launch it directly. RuneLite IS the modded
client: plugins (the plugin-hub) are managed in-app, not by nix. nothing else to
do.

### Ragnarok Online — wine/lutris

no package. pick a private server (e.g. OriginsRO, uaRO) and install its client
through **lutris** (already installed):
- add the server's lutris install script, or a manual wine prefix pointed at the
  downloaded client.
- most RO clients are old 32-bit DirectX; `wine` + `dxvk` (or the built-in wined3d)
  is plenty. no proton-ge needed.
- `winetricks` the prefix for any missing vcrun/d3dx if the client complains.
- the client's own patcher (`Setup.exe` / `patcher.exe`) runs first-time; some
  servers ship a custom launcher that wants `.NET` (`winetricks dotnet48`).

---

## overlays / tooling recap

- **mangohud** — perf HUD, themed to the blood palette. opt in per game with
  `mangohud %command%` (steam) or `MANGOHUD=1`. toggle `Shift_R+F12`.
- **vkbasalt** — shader layer. opt in with `ENABLE_VKBASALT=1`. toggle `Home`.
- **goverlay** — GUI if the hand-rolled mangohud/vkbasalt configs need visual
  tweaking. it writes the same conf files the nix modules render, so treat its
  output as scratch; fold anything you want to keep back into the nix modules.
- **protontricks / winetricks** — the prefix escape hatch every section above
  leans on.
