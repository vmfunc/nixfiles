{ pkgs, lib, ... }:
{
  home.packages =
    with pkgs;
    [
      ripgrep
      fd
      jq
      gitui
      gh
      just # command runner for justfiles (nixfiles' own justfile + ad-hoc ones)
      tree
      onefetch
      gitleaks
      age
      wget
      glow
      dust
      duf
      procs
      restic
      television
      ncspot
      spotify-player
      bottom
      lazydocker
      serie
      presenterm
      wiki-tui
      cmatrix
      pipes-rs
      nyancat # ambient terminal toy, next to cmatrix/pipes-rs
      terminal-parrot # the party parrot, because why not
      chafa # terminal image renderer (sixel/kitty/ansi); also powers yazi previews
      gallery-dl # yt-dlp's sibling for pixiv/twitter/imageboard/doujin galleries
      bun

      # everyday CLI sharpeners (rust/go, source-built, portable). ripgrep+fd are
      # already here; these fill the obvious gaps in the daily loop.
      sd # find/replace without sed's escaping tax; the third of rg/fd/sd
      hexyl # hex viewer; constant companion for poking at binaries
      xh # httpie-in-rust: curl-for-humans, for quick web pokes + recon
      jnv # interactive jq explorer (jq scripts, jnv spelunks)
      hyperfine # statistical command benchmarking
      tokei # LOC/language stats over a tree
      ouch # one verb (ouch d/c) for every archive format
      gping # ping with a live graph, several hosts at once
      croc # encrypted p2p file transfer between the fleet's boxes
      watchexec # re-run a command when files change
      difftastic # structural (AST) diff; reads code changes far better than line-diff
      dua # interactive disk-usage navigator (ncdu, but fast); dust stays for the static view
      mprocs # run several long processes side by side in one pane
      viddy # modern `watch`: diff-highlighted, scrollable history

      # cozy terminal toys, ambient Wired texture next to cmatrix/pipes/nyancat
      cbonsai # grow a bonsai in the terminal; --live for a slow unfurl
      asciiquarium # an ASCII aquarium
      genact # fake "compiling the mainframe" activity generator, peak Wired set-dressing

      # file / text / data tools
      broot # fuzzy filesystem tree navigator with built-in fs ops
      xplr # hackable, keyboard-driven file explorer tui
      csvlens # csv viewer tui, less-for-tables with search/filter
      qsv # blistering csv toolkit (join/stats/slice), rust xsv successor
      choose # human-friendly cut/awk replacement for field selection
      sad # batch find-and-replace across files with a diff preview
      ast-grep # structural code search/rewrite by syntax tree, not regex
      jless # json/yaml pager tui, fold and navigate huge blobs
      fq # jq for binary formats, query/decode media and packets
      heh # hex editor tui in rust, cleaner than xxd-in-vim

      # git / dev workflow tuis
      gitu # magit-inspired git tui, stage/commit/rebase from the keyboard
      jujutsu # git-compatible vcs (jj) with first-class stacked/undo workflow
      git-cliff # changelog generator from conventional commits
      git-absorb # auto-generate fixup commits into the right ancestor
      git-branchless # stacked-diff workflow, smartlog + undo on top of git

      # http / json / api clients
      hurl # http requests and assertions as plain-text files, ci-friendly
      slumber # terminal http/rest client tui backed by yaml collections
      atac # postman-like api client tui, offline and git-friendly
      websocat # netcat for websockets, connect/serve/pipe ws streams

      # system / process / disk
      gdu # fast parallel disk usage analyzer tui
      glances # cross-platform system monitor, one-glance everything

      # fuzzy / session
      skim # rust fuzzy finder (sk), fzf-compatible, usable as a library
      sesh # smart terminal session manager over zoxide + tmux/zellij

      # encryption / hashing
      rage # rust implementation of age, small clean file encryption
      minisign # dead-simple ed25519 file signing and verification
      b3sum # blake3 hashing cli, absurdly fast checksums
      rbw # unofficial bitwarden cli with an agent, no electron

      # docs / screenshots / demos (wired-flavored)
      gum # charm's glamorous shell-script primitives (input/choose/spin)
      vhs # script terminal sessions into gifs for docs and demos
      freeze # generate polished code/terminal screenshots
      ttyper # terminal typing-speed test with clean stats

      # task / queue tuis
      taskwarrior-tui # keyboard-driven front end for taskwarrior
      pueue # queue and run shell commands as a managed background daemon

      # cozy CLIs: pure writeShellApplications, portable across darwin + linux
      case
      mesh
      plan
      tama # terminal tamagotchi; state decays in real time, she never dies, only drifts into static
    ]
    ++ lib.optionals pkgs.stdenv.hostPlatform.isDarwin [
      # prebuilt aarch64-darwin binary, darwin-only
      linear-cli
      cinny-desktop
      ctf-new
      gate-check
      pvr-scan
      remind
      record

      r2mcp
      frida-mcp
      # pyghidra-mcp closure is huge; run on demand: nix run .#pyghidra-mcp -- <binary>

      # self-hosted forgejo CI runner (docker executor via colima)
      forgejo-runner
      colima
      docker-client
    ]
    ++ lib.optionals pkgs.stdenv.hostPlatform.isLinux [
      # hollywood's runtime deps pull jp2a, which is broken on darwin, so keep
      # this wired hacker-movie toy off the macs.
      hollywood
    ];
}
