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

  # nu record literal of the wired identity table, from the one source in
  # wired-name.nix, so `wired` can't drift when a host is added or renamed.
  naviRecord =
    "{ "
    + lib.concatStringsSep ", " (
      lib.mapAttrsToList (host: name: ''"${host}": "${name}"'') config.rice.wiredNames
    )
    + " }";

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
      # eza's optional-WHEN flags (--hyperlink, --icons) greedily eat a following
      # path, so none of them may sit last; and carapace's eza spec types
      # --hyperlink as bool, so it must stay bare (=auto breaks completion while
      # typing). hence: --hyperlink bare up front, --icons pinned with =.
      ls = "eza --hyperlink --icons=auto --git --group-directories-first";
      ll = "eza -l --hyperlink --icons=auto --git --group-directories-first --header --git-repos";
      la = "eza -la --hyperlink --icons=auto --git --group-directories-first --git-repos";
      lt = "eza --tree --level=2 --icons=auto --git";
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
      # even a login nu gets no nix PATH (nothing like /etc/zprofile exists for nushell),
      # so put the profile dirs on PATH ourselves
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

      # hm session vars (EDITOR, FZF_*, NH_FLAKE, ...) only land in hm-session-vars.sh,
      # which only posix shells source, and nu is the only shell on these boxes. mirror
      # them from the one source so programs.* env exports actually reach a shell. values
      # carrying a "$" need posix expansion (hm's darwin TERMINFO_DIRS trick) and would
      # land as broken literals here, so those stay with the shells that can expand them.
      ${lib.concatStringsSep "\n" (
        lib.mapAttrsToList (n: v: "$env.${n} = ${lib.hm.nushell.toNushell { } (toString v)}") (
          lib.filterAttrs (_name: v: !(lib.hasInfix "$" (toString v))) config.home.sessionVariables
        )
      )}

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
      # catppuccin is OFF for the wired variants, so nushell's tables + syntax highlighting lose
      # their theme and fall back to the stock blue/green defaults (cold in the amber field).
      # drive color_config straight off theme.palette so every variant recolors. mauve = the gold
      # accent (headers/shapes), text = amber fg, subtext0/overlay1 = dim structure, red = rust.
      $env.config.color_config = {
        separator: '${theme.palette.overlay1}'
        leading_trailing_space_bg: { attr: n }
        header: { fg: '${theme.palette.mauve}' attr: b }
        empty: '${theme.palette.blue}'
        bool: '${theme.palette.peach}'
        int: '${theme.palette.text}'
        filesize: '${theme.palette.green}'
        duration: '${theme.palette.text}'
        date: '${theme.palette.yellow}'
        range: '${theme.palette.text}'
        float: '${theme.palette.text}'
        string: '${theme.palette.text}'
        nothing: '${theme.palette.overlay1}'
        binary: '${theme.palette.peach}'
        cell-path: '${theme.palette.text}'
        row_index: { fg: '${theme.palette.subtext0}' attr: b }
        record: '${theme.palette.text}'
        list: '${theme.palette.text}'
        block: '${theme.palette.text}'
        hints: '${theme.palette.overlay1}'
        search_result: { fg: '${theme.palette.base}' bg: '${theme.palette.mauve}' }
        shape_and: { fg: '${theme.palette.mauve}' attr: b }
        shape_binary: { fg: '${theme.palette.peach}' attr: b }
        shape_block: { fg: '${theme.palette.mauve}' attr: b }
        shape_bool: '${theme.palette.peach}'
        shape_closure: { fg: '${theme.palette.green}' attr: b }
        shape_custom: '${theme.palette.green}'
        shape_datetime: { fg: '${theme.palette.yellow}' attr: b }
        shape_directory: '${theme.palette.green}'
        shape_external: '${theme.palette.green}'
        shape_externalarg: { fg: '${theme.palette.green}' attr: b }
        shape_external_resolved: { fg: '${theme.palette.yellow}' attr: b }
        shape_filepath: '${theme.palette.green}'
        shape_flag: { fg: '${theme.palette.blue}' attr: b }
        shape_float: { fg: '${theme.palette.text}' attr: b }
        shape_garbage: { fg: '${theme.palette.text}' bg: '${theme.palette.red}' attr: b }
        shape_glob_interpolation: { fg: '${theme.palette.green}' attr: b }
        shape_globpattern: { fg: '${theme.palette.green}' attr: b }
        shape_int: { fg: '${theme.palette.mauve}' attr: b }
        shape_internalcall: { fg: '${theme.palette.green}' attr: b }
        shape_keyword: { fg: '${theme.palette.mauve}' attr: b }
        shape_list: { fg: '${theme.palette.green}' attr: b }
        shape_literal: '${theme.palette.blue}'
        shape_match_pattern: '${theme.palette.green}'
        shape_matching_brackets: { attr: u }
        shape_nothing: '${theme.palette.overlay1}'
        shape_operator: '${theme.palette.yellow}'
        shape_pipe: { fg: '${theme.palette.mauve}' attr: b }
        shape_range: { fg: '${theme.palette.yellow}' attr: b }
        shape_record: { fg: '${theme.palette.green}' attr: b }
        shape_redirection: { fg: '${theme.palette.mauve}' attr: b }
        shape_signature: { fg: '${theme.palette.green}' attr: b }
        shape_string: '${theme.palette.green}'
        shape_string_interpolation: { fg: '${theme.palette.green}' attr: b }
        shape_table: { fg: '${theme.palette.blue}' attr: b }
        shape_variable: '${theme.palette.mauve}'
        shape_vardecl: '${theme.palette.mauve}'
      }

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

      # the Wired, on demand. the SEL opening (Duvet, boa) then a koan. sincere, the uncanny
      # edge intact, never winky.
      def lain [] {
        let a = '${theme.palette.mauve}'
        let d = '${theme.palette.subtext0}'
        print $"(ansi { fg: $d })and you don't seem to understand(ansi reset)"
        print $"(ansi { fg: $a })a shame you seemed an honest man(ansi reset)"
        print $"(ansi { fg: $d })and all the fears you hold so dear(ansi reset)"
        print $"(ansi { fg: $a })will turn to whisper in your ear(ansi reset)"
        print ""
        print $"(ansi { fg: $d })no matter where you go, everyone's connected.(ansi reset)"
      }

      # the end-card, on demand. the capital E in nExt is canon, do not normalize it.
      def close [] {
        print $"(ansi { fg: '${theme.palette.mauve}' })Close the World,  Open the nExt(ansi reset)"
      }

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
          # `first` on an empty result returns nothing (no error to catch), so coerce it
          ^nix-locate --minimal --whole-name --type x $"bin/($cmd)" | lines | first | default ""
        } catch { "" })
        if (($attr | default "") | str trim | is-empty) {
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
        # the connect ritual: RARELY (1 in 8 fresh shells) stage jacking into the Wired before
        # anything else. the contained Copland cold-blue (#5a8ad0) lives ONLY here, the one place
        # the second register is allowed, it never bleeds into the crimson machine elsewhere.
        if ((random int 0..7) == 0) {
          let b = "#5a8ad0"
          print $"(ansi { fg: $b })connecting to the wired ...(ansi reset)"
          sleep 320ms
          for i in 1..14 {
            # `repeat` lives in std (never imported here); `fill` is a builtin on plain nu
            let fill = ("" | fill --width $i --character "█")
            let rest = ("" | fill --width (14 - $i) --character "░")
            print -n $"(char cr)(ansi { fg: $b })  [($fill)($rest)] layer 07(ansi reset)"
            sleep 55ms
          }
          print ""
          sleep 150ms
          print $"(ansi { fg: $b })  protocol 7  //  layer 07  established(ansi reset)"
          print ""
        }
        # the Navi murmurs the show's end-card ONCE a day (first shell), dim and sincere,
        # the eerie opening laugh intact. a diegetic event, never a plastered banner.
        let _pdpt = $"($env.HOME)/.cache/rice-pdpt"
        let _today = (date now | format date "%Y-%m-%d")
        if ((if ($_pdpt | path exists) { open $_pdpt | str trim } else { "" }) != $_today) {
          $_today | save -f $_pdpt
          print $"(ansi { fg: '${theme.palette.overlay1}' })present day, present time.  hahaha.(ansi reset)"
          print ""
        }
        # the Navi names the connection it IS, dim, before its own readout. cosmetic
        # only, the real nix hostname is untouched. ${config.rice.wiredName} is the
        # host's wired name (NAVI / CYBERIA / PROTOCOL7).
        print $"(ansi { fg: '${theme.palette.overlay1}' })connected to ${config.rice.wiredName}(ansi reset)"
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
        # a rare Wired murmur (1 in 6), sincere and rueful, the surveillance/isolation read,
        # never cheerful. the machine is lonely and it's letting you hear it, just barely.
        if ((random int 0..5) == 0) {
          let _w = ([
            "no matter where you go, everyone is connected."
            "if you aren't remembered, then you never existed."
            "i'm always here. i'm always watching over you."
            "the line between here and the wired is thin tonight."
          ] | shuffle | first)
          print $"(ansi { fg: '${theme.palette.overlay1}' })   ($_w)(ansi reset)"
        }
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

      # the machine pings when a LONG command finishes (>20s): a soft DONE rise on a clean
      # exit, a low FAIL buzz on error. sparse by design, the build-finished-while-you-
      # stepped-away ping, never a per-command chirp. afplay is backgrounded so the prompt
      # never blocks on the tone.
      # the timestamp travels as epoch seconds in a plain string: env vars are stringified
      # into child process environments, so a nested shell inheriting a datetime value would
      # type-error on every prompt, and an erroring hook never gets to reset the var. the
      # try/catch turns stale or foreign values into "no start time" instead of wedging the
      # session (long-lived parents keep exporting the old format until they die).
      $env.config.hooks.pre_execution = (
        ($env.config.hooks.pre_execution? | default [])
        | append {|| $env.WIRED_CMD_START = (date now | format date "%s") }
      )
      $env.config.hooks.pre_prompt = (
        ($env.config.hooks.pre_prompt? | default [])
        | append {||
          let st = ($env.WIRED_CMD_START? | default "")
          $env.WIRED_CMD_START = ""
          let start = (try { $st | into int } catch { 0 })
          if ($start > 0) and (((date now | format date "%s" | into int) - $start) > 20) {
            let tone = (if $env.LAST_EXIT_CODE == 0 {
              '${pkgs.wired-sound}/share/wired-sound/done.wav'
            } else {
              '${pkgs.wired-sound}/share/wired-sound/fail.wav'
            })
            ^bash -c $"/usr/bin/afplay -v 0.30 '($tone)' >/dev/null 2>&1 &"
          }
        }
      )

      # the ambient soundbed: `hum` toggles it, `hum lines` / `hum crt` switch texture,
      # `hum off` stops it. the room humming under the wires (barely-there on purpose).
      def hum [mode?: string] {
        ^${pkgs.wired-sound}/bin/wired-hum ($mode | default "toggle")
      }

      # `wired`: jack into a Copland-OS readout on demand. node identity + which of your Navi
      # are alive on the tailnet. replaces the disabled AFK kiosk with something you'd run.
      def wired [] {
        let accent = '${theme.palette.mauve}'
        let dim = '${theme.palette.subtext0}'
        let txt = '${theme.palette.text}'
        let navi = ${naviRecord}
        let me = (^hostname | str trim | str downcase | split row "." | first)
        let myname = (if ($me in $navi) { $navi | get $me } else { $me | str upcase })
        let up = (try { sys host | get uptime } catch { "?" })
        print $"(ansi { fg: $accent })||  COPLAND OS ENTERPRISE  //  EXTERNAL WIRED INTERFACE  ||(ansi reset)"
        print ""
        print $"(ansi { fg: $dim })  NODE   (ansi reset)(ansi { fg: $accent })($myname)(ansi reset)  (ansi { fg: $dim })($me)(ansi reset)"
        print $"(ansi { fg: $dim })  UPTIME (ansi reset)($up)"
        if (which tailscale | is-not-empty) {
          print ""
          print $"(ansi { fg: $dim })  THE WIRED(ansi reset)"
          let res = (do { ^tailscale status } | complete)
          if $res.exit_code == 0 {
            for l in ($res.stdout | lines) {
              let cols = ($l | split row " " | where ($it | str length) > 0)
              if ($cols | length) >= 2 {
                let h = ($cols | get 1 | str downcase | split row "." | first)
                let nm = (if ($h in $navi) { $navi | get $h } else { $h | str upcase })
                let online = (not ($l | str downcase | str contains "offline"))
                let dot = (if $online { $accent } else { $dim })
                let mark = (if $online { "online" } else { "offline" })
                print $"    (ansi { fg: $dot })●(ansi reset) (ansi { fg: $txt })($nm)(ansi reset)  (ansi { fg: $dim })($mark)(ansi reset)"
              }
            }
          }
        }
      }

    ''
    + lib.optionalString (!isDarwin) ''
      # novel drives the emacs daemon (the tuna-only editor module), so it is LINUX-
      # gated (a darwin box has no daemon to talk to; the macs use neovim).

      # novel <file.epub>: read an EPUB in a nov-mode buffer (auto-mode on .epub).
      def novel [file: path] {
        let f = ($file | path expand)
        ^emacsclient -t -e $'(find-file "($f)")'
      }
    '';
  };
}
