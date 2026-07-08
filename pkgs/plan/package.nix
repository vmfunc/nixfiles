{
  writeShellApplication,
  coreutils,
  gnugrep,
  gawk,
  age,
  git,
}:
writeShellApplication {
  name = "plan";
  runtimeInputs = [
    coreutils
    gnugrep
    gawk
    age
    git
  ];
  text = ''
    dir="''${PLAN_DIR:-$HOME/plan}"
    file="$dir/.plan"
    recipient="age17p7gtew5du203m4g5wja9gfyahqhwqjh6zsnwq55g7fv2zecj9yqj86xfw"
    # tuna's host age key, so the linux box reads .plan.age with its OWN key
    # instead of holding a copy of the personal one. encrypt to both.
    recipient_tuna="age1ayf0hldrxg5zpz78pqjr5qjkxuz9z3lajn9atlhsel5krd3lncwqt6atr3"
    # sops age key: darwin puts it under Library, linux under XDG. use whichever exists.
    key="$HOME/Library/Application Support/sops/age/keys.txt"
    [ -f "$key" ] || key="''${XDG_CONFIG_HOME:-$HOME/.config}/sops/age/keys.txt"

    ensure() { [ -f "$file" ] || { echo "plan: no $file yet (try: plan restore)" >&2; exit 1; }; }

    publish() {
      ensure
      cd "$dir" || exit 1
      # public plan.txt shows live intent only: drop %hidden privates, every
      # done item (× bullet, wherever it sits), and the ✓ done section header.
      # the encrypted .plan.age below still carries the FULL .plan (done log
      # included), so nothing is lost, it just stays out of the world-readable view.
      grep -v '%hidden' .plan | grep -v '^[[:space:]]*×' | grep -v '^✓' > plan.txt || true
      if grep -q '%hidden' plan.txt; then echo "plan: refusing, a %hidden line leaked" >&2; exit 1; fi
      if command -v age >/dev/null 2>&1; then age -r "$recipient" -r "$recipient_tuna" -o .plan.age .plan; fi
    }

    # two-way, conflict-safe sync. the shared source of truth is the committed
    # .plan.age; local .plan is a working copy. we decrypt the committed blob
    # (old), pull, decrypt again (remote), and compare against local (mine):
    #   - no local edits   -> take remote (decrypt straight to .plan)
    #   - only local moved  -> publish + push
    #   - both moved        -> refuse, leave it for a human (no silent clobber)
    sync() {
      cd "$dir" || exit 1
      # tidy closed items to the bottom first, so the hourly tick is what makes
      # "reap periodically" happen; guarded so a box with no .plan yet skips it.
      [ -f "$file" ] && reap
      [ -f .plan.age ] || { echo "plan: nothing to sync (no .plan.age)"; return 0; }
      old="$(age -d -i "$key" .plan.age 2>/dev/null || true)"
      git pull --rebase --autostash -q 2>/dev/null || echo "plan: pull failed (offline or creds?)" >&2
      remote="$(age -d -i "$key" .plan.age 2>/dev/null || true)"
      mine="$(cat "$file" 2>/dev/null || true)"

      if [ -z "$mine" ] || [ "$mine" = "$old" ]; then
        if [ "$remote" != "$mine" ]; then
          age -d -i "$key" -o "$file" .plan.age && echo "plan: pulled remote changes"
        else
          echo "plan: up to date"
        fi
        return 0
      fi

      if [ "$remote" = "$old" ]; then
        publish
        git add -A
        if git -c commit.gpgsign=false commit -q -m "''${1:-plan: sync}"; then
          if git push -q 2>/dev/null; then echo "plan: pushed local changes"; else echo "plan: committed; push failed (creds?)"; fi
        else
          echo "plan: nothing to publish"
        fi
        return 0
      fi

      echo "plan: CONFLICT, both .plan and .plan.age changed since last sync." >&2
      echo "      inspect: diff <(age -d -i \"$key\" .plan.age) .plan" >&2
      return 1
    }

    show() {
      ensure
      awk '
        /^▶/      { print "\033[1;38;5;183m" $0 "\033[0m"; next }
        /^▷/      { print "\033[38;5;151m"   $0 "\033[0m"; next }
        /^~/      { print "\033[38;5;245m"   $0 "\033[0m"; next }
        /^✓/      { print "\033[38;5;110m"   $0 "\033[0m"; next }
        /%hidden/ { print "\033[38;5;211m"   $0 "\033[0m"; next }
        /^[[:space:]]*×/ { print "\033[38;5;245m" $0 "\033[0m"; next }
        { print }
      ' "$file"
    }

    add() {
      ensure
      bucket="next"
      case "''${1:-}" in
        doing | next | someday | done) bucket="$1"; shift ;;
      esac
      flag=""
      text=""
      for a in "$@"; do
        if [ "$a" = "--hidden" ]; then flag=" %hidden"; else text="''${text:+$text }$a"; fi
      done
      [ -n "$text" ] || { echo "usage: plan add [doing|next|someday|done] \"text\" [--hidden]" >&2; exit 1; }
      case "$bucket" in
        doing) hdr="▶ doing" ;;
        next) hdr="▷ next" ;;
        someday) hdr="~ someday" ;;
        done) hdr="✓ done" ;;
      esac
      bullet="·"
      [ "$bucket" = "done" ] && bullet="×"
      awk -v hdr="$hdr" -v ins="  $bullet $text$flag" '
        { print }
        # trailing whitespace on a section header (e.g. "▷ next  ") must not
        # defeat the match, else add silently no-ops while claiming success.
        { t = $0; sub(/[[:space:]]+$/, "", t) }
        t == hdr { print ins }
      ' "$file" > "$file.bak" && mv "$file.bak" "$file"
      echo "added to $bucket: $text$flag"
    }

    done_item() {
      ensure
      q="''${1:-}"
      [ -n "$q" ] || { echo "usage: plan done <substring>" >&2; exit 1; }
      if awk -v q="$q" '
        !hit && /^[[:space:]]*·/ && index($0, q) { sub(/·/, "×"); hit = 1 }
        { print }
        END { if (!hit) exit 3 }
      ' "$file" > "$file.bak"; then
        mv "$file.bak" "$file"
        echo "done: $q"
      else
        rm -f "$file.bak"
        echo "no open item matching: $q" >&2
        exit 1
      fi
    }

    # settle every done (× ) item into a ✓ done section at the bottom, so closed
    # work drops out of the live doing/next/someday buckets. idempotent: a second
    # run yields identical output, which is what keeps sync from churning once
    # things are tidy. any pre-existing ✓ done header is dropped and re-emitted.
    reap() {
      ensure
      awk '
        /^[[:space:]]*×/ { dones = dones $0 "\n"; next }
        /^✓/             { next }
        { keep = keep $0 "\n" }
        END {
          sub(/\n+$/, "\n", keep)
          printf "%s", keep
          if (dones != "") { print ""; print "✓ done"; printf "%s", dones }
        }
      ' "$file" > "$file.bak" && mv "$file.bak" "$file"
    }

    hook() {
      [ -f "$file" ] || exit 0
      out="$(awk '
        /^▶/ { sec = "doing"; next }
        /^▷/ { sec = "next"; next }
        /^~/ { sec = ""; next }
        /^✓/ { sec = ""; next }
        sec != "" && /^[[:space:]]*·/ {
          gsub(/^[[:space:]]*·[[:space:]]*/, "")
          print "  " sec ": " $0
        }
      ' "$file")"
      [ -n "$out" ] || exit 0
      printf 'azzie keeps a .plan (~/.plan, edit with the plan command). active right now:\n%s\n' "$out"
    }

    case "''${1:-show}" in
      show | ls | "") show ;;
      hook) hook ;;
      add | a)
        shift
        add "$@"
        ;;
      done | did | x)
        shift
        done_item "''${1:-}"
        ;;
      reap | tidy)
        reap
        echo "reaped closed items to the ✓ done section"
        ;;
      edit | e)
        ensure
        "''${EDITOR:-nvim}" "$file"
        ;;
      publish | pub)
        publish
        echo "published plan.txt + .plan.age"
        ;;
      restore)
        [ -f "$dir/.plan.age" ] || { echo "plan: no .plan.age to restore" >&2; exit 1; }
        age -d -i "$key" -o "$file" "$dir/.plan.age" && echo "restored $file"
        ;;
      sync)
        shift
        sync "$*"
        ;;
      push)
        shift
        ensure
        publish
        git add -A
        if git -c commit.gpgsign=false commit -q -m "''${*:-update plan}"; then
          git push -q && echo "published + pushed" || echo "committed; push failed (check creds)"
        else
          echo "nothing to publish"
        fi
        ;;
      -h | --help | help)
        printf 'plan -- your .plan: public view + age-encrypted privates\n'
        printf '  plan                              show it\n'
        printf '  plan add [bucket] "x" [--hidden]  bucket: doing|next|someday|done\n'
        printf '  plan done <substr>                mark an open item done\n'
        printf '  plan reap                         move done items to the bottom (auto on sync)\n'
        printf '  plan edit                         open it in your editor\n'
        printf '  plan push ["msg"]                 publish + commit + push\n'
        printf '  plan restore                      decrypt .plan.age -> .plan\n'
        printf '  plan sync ["msg"]                 pull remote + push local, conflict-safe\n'
        ;;
      *) show ;;
    esac
  '';
  meta = {
    description = "two-way-synced .plan editor (doing/next/someday/done), age-encrypts %hidden lines";
    mainProgram = "plan";
  };
}
