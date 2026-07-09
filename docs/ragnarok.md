# Ragnarok Online (tuna, wine/lutris)

the stateful half of running RO on tuna. no nix package for any RO client or
server exists (checked: no `grftool`, `grf`, `openkore`, RO client in nixpkgs),
so this is a wine install driven by the server's own launcher. nix owns the
tooling (lutris, wine-ge, winetricks, protontricks all come from
`modules/nixos/gaming.nix`), the wine prefix owns the game. every step below is
a one-time, in-prefix action. `modules/nixos/retro.nix` is intentionally NOT
touched for this (see the "why nothing declarative" note at the bottom).

RO private servers are the whole game here. official kRO/iRO is dead-ish; the
population lives on private servers. this doc picks one, installs it, and lists
the mods that server actually permits.

---

## which server (July 2026)

**pick: uaRO** (`uaro.net`, "UARO: World of Your Dream"). runner-up: **NovaRO**.

the population evidence, cross-checked across trackers, not vibes:

- **uaRO is #1 by live population.** ~5,091 concurrent online and ~31k Discord
  members as of July 2026, top of every tracker that measures real numbers
  (nostalgic.gg live-Discord counts, RMS listing, gtop100). it launched
  2025-04-29 and became the largest server, Pre-Renewal or Renewal, inside a
  year. that is the fastest population ramp in the current scene.
- it is **Pre-Renewal core with select Renewal content**, x5/x5/x5 rates
  (x7.5 weekends), classic "no warpers / no job changer / no healer NPC / no
  multi-client" old-school ruleset. community-tagged no-pay-to-win.
- the client is a **new DirectX 9 client with native GPU support** (a DirectX7
  fallback exists for ancient GPUs), which matters for wine: modern DX9 over
  wined3d/dxvk is a solved problem, unlike some ancient GDI-only clients.
- it has an **official Lutris install script** (lutris slug `uaro-uaro`, install
  id 39931) and the client ships **built-in EN / UA / RU language** selectable
  in-game via the Sorceress NPC. so it runs on linux with a documented path and
  needs no third-party English translation GRF.
- protected by **Gepard Shield 3.0** (anti-bot / anti-WPE/RPE/DLL-injection /
  node-delay). relevant to mods and botting below.

**why not the others.** NovaRO is the flagship low-rate **Renewal** server
(episode 17.x, third jobs, Rebellion/Kagerou-Oboro), long-running, stable ~800+
online, strong reputation, and it also has a Lutris script (`novaro`). it is the
right pick *if you want Renewal + 3rd jobs* instead of Pre-Renewal, which is the
only reason it is runner-up and not the pick: uaRO simply has the larger live
population right now and the classic ruleset. Shining Moon (ep 20 hybrid) and
the OldschoolRO family also chart high on nostalgic.gg but sit below uaRO on
concurrent players. DarkRO: Bloodshed is high-rate PvP, a different game. the
old names people remember (TalonRO, OriginsRO, RebirthRO) are still up but are
no longer the population leaders in 2026.

pick uaRO for "the biggest active classic RO right now". switch the target to
NovaRO if you specifically want Renewal, the install shape below is identical
(different lutris slug, same wine dependencies).

---

## install (lutris + wine)

lutris, wine-ge, winetricks and protontricks are already in the system set from
`rice.gaming`, do not install them by hand.

**1. system wine first.** lutris' own docs are explicit: have a system wine
present so all wine runtime deps resolve. it is already pulled in by the gaming
module. use the **wine-ge** runner in lutris (proton-ge's wine build, the same
`extraCompatPackage` the box already carries) rather than a random tkg build.

**2. run the official lutris script.** on lutris, search the uaRO installer
(slug `uaro-uaro`) or install from `https://lutris.net/games/uaro/`. the script
creates a **win64** prefix at the game dir and runs the server's own
`UaRo Patcher.exe` (it lands at
`drive_c/users/steamuser/AppData/Local/Programs/UaRO World of Your Dream/UaRo Patcher.exe`).
accept the recommended install path (user AppData). if you would rather not use
the community script, make a blank lutris wine prefix (win64, wine-ge runner)
and point it at the installer downloaded from `uaro.net` directly, the result is
the same prefix layout.

