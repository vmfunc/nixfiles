{
  writeShellApplication,
  gh,
  jq,
  coreutils,
}:
writeShellApplication {
  name = "pvr-scan";

  runtimeInputs = [
    gh
    jq
    coreutils
  ];

  text = ''
    set -euo pipefail

    mauve=$'\033[38;5;183m'
    subtext=$'\033[38;5;146m'
    green=$'\033[38;5;151m'
    red=$'\033[38;5;210m'
    reset=$'\033[0m'

    default_tsv="''${PVR_SCAN_TSV:-$HOME/pentest/targets/candidates.tsv}"
    tsv="$default_tsv"
    dry_run=0
    rate_floor=50

    usage() {
      cat >&2 <<EOF
    ''${mauve}pvr-scan''${reset}: refresh the PVR column of a targets TSV 🦦

    usage: pvr-scan [TSV] [--dry-run]

      TSV          path to the targets TSV (default: \$PVR_SCAN_TSV or
                   ~/pentest/targets/candidates.tsv). Point this at YOUR file.
      --dry-run    query + print the diff, do NOT rewrite the TSV.
      -h, --help   this.

    Expected TSV schema (tab-separated, header on line 1):
      repo<TAB>stars<TAB>lang<TAB>PVR<TAB>description
    where 'repo' is "owner/repo" and 'PVR' is true/false. Any extra columns
    after 'description' (e.g. an 'archived' / 'pushed_at' drop-signal column
    appended by a previous run) are preserved. If your file uses a different
    layout, pvr-scan only needs a 'repo' column and a 'PVR' column by name,
    it locates them from the header, so adapt the header, not the tool.

    Per repo it calls:
      gh api repos/{o}/{r}/private-vulnerability-reporting -q .enabled
      gh api repos/{o}/{r}    (archived, pushed_at, stargazers_count)
    and appends/refreshes 'archived' + 'pushed_at' columns as drop signals.
    EOF
    }

    for arg in "$@"; do
      case "$arg" in
        -h | --help)
          usage
          exit 0
          ;;
        --dry-run)
          dry_run=1
          ;;
        -*)
          printf '%sunknown flag: %s%s\n' "$red" "$arg" "$reset" >&2
          usage
          exit 1
          ;;
        *)
          tsv="$arg"
          ;;
      esac
    done

    if [ ! -f "$tsv" ]; then
      printf '%sno such TSV: %s%s\n' "$red" "$tsv" "$reset" >&2
      printf '%spoint pvr-scan at your targets file: pvr-scan <path>%s\n' \
        "$subtext" "$reset" >&2
      exit 1
    fi

    if ! gh auth status >/dev/null 2>&1; then
      printf '%sgh is not authenticated, run: gh auth login%s\n' \
        "$red" "$reset" >&2
      exit 1
    fi

    header="$(head -n 1 "$tsv")"
    repo_col=0
    pvr_col=0
    ncol=0
    # shellcheck disable=SC2034
    IFS=$'\t' read -r -a cols <<<"$header"
    for i in "''${!cols[@]}"; do
      case "''${cols[$i]}" in
        repo) repo_col=$((i + 1)) ;;
        PVR) pvr_col=$((i + 1)) ;;
      esac
      ncol=$((i + 1))
    done

    if [ "$repo_col" -eq 0 ] || [ "$pvr_col" -eq 0 ]; then
      printf '%sheader is missing a "repo" and/or "PVR" column:%s\n' \
        "$red" "$reset" >&2
      printf '%s  %s%s\n' "$subtext" "$header" "$reset" >&2
      exit 1
    fi

    archived_col=0
    pushed_col=0
    for i in "''${!cols[@]}"; do
      case "''${cols[$i]}" in
        archived) archived_col=$((i + 1)) ;;
        pushed_at) pushed_col=$((i + 1)) ;;
      esac
    done
    new_header="$header"
    if [ "$archived_col" -eq 0 ]; then
      ncol=$((ncol + 1))
      archived_col=$ncol
      new_header="$new_header"$'\t'"archived"
    fi
    if [ "$pushed_col" -eq 0 ]; then
      ncol=$((ncol + 1))
      pushed_col=$ncol
      new_header="$new_header"$'\t'"pushed_at"
    fi

    rate_guard() {
      local remaining reset_at now wait
      remaining="$(gh api rate_limit -q .resources.core.remaining 2>/dev/null || echo 999)"
      case "$remaining" in
        "" | *[!0-9]*) remaining=999 ;;
      esac
      if [ "$remaining" -ge "$rate_floor" ]; then
        return 0
      fi
      reset_at="$(gh api rate_limit -q .resources.core.reset 2>/dev/null || echo 0)"
      now="$(date +%s)"
      wait=$((reset_at - now + 2))
      [ "$wait" -lt 2 ] && wait=2
      printf '%s… rate quota low (%s left), waiting %ss for reset%s\n' \
        "$subtext" "$remaining" "$wait" "$reset" >&2
      sleep "$wait"
    }

    # per-run mktemp for gh's stderr; a fixed /tmp path is a symlink-clobber vector and
    # races two concurrent scans. cleaned up in the EXIT trap below.
    errf="$(mktemp)"

    # 429/secondary-limit: back off once and retry; other failures bubble up
    gh_api() {
      local out rc
      if out="$(gh api "$@" 2>"$errf")"; then
        printf '%s' "$out"
        return 0
      fi
      rc=$?
      if grep -qiE '(rate limit|429|secondary rate)' "$errf"; then
        printf '%s… hit a rate limit on "%s", backing off 60s%s\n' \
          "$subtext" "$*" "$reset" >&2
        sleep 60
        if out="$(gh api "$@" 2>/dev/null)"; then
          printf '%s' "$out"
          return 0
        fi
      fi
      return "$rc"
    }

    tmp="$(mktemp)"
    trap 'rm -f "$tmp" "$errf"' EXIT

    printf '%s' "$new_header" >"$tmp"
    printf '\n' >>"$tmp"

    new_targets=0
    dropped=0
    errors=0
    scanned=0

    tail -n +2 "$tsv" | while IFS=$'\t' read -r -a row; do
      [ "''${#row[@]}" -eq 0 ] && continue

      repo="''${row[$((repo_col - 1))]}"
      old_pvr="''${row[$((pvr_col - 1))]:-}"
      scanned=$((scanned + 1))

      owner="''${repo%%/*}"
      name="''${repo#*/}"
      if [ -z "$owner" ] || [ -z "$name" ] || [ "$owner" = "$repo" ]; then
        printf '%s  ? skipping malformed repo cell: %s%s\n' \
          "$subtext" "$repo" "$reset" >&2
        errors=$((errors + 1))
      else
        rate_guard

        # PVR endpoint 404s when a repo is gone/renamed
        if new_pvr="$(gh_api "repos/$owner/$name/private-vulnerability-reporting" \
          -q .enabled 2>/dev/null)"; then
          case "$new_pvr" in
            true | false) : ;;
            *) new_pvr="$old_pvr" ;;
          esac
        else
          printf '%s  ! %s: PVR query failed, keeping old value%s\n' \
            "$red" "$repo" "$reset" >&2
          errors=$((errors + 1))
          new_pvr="$old_pvr"
        fi

        meta="$(gh_api "repos/$owner/$name" \
          -q '[.archived, (.pushed_at // ""), (.stargazers_count // "")] | @tsv' \
          2>/dev/null || true)"
        if [ -n "$meta" ]; then
          IFS=$'\t' read -r m_arch m_pushed m_stars <<<"$meta"
          m_pushed="''${m_pushed%%T*}"
        else
          m_arch="false"
          m_pushed=""
          m_stars=""
        fi

        if [ "$old_pvr" = "false" ] && [ "$new_pvr" = "true" ]; then
          printf '%s  + %s: PVR enabled → NEW TARGET%s\n' \
            "$green" "$repo" "$reset"
          new_targets=$((new_targets + 1))
        elif [ "$old_pvr" = "true" ] && [ "$new_pvr" = "false" ]; then
          printf '%s  - %s: PVR disabled → drop%s\n' "$red" "$repo" "$reset"
          dropped=$((dropped + 1))
        fi
        if [ "$m_arch" = "true" ]; then
          printf '%s  - %s: archived → drop%s\n' "$red" "$repo" "$reset"
          dropped=$((dropped + 1))
        fi

        # pad to full width so positional writes never index past the end
        while [ "''${#row[@]}" -lt "$ncol" ]; do
          row+=("")
        done
        row[pvr_col - 1]="$new_pvr"
        row[archived_col - 1]="$m_arch"
        row[pushed_col - 1]="$m_pushed"
        if [ -n "$m_stars" ]; then
          for i in "''${!cols[@]}"; do
            if [ "''${cols[$i]}" = "stars" ]; then
              row[i]="$m_stars"
              break
            fi
          done
        fi
      fi

      out=""
      for i in $(seq 0 $((ncol - 1))); do
        cell="''${row[$i]:-}"
        if [ "$i" -eq 0 ]; then
          out="$cell"
        else
          out="$out"$'\t'"$cell"
        fi
      done
      printf '%s\n' "$out" >>"$tmp"
    done

    # while-loop ran in a subshell so its counters are gone; recompute from files
    enabled_before="$(tail -n +2 "$tsv" | awk -F'\t' -v c="$pvr_col" \
      '$c=="true"{n++} END{print n+0}')"
    enabled_after="$(tail -n +2 "$tmp" | awk -F'\t' -v c="$pvr_col" \
      '$c=="true"{n++} END{print n+0}')"
    arch_after="$(tail -n +2 "$tmp" | awk -F'\t' -v c="$archived_col" \
      '$c=="true"{n++} END{print n+0}')"
    total="$(($(wc -l <"$tmp") - 1))"

    if [ "$dry_run" -eq 1 ]; then
      printf '%s🦦 dry run: TSV unchanged.%s\n' "$mauve" "$reset"
    else
      # write to same dir then mv for rename atomicity
      dest_tmp="$tsv.pvr-scan.$$"
      cp "$tmp" "$dest_tmp"
      mv -f "$dest_tmp" "$tsv"
      printf '%s🦦 wrote%s %s%s%s\n' "$mauve" "$reset" "$green" "$tsv" "$reset"
    fi

    printf '%s   %s repos scanned%s\n' "$subtext" "$total" "$reset"
    printf '%s   PVR-enabled: %s → %s%s\n' \
      "$subtext" "$enabled_before" "$enabled_after" "$reset"
    printf '%s   currently archived (drop): %s%s\n' \
      "$subtext" "$arch_after" "$reset"
  '';

  meta = {
    description = "Refresh the PVR column of a targets TSV + mauve diff of what flipped";
    mainProgram = "pvr-scan";
    platforms = [
      "aarch64-darwin"
      "x86_64-darwin"
      "aarch64-linux"
      "x86_64-linux"
    ];
  };
}
