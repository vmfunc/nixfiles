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
      # for lookup/mining). anki-bin is prebuilt (the source build is heavy).
      anki-bin
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
      keepassxc # local vault
      pavucontrol # pipewire mixer
      nautilus # a GUI file manager alongside yazi
      blueman # bluetooth GUI manager + tray applet
      bluetuith # bluetooth TUI, for the terminal
      wl-clipboard
    ])
    ++ [
      # zen browser, azzie's daily driver (linux build from the flake input)
      inputs.zen-browser.packages.${pkgs.stdenv.hostPlatform.system}.default
    ];
}
