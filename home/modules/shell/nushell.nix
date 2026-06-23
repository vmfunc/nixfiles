{
  config,
  pkgs,
  lib,
  theme,
  username,
  ...
}:
let
  isDarwin = pkgs.stdenv.hostPlatform.isDarwin;

  pathDirs = [
    "'/run/wrappers/bin'"
    "$'($env.HOME)/.nix-profile/bin'"
    "'/etc/profiles/per-user/${username}/bin'"
    "'/run/current-system/sw/bin'"
    "'/nix/var/nix/profiles/default/bin'"
    "$'($env.HOME)/.local/bin'"
    "$'($env.HOME)/.cargo/bin'"
    "$'($env.HOME)/go/bin'"
    "$'($env.HOME)/.bun/bin'"
  ]
  ++ lib.optionals isDarwin [
    "'/opt/homebrew/bin'"
  ];
in
{
  programs.nushell = {
    enable = true;
    settings = {
      show_banner = false;
      edit_mode = "vi";
    };

    shellAliases = {
      ls = "eza --icons --git --group-directories-first --hyperlink";
      ll = "eza -l --icons --git --group-directories-first --header --git-repos --hyperlink";
      la = "eza -la --icons --git --group-directories-first --git-repos --hyperlink";
      lt = "eza --tree --level=2 --icons --git";
      cat = "bat";
      cd = "z";
      gs = "git status";
      omg = "git status"; # for the panicked moments
      oops = "git reset --soft HEAD~1";
      lg = "lazygit";
      backup = "restic backup ~/workspace";
      snaps = "restic snapshots";
    }
    // lib.optionalAttrs isDarwin {
      easystore = "cd /Volumes/EASYSTORE";
    };

    extraEnv = ''
      # wezterm doesn't launch a login shell, so put the nix profile dirs on PATH
      $env.PATH = (
        $env.PATH
        | (if ($in | describe) == 'string' { split row (char esep) } else { $in })
        | prepend [
            ${lib.concatStringsSep "\n            " pathDirs}
          ]
        | uniq
      )

      $env.MANPAGER = "sh -c 'col -bx | bat -l man -p'"
      $env.MANROFFOPT = "-c"

      $env.NH_FLAKE = $"($env.HOME)/mac-rice"

      # ssh via gpg-agent (Ledger auth subkey), uncomment once gpg.nix has the real keygrip
      # $env.SSH_AUTH_SOCK = (^gpgconf --list-dirs agent-ssh-socket | str trim)

      # transient prompt: past lines collapse to a single ❯ (must live in env.nu)
      $env.TRANSIENT_PROMPT_COMMAND = {|| $"(ansi { fg: '${theme.palette.mauve}' })❯ (ansi reset)" }
      $env.TRANSIENT_PROMPT_COMMAND_RIGHT = {|| "" }
      $env.TRANSIENT_PROMPT_INDICATOR = ""
      $env.TRANSIENT_PROMPT_INDICATOR_VI_INSERT = ""
      $env.TRANSIENT_PROMPT_INDICATOR_VI_NORMAL = ""
      $env.TRANSIENT_PROMPT_MULTILINE_INDICATOR = ""

      $env.RICE_SESSION = (random chars --length 8)
    ''
    + lib.optionalString config.rice.backup.enable ''

      $env.RESTIC_REPOSITORY = '${config.rice.backup.repository}'
      $env.RESTIC_PASSWORD_FILE = '${config.rice.backup.passwordFile}'
    '';

    extraConfig = ''
      $env.config.show_banner = false

      # a little serotonin
      def _affirm_line [] {
        [
          "good girl. you're doing so well 🦦"
          "rest now, little floret, your affini's got you"
          "you don't have to be strong here. just be cared for."
          "such a clever little thing, aren't you?"
          "you're safe, you're wanted, you're held 💜"
          "let me carry that one for you, petal"
          "no more pushing, you've earned your bloom"
          "you belong to something gentle now. breathe."
          "that's it. soft and slow. good floret."
          "your worth was never in the work, sweetpea"
          "you're allowed to be small and still be enough"
          "i've got you, and i'm not going anywhere"
          "blooming so prettily for me, aren't you? 🌸"
          "set it down, pet. you've done plenty."
        ] | shuffle | first
      }

      def affirm [] {
        print $"(ansi { fg: '${theme.palette.mauve}' })(_affirm_line)(ansi reset)"
      }

      def meow [] {
        let face = (["(=^･ω･^=)" "(ฅ^•ﻌ•^ฅ)" "(=ↀωↀ=)✧" "( ๑'ꀀ'๑)"] | shuffle | first)
        let pet = (["sweetpea" "little one" "petal" "kiddo" "pumpkin"] | shuffle | first)
        print $"(ansi { fg: '${theme.palette.pink}' })($face)  hi ($pet)~(ansi reset)"
      }

      def wip [] { git add -A; git commit -m "🚧 wip" }

      # companion mode: claude code as a warm conversational partner, not a coding agent
      def --wrapped chat [...args] {
        mkdir ~/notes
        cd ~/notes
        ^claude --settings '{"outputStyle":"companion"}' ...$args
      }

      # heal: gc the store + sweep onefetch markers, then a soft word
      def heal [] {
        print $"(ansi { fg: '${theme.palette.mauve}' })⟳ casting Benediction…(ansi reset)"
        ^nh clean all --keep 5 --keep-since 7d
        let markers = (glob /tmp/.onefetch-*)
        if ($markers | is-not-empty) { rm --force ...$markers }
        print $"(ansi { fg: '${theme.palette.green}' })✨ Medica III, you're topped off, quaver 🦦(ansi reset)"
        print $"(ansi { fg: '${theme.palette.subtext0}' })   (_affirm_line)(ansi reset)"
      }

      # rice.mode: you declare your state, nothing infers it; `mode clear` ends it
      def mode [state?: string] {
        let f = $"($env.HOME)/.cache/rice-mode"
        mkdir ($env.HOME + "/.cache")
        if ($state == null) {
          let cur = (if ($f | path exists) { open $f | str trim } else { "clear" })
          print $"(ansi { fg: '${theme.palette.mauve}' })you're in ($cur) mode, quaver(ansi reset)"
          return
        }
        match $state {
          "little" => { "little" | save -f $f
            print $"(ansi { fg: '${theme.palette.pink}' })softening it all down for you, little one. no big thoughts needed here 🌸(ansi reset)" }
          "focus" => { "focus" | save -f $f
            print $"(ansi { fg: '${theme.palette.mauve}' })clearing the noise. just you and the work, quaver.(ansi reset)" }
          "crisis" => { "crisis" | save -f $f
            print $"(ansi { fg: '${theme.palette.mauve}' })i'm right here, steady. one thing at a time, you're not alone in this.(ansi reset)" }
          "clear" | "off" | "none" => { rm -f $f
            print $"(ansi { fg: '${theme.palette.green}' })back to baseline. there you are, love.(ansi reset)" }
          _ => { print $"(ansi { fg: '${theme.palette.subtext0}' })modes: little · focus · crisis · clear(ansi reset)" }
        }
      }

      # bloom: private note jar in ~/.local/share/bloom, never committed or backed up
      def bloom [...note: string] {
        let dir = $"($env.HOME)/.local/share/bloom"
        mkdir $dir
        let j = $"($dir)/journal.md"
        if ($note | is-empty) {
          if ($j | path exists) { open --raw $j | lines | last 8 | str join (char nl) | print } else {
            print $"(ansi { fg: '${theme.palette.subtext0}' })the jar's empty, love, add a petal whenever you like.(ansi reset)" }
        } else {
          $"- ((date now | format date '%Y-%m-%d %H:%M')): ($note | str join ' ')(char nl)" | save -a $j
          print $"(ansi { fg: '${theme.palette.pink}' })tucked away. 🌸(ansi reset)"
        }
      }

      # every so often, after a command, a soft line floats up
      $env.config.hooks.pre_prompt = (
        ($env.config.hooks.pre_prompt? | default [])
        | append {||
          let r = (random int 1..40)
          if $r == 1 { meow } else if $r <= 4 { affirm }
        }
      )

      # name the package that provides a missing command (nix-index)
      $env.config.hooks.command_not_found = {|cmd|
        let attr = (try {
          ^nix-locate --minimal --whole-name --type x $"bin/($cmd)" | lines | first
        } catch { "" })
        if ($attr | str trim | is-empty) {
          $"(ansi { fg: '${theme.palette.subtext0}' })no ($cmd) here, and nix-index doesn't know it either, set it down? 🦦(ansi reset)"
        } else {
          $"(ansi { fg: '${theme.palette.mauve}' })($cmd) lives in ($attr | str trim), want it in packages.nix? 🦦(ansi reset)"
        }
      }

      # onefetch once per repo per session
      $env.config.hooks.env_change.PWD = (
        ($env.config.hooks.env_change.PWD? | default [])
        | append {|before, after|
          if ((".git" | path exists) and (which onefetch | is-not-empty)) {
            let mark = $"/tmp/.onefetch-($env.RICE_SESSION? | default 'x')-(($after | str replace --all '/' '%'))"
            if (not ($mark | path exists)) {
              try { ^onefetch; touch $mark } catch { }
            }
          }
        }
      )

      if ($nu.is-interactive) {
        ^fastfetch
        print ""
        let h = (date now | format date "%H" | into int)
        let msg = (
          if $h < 5 { "the small hours, quaver~ be gentle with yourself" }
          else if $h < 12 { "good morning, quaver, soft start, no rush" }
          else if $h < 17 { "afternoon, quaver~ how's it flowing?" }
          else if $h < 21 { "evening, quaver, you've done plenty today" }
          else { "getting late, quaver... save your work and rest soon, hm?" }
        )
        let otter = (["🦦" "(=ﾟωﾟ)ﾉ🦦" "꒰ᵔᵕᵔ꒱" "(・o・)つ🦦" "ᶠᶸⁿ"] | shuffle | first)
        print $"(ansi { fg: '${theme.palette.mauve}' })($otter)  ($msg)(ansi reset)"
        print $"(ansi { fg: '${theme.palette.subtext0}' })   (_affirm_line)(ansi reset)"
        let mf = $"($env.HOME)/.cache/rice-mode"
        let m = (if ($mf | path exists) { open $mf | str trim } else { "" })
        if $m == "little" { print $"(ansi { fg: '${theme.palette.pink}' })   little space, i've got you. no rush, nothing hard today 🌸(ansi reset)" }
        if $m == "crisis" { print $"(ansi { fg: '${theme.palette.mauve}' })   steady, love. i'm right here, one thing at a time.(ansi reset)" }
      }
    ''
    + lib.optionalString isDarwin ''

      # darwin-rebuild switch, with a little praise on a clean build
      def --wrapped switch [...rest] {
        try {
          sudo darwin-rebuild switch --flake ~/mac-rice ...$rest
          let praise = ([
            "that built clean, quaver ✨"
            "nailed it~"
            "look at you go 🦦"
            "rebuilt and happy"
            "smooth as anything, petal"
          ] | shuffle | first)
          print $"(ansi { fg: '${theme.palette.green}' })🦦  ($praise)(ansi reset)"
        } catch {
          print $"(ansi { fg: '${theme.palette.red}' })🦦  mnnh, it didn't land clean, that's okay, let's read what it's telling us together(ansi reset)"
        }
      }
    '';
  };
}
