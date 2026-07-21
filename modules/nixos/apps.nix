# desktop apps for the linux hosts (currently tuna). system-level so they land
# in PATH + get .desktop entries without threading each through home. the terminal
# rice (nvim, yazi, nushell, etc.) stays in home/; this is the GUI/creature-comfort
# layer. gaming is separate (modules/nixos/gaming.nix), llm too (llm.nix).
{ pkgs, inputs, ... }:
{
  environment.systemPackages =
    (with pkgs; [
      # chat
      vesktop # discord client (the mac runs this too)
      element-desktop # matrix
      cinny-desktop # matrix (the mac aerospace assigns "Cinny" to a workspace)
      signal-desktop
      telegram-desktop

      # claude code CLI. claude.nix only deploys the config bundle (CLAUDE.md,
      # skills, hooks); this is the actual `claude` binary.
      claude-code

      hyfetch # pride-flag fetch for repo screenshots (fastfetch lives in home)
      spotify
      # mpv moved to home/modules/desktop/mpv.nix (hand-tuned + the JP-tv pipeline)
      vlc
      imv # wayland image viewer
      gimp # raster editor
      prismlauncher # minecraft / modded launcher
      obs-studio # capture/stream
      qbittorrent

      # japanese media + immersion (the "watch japanese tv" + otaku stack).
      # hypnotix = point-at-a-JP-m3u IPTV channel-surfer (mpv-backed); streamlink
      # + yt-dlp + the tuned mpv (home layer) are the workhorse pipeline for NHK
      # World / youtube-live / catch-up. anime: ani-cli (TUI -> mpv), trackma
      # (anilist/MAL tracker), freetube (yt front-end). shortwave = JP net radio.
      hypnotix
      ani-cli
      trackma
      freetube
      shortwave
      # JP study: anki (SRS) + mecab (tokenizer) + mokuro/manga-ocr (manga OCR
      # for lookup/mining). anki is the SOURCE build (build-from-source rule);
      # the heavy rust+ts build comes substituted from hydra, so no local cost.
      anki
      mecab
      mokuro
      (python3.withPackages (ps: [ ps.manga-ocr ]))
      kanjidraw # draw-a-kanji-to-look-it-up

      # manga / doujin readers + more JP media clients
      komikku # GTK manga reader (tachiyomi-compatible sources)
      (kodi.withPackages (ps: [ ps.pvr-iptvsimple ])) # HTPC w/ EPG grid over a JP m3u

      # otaku niche: torrent TUI + creative tools
      nyaa # TUI client for the nyaa.si anime tracker (seedbox/legal context is yours)
      openutau # UTAU-compatible vocal synth
      inochi-creator # live2d-style 2D vtuber rig

      # net HUD (GUI): live traffic map, the most Navi-panel-looking tool in nixpkgs
      sniffnet

      # OCR + reading. normcap = select-any-JP-text-on-screen OCR (the native
      # yomitan/Capture2Text substitute, pairs with manga-ocr for what a browser
      # addon can't reach); mcomix = classic cbz/cbr doujinshi reader; manga-tui =
      # terminal manga reader/downloader; hakuneko = bulk manga scraper.
      normcap
      mcomix
      manga-tui
      hakuneko
      nhentai # leaf CLI downloader

      # doujin music / chiptune: schismtracker (impulse tracker) + furnace
      # (chiptune tracker, speaks the YM2612/PC-98 sound chips) to make it,
      # vgmstream (ripped game/eroge BGM formats) + deadbeef (the foobar2000-of-
      # linux: gapless, cue, chip formats) to hoard and play it.
      schismtracker
      furnace
      vgmstream
      deadbeef

      # synced mpv watch-parties: how the shut-in watches anime "together"
      syncplay

      keepassxc # local vault
      pavucontrol # pipewire mixer
      nautilus # a GUI file manager alongside yazi
      blueman # bluetooth GUI manager + tray applet
      bluetuith # bluetooth TUI, for the terminal
      wl-clipboard

      # niri/wayland desk niceties (screenshots + media keys already live in
      # home/modules/desktop/niri.nix; these are the gaps).
      hyprpicker # point-and-grab color picker, for ricing
      wl-screenrec # GPU-encoded wayland screen recorder (strix-halo vaapi); quick clips vs OBS
      imhex # GUI hex editor + pattern language, for RE work off the terminal
      mission-center # modern GUI system monitor (the task-manager view, over btop)
      zathura # keyboard-driven (vim-like) PDF/CBZ reader, terminal-first ergonomics

      # creative: audio / daw / synths / trackers
      ardour # pro multitrack daw, full source build
      lmms # pattern/piano-roll daw, no external deps
      surge-XT # open hybrid synth, huge preset library
      milkytracker # fasttracker ii style .xm/.mod tracker
      picard # musicbrainz-backed batch tag editor
      qpwgraph # pipewire graph patchbay (qt), routes everything

      # creative: image / vector / 3d / video
      inkscape # vector editor
      krita # digital painting, wayland-native
      blender # 3d modeling / sculpt / render
      darktable # raw photo develop + library
      aseprite # pixel art + sprite animation, built from source
      rnote # gtk4 vector notetaking / freehand, wayland
      gImageReader # tesseract ocr front-end for scans + screenshots
      kdePackages.kdenlive # nonlinear video editor

      # wayland / desktop utilities
      nwg-look # gtk theme/font/cursor picker for wlroots
      gammastep # night color-temperature shift, wayland redshift
      mpvpaper # play video as live wallpaper via mpv
      eww # yuck-scripted widgets/bars, ricing swiss army knife

      # system / hardware (strix halo)
      lact # amd gpu fan/clock/power control daemon + gui (needs lactd service to fully drive)
      amdgpu_top # radeon/apu usage + vram monitor, strix halo native
      gnome-disk-utility # partition + smart + image-write gui
      kdePackages.filelight # radial disk-usage map

      # media / reading
      amberol # minimal gtk4 music player, clean aesthetic
      foliate # gtk epub/mobi reader, wayland
      calibre # ebook library manager + convert, source build
      tuba # gtk4 mastodon/fediverse client

      # comms
      dino # modern xmpp client, gtk wayland
      fractal # gtk4 matrix client
      halloy # rust/iced irc client, wayland-native

      # jp study
      tagainijisho # japanese-english dictionary + kanji study
    ])
    ++ [
      # zen browser, azzie's daily driver (linux build from the flake input)
      inputs.zen-browser.packages.${pkgs.stdenv.hostPlatform.system}.default
    ];
}