**3. winetricks verbs.** the uaRO patcher is a modern packaged launcher (a
`.NET`-era patcher living under `AppData\Local\Programs`), so the prefix wants:

```
winetricks -q dotnet48 vcrun2019 corefonts
# add if the patcher or OpenSetup throws a font/GDI+ error:
winetricks -q gdiplus
# only if a legacy DX7-path GPU fallback complains:
winetricks -q d3dx9
```

reasoning per verb:
- `dotnet48`: the patcher/launcher is .NET. this is the one that actually
  matters; a bare prefix hangs on the patcher without it. installing dotnet48
  under wine is slow, let it finish.
- `vcrun2019`: the VC++ runtime the client and Gepard link against
  (`vcrun2010` is the older equivalent some clients want; 2019 is the safe
  superset for a 2025-era client).
- `corefonts`: RO UI and OpenSetup render wrong / boxes-for-glyphs without the
  MS core fonts.
- `gdiplus`, `d3dx9`: only-if-it-breaks. do not front-load them.

**4. renderer: wined3d is fine, dxvk optional.** the uaRO client is DirectX 9.
plain wined3d handles RO's DX9/GDI mix without fuss and is the low-risk default.
dxvk works too and can be smoother on the Strix Halo iGPU, but adds a d3d9 dll
into the process space, which is exactly the kind of thing Gepard notices, so
**prefer wined3d first**. only flip dxvk on if you have a specific perf problem,
and test that Gepard still lets you log in afterward.

**5. no virtual desktop.** RO patchers and OpenSetup misbehave inside a wine
virtual desktop (resolution/fullscreen fights, mouse capture). leave "Emulate a
virtual desktop" OFF in wine config / lutris. run the game fullscreen or
borderless via OpenSetup instead (next section).

**6. Gepard Shield under wine.** Gepard 3.0 loads with the client. in practice
it tolerates a clean wine prefix (it is checking for injected DLLs, WPE/RPE
packet editors, and known bot signatures, not for wine itself). two rules keep
you logging in:
- do not inject anything into the process (no in-prefix ReShade dll, no dxvk
  unless you accept the risk, no overlays that hook d3d). use the **vulkan-layer**
  overlays instead: `mangohud` / `vkbasalt` sit below the game's dll space and
  are far safer than an injected d3d9 hook. still, the safest login is a naked
  client.
- Gepard sometimes flags host-side macro/keyboard software and pops a "remove
  macro tool" browser page. on linux that maps to nothing running, but if you
  have `ydotool`/`wtype` daemons or a keyboard-macro tool active, kill them
  before launching. see the botting line below, this is the same enforcement.

---

## OpenSetup (graphics / resolution)

RO resolution, renderer and windowing are NOT set in-game, they are set by
`OpenSetup.exe` (ships in the client folder next to the patcher/client exe).
run it through the same wine prefix once:

```
# from inside the prefix, via lutris "run EXE" or:
WINEPREFIX=<gamedir> wine "<gamedir>/.../OpenSetup.exe"
```

set:
- **Graphics API**: Direct3D 9 (the default; only drop to DirectX7 if the iGPU
  path glitches, which it should not on Strix Halo).
- **Resolution**: pick a native or scaled mode. RO's UI is fixed-size, so very
  high resolutions make the HUD tiny; 1920x1080 windowed/borderless is the sane
  default, bump only if you like small UI.
- **Windowed / Fullscreen**: borderless-windowed plays nicest with wayland/niri
  and alt-tab. true exclusive fullscreen can fight the compositor.

OpenSetup writes into the client folder / prefix registry, so it is stateful and
survives patches. re-run it if a patch resets the display config.

---

## mods (what uaRO actually allows)

