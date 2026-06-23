{
  writeShellApplication,
  coreutils,
  gnugrep,
  findutils,
}:
writeShellApplication {
  name = "gate-check";

  runtimeInputs = [
    coreutils
    gnugrep
    findutils
  ];

  text = ''
    set -euo pipefail

    mauve=$'\033[38;5;183m'
    subtext=$'\033[38;5;146m'
    green=$'\033[38;5;151m'
    red=$'\033[38;5;210m'
    reset=$'\033[0m'

    hedge_words=(
      'appears to'
      'likely'
      'should be vulnerable'
      'might be'
      'probably'
    )

    cvss_re='CVSS:3\.1/'
    cite_re='[A-Za-z0-9_]+\.[A-Za-z0-9_]+:[0-9]+'

    dir="''${1:-$PWD}"
    if [ ! -d "$dir" ]; then
      printf '%sgate-check: %s is not a directory%s\n' "$red" "$dir" "$reset" >&2
      exit 2
    fi

    drafts=()
    while IFS= read -r -d ''' f; do
      drafts+=("$f")
    done < <(find "$dir" -type f -name 'GHSA-SUBMIT-*.md' -print0 | sort -z)

    if [ ''${#drafts[@]} -eq 0 ]; then
      printf '%sgate-check:%s no GHSA-SUBMIT-*.md under %s%s%s, nothing to gate.\n' \
        "$mauve" "$reset" "$subtext" "$dir" "$reset"
      exit 0
    fi

    printf '%sgate-check%s %s(%d draft(s) under %s)%s\n' \
      "$mauve" "$reset" "$subtext" "''${#drafts[@]}" "$dir" "$reset"

    fail_total=0

    for draft in "''${drafts[@]}"; do
      finding_dir="$(dirname "$draft")"
      poc_dir="$finding_dir/poc"
      reasons=()

      # gate 1: poc/ non-empty
      if [ ! -d "$poc_dir" ]; then
        reasons+=("no poc/ dir (expected $poc_dir)")
      elif [ -z "$(find "$poc_dir" -mindepth 1 -print -quit)" ]; then
        reasons+=("poc/ is empty: a runnable PoC must live here")
      fi

      # gate 2: repro.txt
      if [ ! -s "$poc_dir/repro.txt" ] && [ ! -s "$finding_dir/repro.txt" ]; then
        reasons+=("no repro.txt: capture the ACTUAL observed crash/leak output")
      fi

      # gate 3: cvss vector
      if ! grep -qE "$cvss_re" "$draft"; then
        reasons+=("no CVSS:3.1/ vector: score it (conservatively)")
      fi

      # gate 4: file:line citation
      if ! grep -qE "$cite_re" "$draft"; then
        reasons+=("no file:line citation: name the source and sink with line numbers")
      fi

      # gate 5: no hedge words
      hedges_hit=()
      for w in "''${hedge_words[@]}"; do
        if grep -qiF "$w" "$draft"; then
          hedges_hit+=("$w")
        fi
      done
      if [ ''${#hedges_hit[@]} -gt 0 ]; then
        reasons+=("hedge word(s): $(IFS=', '; echo "''${hedges_hit[*]}"): prove it, don't hedge")
      fi

      rel="''${draft#"$dir"/}"
      if [ ''${#reasons[@]} -eq 0 ]; then
        printf '  %s✓%s %s%s%s\n' "$green" "$reset" "$subtext" "$rel" "$reset"
      else
        fail_total=$((fail_total + 1))
        printf '  %s✗ %s%s\n' "$red" "$rel" "$reset"
        for r in "''${reasons[@]}"; do
          printf '      %s↳ %s%s\n' "$red" "$r" "$reset"
        done
      fi
    done

    echo
    if [ "$fail_total" -gt 0 ]; then
      printf '%sgate-check: %d draft(s) RED, not submittable.%s ' "$red" "$fail_total" "$reset"
      printf '%sthe gate is the point; go back to the debugger.%s\n' "$subtext" "$reset"
      exit 1
    fi

    printf '%sall drafts green%s %s: gates passed (poc/repro/cvss/cite, no hedging).%s\n' \
      "$green" "$reset" "$subtext" "$reset"
  '';

  meta = {
    description = "deterministic pre-submit linter for GHSA-SUBMIT drafts (poc/repro/cvss/cite/no-hedge)";
    mainProgram = "gate-check";
    platforms = [
      "aarch64-darwin"
      "x86_64-darwin"
      "aarch64-linux"
      "x86_64-linux"
    ];
  };
}
