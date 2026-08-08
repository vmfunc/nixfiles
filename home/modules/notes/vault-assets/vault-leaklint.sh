#!/usr/bin/env bash
# vault-leaklint: pre-publish opsec check for vmfunc.ink.
#
# Obsidian Sync gives no diff to review before a publish, and Publish renders a
# link to an unpublished note as a DIM link that still shows the target's title.
# so a single wikilink from a published note into a private one (work/, shopping/,
# anything publish:false) leaks that private title onto the public site. this
# flags those, plus stray %hidden markers, before a sync. exit 1 on any finding.
#
# the private set is the picker exclusions (work/, shopping/) plus any note
# carrying `publish: false`. run: `vault-leaklint` (defaults to ~/vault), or
# `vault-leaklint /path/to/vault`. read-only; it never edits the vault.
set -euo pipefail

VAULT="${1:-$HOME/vault}"
cd "$VAULT"

tmp="$(mktemp)"
trap 'rm -f "$tmp"' EXIT

# private targets, addressed by the link-by-filename convention (basename).
declare -A PRIVATE
add_private() { PRIVATE["$(basename "$1" .md)"]=1; }
while IFS= read -r f; do add_private "$f"; done < <(find work shopping -name '*.md' 2>/dev/null || true)
while IFS= read -r f; do add_private "$f"; done < <(
  grep -rlE '^publish:[[:space:]]*false' --include='*.md' . 2>/dev/null | sed 's#^\./##' || true
)

# 1. wikilinks from a publishable note into a private note (title leak).
while IFS= read -r src; do
  rel="${src#./}"
  # skip sources that are themselves excluded from publish (the picker mutes
  # home/inbox/shopping/work) plus the non-note trees. everything else ships.
  case "$rel" in
    work/* | shopping/* | inbox/* | .obsidian/* | .trash/* | .archive/* | templates/* | home.md) continue ;;
  esac
  while IFS= read -r tgt; do
    [ -n "$tgt" ] || continue
    if [ -n "${PRIVATE[$(basename "$tgt")]:-}" ]; then
      printf 'LEAK    %s  ->  [[%s]]  (private note title exposed as a link)\n' "$rel" "$tgt" >>"$tmp"
    fi
  done < <(
    grep -oE '\[\[[^]]+\]\]' "$src" 2>/dev/null |
      sed -E 's/^\[\[//; s/\]\]$//; s/\|.*$//; s/#.*$//' || true
  )
done < <(find . -name '*.md' 2>/dev/null)

# 2. a %hidden marker (a ~/.plan-ism) sitting in a publishable note.
while IFS= read -r hit; do
  printf 'REVIEW  %s  (carries a %%hidden marker in a publishable folder)\n' "$hit" >>"$tmp"
done < <(
  grep -rlE '%hidden' --include='*.md' . 2>/dev/null | sed 's#^\./##' |
    grep -vE '^(work|shopping|inbox|\.obsidian|\.trash|\.archive|templates)/|^home\.md$' || true
)

if [ -s "$tmp" ]; then
  echo "vault-leaklint: findings, review before publishing:"
  sort -u "$tmp" | sed 's/^/  /'
  echo "  ---"
  echo "  $(sort -u "$tmp" | wc -l) finding(s). a dim/unresolved link on Publish still leaks the target's title."
  exit 1
fi
echo "vault-leaklint: clean. no publishable note links into work/ or shopping/, no stray %hidden."