read this before installing anything: **uaRO is a strict, unmodified-client
server.** the rules are explicit (Server_Rules 2.1-2.7):

- **2.1 custom GRFs are BANNED** ("Grayworld, DarkSide, etc."). the big QoL
  "everything" GRFs the wider RO scene passes around are not allowed here.
- **2.2 no client mod for gameplay advantage.**
- **2.3-2.5 no packet/visual bots, no timer/auto-clicker scripts
  (auto-feed/anti-afk/auto-hide), no skill-spam auto-clickers.**
- **2.6-2.7 no multi-client / multi-box** (dual-player household exception).

what that means concretely for mods:

- **English translation GRF: not needed and not wanted.** unlike a raw
  JP/kRO-based client, uaRO ships official EN/UA/RU language built in, selectable
  in-game at the Sorceress NPC. so the usual `zackdreaver/ROenglishRE`
  translation GRF (the thing you would load on a JP client via `data.ini`) is
  both unnecessary and a banned custom GRF here. use the built-in language.
- **QoL GRF (iteminfo/skill descriptions, damage numbers, clean UI): banned as a
  custom GRF.** whatever QoL the server wants you to have is baked into the
  official client already. do not side-load a QoL `.grf`.
- **custom sprite / skin packs: banned.** same rule, and Gepard can see a
  swapped `data.grf`/`rdata.grf` hash.
- the **only** sanctioned "mod" surface on uaRO is `OpenSetup` (resolution /
  renderer, above) and the official client's own settings. that is the whole
  legal mod list. it is a short list on purpose.

if you want the full custom-GRF modding experience (translation GRF loaded via
`data.ini`, damage-number GRFs, custom sprites, BGM packs), that lives on
servers that permit it (some low-population classic servers explicitly allow a
whitelist of client mods). uaRO is not one of them. picking uaRO is picking the
big-population strict-client experience; the trade is you play the client as
shipped.

### how GRF loading works (reference, for a server that DOES allow it)

so the mechanic is documented if you ever target a mod-friendly server: RO
reads a `data.ini` in the client root that lists `.grf` archives in priority
order, e.g.

```
[Data]
0=custom_translation.grf
1=rdata.grf
2=data.grf
```

lower index = higher priority = overrides the ones below. a translation/QoL mod
is just a `.grf` dropped in the client folder and prepended in `data.ini`. GRFs
are built/edited with **Windows** tools (GRF Editor, GRFbuilder, WARP) run under
this same wine prefix, there is no nix/native GRF tool (nixpkgs has none). again:
do NOT do this on uaRO, Gepard bans the modified client. this paragraph exists
so the mechanic is on record for a future mod-friendly target.

---

## botting

OpenKore (and every packet/macro bot) is against uaRO's ToS (rules 2.3-2.5) and
against essentially every RO server's ToS, and uaRO runs **Gepard Shield 3.0**
which detects and bans bots, packet editors (WPE/RPE), injected DLLs and macro
tools aggressively. not set up here, not recommended, your account eats a ban.
that is the whole botting section.

---

## why nothing declarative was added

`modules/nixos/retro.nix` is intentionally unchanged. RO on uaRO is a stateful
wine-prefix install driven entirely by the server's own `.NET` patcher +
Gepard, built through the official lutris script. a `writeShellScriptBin`
launcher that pre-seeds a WINEPREFIX would be fragile (the patcher path, the
winetricks verb set, and the Gepard tolerance all shift with client updates) and
would duplicate what the lutris script already does correctly. every tool the
install needs (lutris, wine-ge, winetricks, protontricks, mangohud, vkbasalt) is
already in the system set from `rice.gaming`. there is no RO/GRF package in
nixpkgs to surface. so the honest declarative footprint here is zero, and adding
a launcher would be busywork that rots on the next client patch.

TODO(deploy): first-time install is manual: run the uaRO lutris script, then
`winetricks -q dotnet48 vcrun2019 corefonts` in the prefix, then OpenSetup for
resolution. nothing to automate, this note is the one-time checklist.
