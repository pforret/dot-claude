#!/bin/bash
# mkdokf validate.sh — OKF conformance check for an agent-docs bundle.
# Usage: bash validate.sh [bundle-dir]   (default: docs/agents, relative to CWD)
BUNDLE="${1:-docs/agents}"
fail=0

[ -d "$BUNDLE" ] || { echo "NO BUNDLE: $BUNDLE"; exit 1; }

# 1. Every folder (root + each section, excluding references/) has an index.md
for d in "$BUNDLE" "$BUNDLE"/*/; do
  d="${d%/}"
  [ "$(basename "$d")" = "references" ] && continue
  [ -d "$d" ] || continue
  [ -f "$d/index.md" ] || { echo "MISSING INDEX: $d"; fail=1; }
done

# 2. Every concept doc (non-reserved) has frontmatter with a non-empty type:
while IFS= read -r f; do
  if ! head -1 "$f" | grep -q '^---$'; then echo "NO FRONTMATTER: $f"; fail=1; fi
  if ! awk 'NR==1&&/^---$/{fm=1;next} fm&&/^---$/{exit} fm&&/^type: *[^ ]/{found=1} END{exit !found}' "$f"; then
    echo "NO type: $f"; fail=1
  fi
done < <(find "$BUNDLE" -name '*.md' ! -name 'index.md' ! -name 'log.md' ! -name 'tags.md' ! -path '*/references/*')

# 3. Section index files have NO frontmatter; root index carries okf_version
for f in "$BUNDLE"/*/index.md; do
  [ -f "$f" ] || continue
  head -1 "$f" | grep -q '^---$' && { echo "FRONTMATTER IN SECTION INDEX: $f"; fail=1; }
done
if [ -f "$BUNDLE/index.md" ]; then
  head -3 "$BUNDLE/index.md" | grep -q '^okf_version:' || { echo "ROOT INDEX MISSING okf_version"; fail=1; }
fi

# 4. Every concept doc is listed in its folder's index.md
for d in "$BUNDLE"/*/; do
  d="${d%/}"
  [ "$(basename "$d")" = "references" ] && continue
  [ -f "$d/index.md" ] || continue
  for f in "$d"/*.md; do
    b=$(basename "$f")
    case "$b" in index.md|log.md|tags.md) continue ;; esac
    grep -q "($b)" "$d/index.md" || { echo "NOT IN INDEX: $f"; fail=1; }
  done
done

# 5. All relative .md links resolve
while IFS='|' read -r src link; do
  case "$link" in http*) continue ;; esac
  tgt="$(dirname "$src")/$link"
  [ -e "$tgt" ] || { echo "BROKEN LINK: $src -> $link"; fail=1; }
done < <(grep -RoE '\]\([^)#]+\.md' "$BUNDLE" --include='*.md' | sed 's/:\](/|/')

# 6. No markdown links from docs into source trees (breaks docs-site builds)
badlinks=$(grep -RnoE '\]\((\.\./)+(app|src|lib|config|resources|internal|pkg)/[^)]+\)' "$BUNDLE" --include='*.md' || true)
if [ -n "$badlinks" ]; then
  echo "$badlinks" | sed 's/^/SOURCE-TREE LINK (use a code span instead): /'
  fail=1
fi

[ $fail -eq 0 ] && echo "OK: all conformance checks passed for $BUNDLE"
exit $fail
