{
  writeShellApplication,
  coreutils,
  ripgrep,
  fd,
  git,
}:
writeShellApplication {
  name = "case";

  runtimeInputs = [
    coreutils
    ripgrep
    fd
    git
  ];

  text = ''
    set -euo pipefail

    mauve=$'\033[38;5;183m'
    subtext=$'\033[38;5;146m'
    green=$'\033[38;5;151m'
    reset=$'\033[0m'

    CASE_DIRS="''${CASE_DIRS:-$HOME/pentest/findings $HOME/ctf}"

    die() { printf '%s%s%s\n' "$mauve" "$1" "$reset" >&2; exit 1; }

    marker_for() {
      local dir="$1" f
      for f in notes/findings.md notes/notes.md notes.md; do
        [ -f "$dir/$f" ] && { printf '%s\n' "$dir/$f"; return 0; }
      done
      local hit
      hit=$(fd -t f -d 1 \
        -e md \
        '^(GHSA|ISSUE|PR|PREDISCLOSURE)-' \
        "$dir" 2>/dev/null | sort | head -n1 || true)
      [ -n "$hit" ] && { printf '%s\n' "$hit"; return 0; }
      return 1
    }

    phase_for() {
      local marker="$1" base done_n todo_n
      base=$(basename "$marker")
      case "$base" in
        *-SUBMIT-*|SUBMIT-*)         printf 'submit';   return ;;
        *-PREDISCLOSURE-*|PREDISCLOSURE-*) printf 'predisc';  return ;;
        *-DRAFT-*|DRAFT-*)           printf 'draft';    return ;;
        *-ISSUE-*|ISSUE-*)           printf 'issue';    return ;;
        *-PR-*|PR-*)                 printf 'pr';        return ;;
      esac
      done_n=$(rg -c --no-filename '^\s*- \[[xX]\]' "$marker" 2>/dev/null || true)
      todo_n=$(rg -c --no-filename '^\s*- \[ \]'    "$marker" 2>/dev/null || true)
      done_n=''${done_n:-0}; todo_n=''${todo_n:-0}
      if [ "$todo_n" -eq 0 ] && [ "$done_n" -gt 0 ]; then printf 'done'
      elif [ "$done_n" -eq 0 ]; then printf 'scaffold'
      else printf 'active'; fi
    }

    progress_for() {
      local marker="$1" done_n todo_n ver_n unver_n total
      done_n=$(rg -c --no-filename '^\s*- \[[xX]\]' "$marker" 2>/dev/null || true)
      todo_n=$(rg -c --no-filename '^\s*- \[ \]'    "$marker" 2>/dev/null || true)
      done_n=''${done_n:-0}; todo_n=''${todo_n:-0}
      total=$(( done_n + todo_n ))
      if [ "$total" -gt 0 ]; then
        printf '%d/%d' "$done_n" "$total"; return
      fi
      ver_n=$(rg -c --no-filename '^\s*VERIFIED\b'   "$marker" 2>/dev/null || true)
      unver_n=$(rg -c --no-filename '^\s*UNVERIFIED\b' "$marker" 2>/dev/null || true)
      ver_n=''${ver_n:-0}; unver_n=''${unver_n:-0}
      total=$(( ver_n + unver_n ))
      if [ "$total" -gt 0 ]; then printf '%d/%d' "$ver_n" "$total"; return; fi
      printf '—'
    }

    flag_or_cvss_for() {
      local marker="$1" flag cvss
      flag=$(rg --no-filename -o '[A-Za-z0-9_]+\{[^}]+\}' "$marker" 2>/dev/null \
        | tail -n1 || true)
      [ -n "$flag" ] && { printf '%s' "$flag"; return; }
      cvss=$(rg --no-filename -o 'CVSS:3\.1/[A-Z:/.]+`[^0-9]*([0-9]+\.[0-9])' \
        -r '$1' "$marker" 2>/dev/null | head -n1 || true)
      [ -n "$cvss" ] && { printf 'CVSS %s' "$cvss"; return; }
      printf '—'
    }

    pad() { printf '%-*s' "$2" "$1"; }

    cmd_ls() {
      local rows="" found=0 d sub marker mtime
      for d in $CASE_DIRS; do
        [ -d "$d" ] || continue
        while IFS= read -r sub; do
          [ -n "$sub" ] || continue
          marker=$(marker_for "$sub" || true)
          [ -n "$marker" ] || continue
          found=1
          mtime=$(stat -f '%m' "$marker" 2>/dev/null || stat -c '%Y' "$marker" 2>/dev/null || echo 0)
          rows+="$mtime"$'\t'"$sub"$'\t'"$marker"$'\n'
        done < <(printf '%s\n' "$d"; fd -t d -d 1 . "$d" 2>/dev/null)
      done

      if [ "$found" -eq 0 ]; then
        printf '%sno cases found.%s %slooked in: %s%s\n' \
          "$mauve" "$reset" "$subtext" "$CASE_DIRS" "$reset"
        printf '%s   start one:%s case new <name>%s\n' "$subtext" "$mauve" "$reset"
        return 0
      fi

      printf '%s%s  %s  %s  %s%s\n' "$mauve" \
        "$(pad name 28)" "$(pad phase 9)" "$(pad progress 9)" "flag / cvss" "$reset"

      printf '%s' "$rows" | sort -rn -k1,1 | while IFS=$'\t' read -r _ sub marker; do
        [ -n "$sub" ] || continue
        local nm ph pr fc
        nm=$(basename "$sub")
        ph=$(phase_for "$marker")
        pr=$(progress_for "$marker")
        fc=$(flag_or_cvss_for "$marker")
        printf '%s%s%s  %s%s%s  %s%s%s  %s%s%s\n' \
          "$green"   "$(pad "$nm" 28)" "$reset" \
          "$mauve"   "$(pad "$ph" 9)"  "$reset" \
          "$subtext" "$(pad "$pr" 9)"  "$reset" \
          "$subtext" "$fc"             "$reset"
      done
    }

    resolve_case() {
      local name="$1" d cand exact="" prefix=""
      for d in $CASE_DIRS; do
        [ -d "$d" ] || continue
        cand="$d/$name"
        if [ -d "$cand" ] && marker_for "$cand" >/dev/null 2>&1; then
          exact="$cand"; break
        fi
        while IFS= read -r hit; do
          [ -n "$hit" ] || continue
          # fd prints dirs with a trailing slash
          [ -z "$prefix" ] && prefix="''${hit%/}"
        done < <(fd -t d -d 1 "^$name" "$d" 2>/dev/null)
      done
      if [ -n "$exact" ]; then printf '%s\n' "$exact"; return 0; fi
      if [ -n "$prefix" ]; then printf '%s\n' "$prefix"; return 0; fi
      return 1
    }

    cmd_open() {
      local name="''${1:-}"
      [ -n "$name" ] || die "usage: case open <name>"
      local path
      path=$(resolve_case "$name") || die "no case matching '$name' under: $CASE_DIRS"
      if [ -n "''${EDITOR:-}" ] && [ -t 1 ]; then
        local marker
        marker=$(marker_for "$path" || true)
        exec "$EDITOR" "''${marker:-$path}"
      fi
      printf '%s\n' "$path"
    }

    cmd_new() {
      local name="''${1:-}"
      [ -n "$name" ] || die "usage: case new <name>"

      local root="" d
      for d in $CASE_DIRS; do [ -d "$d" ] && { root="$d"; break; }; done
      if [ -z "$root" ]; then
        root="''${CASE_DIRS%% *}"; mkdir -p "$root"
      fi

      local dir="$root/$name"
      [ -e "$dir" ] && die "$dir already exists — refusing to clobber."

      mkdir -p "$dir/notes" "$dir/decomp" "$dir/scripts" "$dir/artifacts"

      cat > "$dir/notes/findings.md" <<NOTESEOF
    # $name

    ## target
    - subject:
    - version / commit:
    - vehicle:           (GHSA / issue / PR / advisory)

    ## surface / approach
    - bug:
    - primitive:
    - reachability:

    ## findings checklist
    - [ ] prior-art search done (no existing CVE/GHSA)
    - [ ] root cause located (file:line)
    - [ ] PoC written
    - [ ] PoC VERIFIED against a clean checkout
    - [ ] impact / threat model written
    - [ ] CVSS scored
    - [ ] draft ready to file

    ## CVSS
    \`CVSS:3.1/AV:?/AC:?/PR:?/UI:?/S:?/C:?/I:?/A:?\` — **?, ?**

    ## flag
    - flag:
    NOTESEOF

      printf '%snew case ready:%s %s%s%s\n' "$mauve" "$reset" "$green" "$name" "$reset"
      printf '%s   %s/%s\n' "$subtext" "$dir" "$reset"
      printf '%s     notes/      findings.md (target / checklist / CVSS / flag)%s\n' "$subtext" "$reset"
      printf '%s     decomp/     decompiler output, IDB/r2 projects%s\n' "$subtext" "$reset"
      printf '%s     scripts/    PoC + tooling%s\n' "$subtext" "$reset"
      printf '%s     artifacts/  binaries, dumps, captures%s\n' "$subtext" "$reset"
      printf '%s   next:%s case open %s%s\n' "$mauve" "$subtext" "$name" "$reset"
    }

    usage() {
      # literal $ at runtime to dodge SC2016
      local d
      d=$(printf '\044')
      printf '%scase%s — cozy RE/CTF + disclosure tracker\n' "$mauve" "$reset"
      printf '%s  case ls%s              list cases (sorted by recency)\n' "$subtext" "$reset"
      printf '%s  case open <name>%s     print the path, or %sEDITOR the notes\n' "$subtext" "$reset" "$d"
      printf '%s  case new  <name>%s     scaffold a fresh case\n' "$subtext" "$reset"
      printf '%s  %sCASE_DIRS%s = %s\n' "$subtext" "$d" "$reset" "$CASE_DIRS"
    }

    case "''${1:-ls}" in
      ls)            shift || true; cmd_ls "$@" ;;
      open|o|cd)     shift; cmd_open "$@" ;;
      new|n)         shift; cmd_new "$@" ;;
      -h|--help|help) usage ;;
      *)             usage >&2; exit 1 ;;
    esac
  '';

  meta = {
    description = "cozy re/ctf + oss-disclosure case tracker (ls/open/new over $CASE_DIRS)";
    mainProgram = "case";
    platforms = [
      "aarch64-darwin"
      "x86_64-darwin"
      "aarch64-linux"
      "x86_64-linux"
    ];
  };
}
