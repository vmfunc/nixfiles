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
    key="$HOME/Library/Application Support/sops/age/keys.txt"

    ensure() { [ -f "$file" ] || { echo "plan: no $file yet (try: plan restore)" >&2; exit 1; }; }

    publish() {
      ensure
      cd "$dir" || exit 1
      grep -v '%hidden' .plan > plan.txt || true
      if grep -q '%hidden' plan.txt; then echo "plan: refusing, a %hidden line leaked" >&2; exit 1; fi
      if command -v age >/dev/null 2>&1; then age -r "$recipient" -o .plan.age .plan; fi
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
        $0 == hdr { print ins }
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
      push)
        shift
        ensure
        cd "$dir" || exit 1
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
        printf '  plan edit                         open it in your editor\n'
        printf '  plan push ["msg"]                 publish + commit + push\n'
        printf '  plan restore                      decrypt .plan.age -> .plan\n'
        ;;
      *) show ;;
    esac
  '';
}
