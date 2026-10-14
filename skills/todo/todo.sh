#!/usr/bin/env bash
# Helper for the /todo skill AND a standalone CLI (symlinked as `todo` / `todo.sh` in $PATH).
#
# CLI usage (run inside a repo):
#   todo                          usage
#   todo i | index                index of todo items in this repo
#   todo p | pick                 fzf picker over planned/plan items; ENTER starts claude on it
#   todo <id> [execute]           start claude to execute item <id>
#   todo <id> plan                start claude to run the planning (PRP) flow on item <id>
#   todo <id> skip                skip item <id> (asks for the reason)
#   todo done | skip | show       same, for the item last started (docs/todo/.current)
#   todo add <text>               start claude to add a new item
# IDs: 1,2,.. = planned table   P1,P2,.. = plan table   B1,B2,.. = busy table
#
# Skill-internal commands:
#   todo.sh init                 create docs/todo/{plan,busy,done,skipped} + index files (idempotent)
#   todo.sh list                 print planned items with reference numbers (+ plan/busy tables if non-empty)
#   todo.sh reindex              rebuild every index.md from the files on disk
#   todo.sh path <id>            print the file path of item <id> (1 / P1 / B1 / filename)
#   todo.sh current              print the file path of the item last moved to busy
#   todo.sh move <id> <plan|busy|done|skipped>     move item <id> and reindex
#   todo.sh move-file <file> <plan|busy|done|skipped>
#   todo.sh set <file> <key> <value>               set/replace a frontmatter field
set -euo pipefail
ROOT="${TODO_ROOT:-docs/todo}"
# a relative ROOT is always taken from the repo root, so the command works from any subdirectory
case "$ROOT" in /*) ;; *) cd "$(git rev-parse --show-toplevel 2>/dev/null || pwd)" ;; esac

field() { # field <file> <key>  -> frontmatter value
  sed -n '/^---$/,/^---$/p' "$1" | grep -E "^$2:" | head -1 | sed -E "s/^$2:[[:space:]]*//; s/^\"(.*)\"$/\1/"
  return 0
}

item_files() { # item_files <dir>
  find "$1" -maxdepth 1 -type f -name '20*.md' 2>/dev/null | sort
}

dir_for() { # dir_for <planned|plan|busy|done|skipped>
  case "$1" in planned|"") echo "$ROOT" ;; plan|busy|done|skipped) echo "$ROOT/$1" ;; *) echo "bad dir: $1" >&2; exit 1 ;; esac
}

write_index() { # write_index <dir> <heading> <status-word> [extra-column] [id-prefix]
  local dir="$1" heading="$2" status="$3" extra="${4:-}" prefix="${5:-}" n=0 f
  {
    echo "# $heading"
    echo
    if [ -z "$(item_files "$dir")" ]; then
      echo "_No $status items._"
    else
      if [ "$extra" = "confidence" ]; then
        echo "| ID | Date | Type | Size | Confidence | Title | File |"
        echo "|----|------|------|------|------------|-------|------|"
      else
        echo "| ID | Date | Type | Size | Title | File |"
        echo "|----|------|------|------|-------|------|"
      fi
      while IFS= read -r f; do
        [ -z "$f" ] && continue
        n=$((n+1))
        local base date type size title conf
        base=$(basename "$f")
        date=${base:0:10}
        type=$(echo "$base" | cut -d. -f2)
        size=$(field "$f" size); size=${size:-?}
        title=$(field "$f" title); title=${title:-${base#*.*.}}; title=${title%.md}
        if [ "$extra" = "confidence" ]; then
          conf=$(field "$f" confidence); conf=${conf:-?}
          echo "| $prefix$n | $date | $type | $size | $conf/10 | $title | [$base]($base) |"
        else
          echo "| $prefix$n | $date | $type | $size | $title | [$base]($base) |"
        fi
      done <<< "$(item_files "$dir")"
    fi
  } > "$dir/index.md"
}

init() {
  mkdir -p "$ROOT/plan" "$ROOT/busy" "$ROOT/done" "$ROOT/skipped"
  reindex
}

reindex() {
  write_index "$ROOT" "Todo — planned" "planned"
  write_index "$ROOT/plan" "Todo — plan (PRP ready, waiting for execute; IDs P1, P2, …)" "plan" confidence P
  write_index "$ROOT/busy" "Todo — busy (in progress; IDs B1, B2, …)" "busy" "" B
  write_index "$ROOT/done" "Todo — done" "done"
  write_index "$ROOT/skipped" "Todo — skipped" "skipped"
}

nth() { # nth <dir> <n>
  item_files "$1" | sed -n "${2}p"
}

list() {
  [ -f "$ROOT/index.md" ] || init
  cat "$ROOT/index.md"
  if [ -n "$(item_files "$ROOT/plan")" ]; then
    echo; cat "$ROOT/plan/index.md"
  fi
  if [ -n "$(item_files "$ROOT/busy")" ]; then
    echo; cat "$ROOT/busy/index.md"
  fi
}

set_field() { # set_field <file> <key> <value>
  local f="$1" key="$2" value="$3"
  [ -f "$f" ] || { echo "not found: $f" >&2; exit 1; }
  if sed -n '/^---$/,/^---$/p' "$f" | grep -qE "^${key}:"; then
    sed -i '' -E "s|^${key}:.*|${key}: ${value}|" "$f"
  else
    awk -v line="${key}: ${value}" 'BEGIN{d=0} {print} /^status:/ && !d {print line; d=1}' "$f" > "$f.tmp" && mv "$f.tmp" "$f"
  fi
}

move_file() { # move_file <file> <target>
  local f="$1" target="$2"
  [ -f "$f" ] || { echo "not found: $f" >&2; exit 1; }
  case "$target" in plan|busy|done|skipped) ;; *) echo "bad target: $target" >&2; exit 1;; esac
  local today; today=$(date +%Y-%m-%d)
  set_field "$f" status "$target"
  set_field "$f" "${target}_at" "$today"
  if git -C "$(dirname "$f")" rev-parse --is-inside-work-tree >/dev/null 2>&1 && git ls-files --error-unmatch "$f" >/dev/null 2>&1; then
    git mv "$f" "$ROOT/$target/"
  else
    mv "$f" "$ROOT/$target/"
  fi
  reindex
  if [ "$target" = busy ]; then
    echo "$(basename "$f")" > "$ROOT/.current"
  elif [ -f "$ROOT/.current" ] && [ "$(cat "$ROOT/.current")" = "$(basename "$f")" ]; then
    rm -f "$ROOT/.current"
  fi
  echo "$ROOT/$target/$(basename "$f")"
}

current() { # path of the item last moved to busy; falls back to the only busy item
  local base
  if [ -f "$ROOT/.current" ]; then
    base=$(cat "$ROOT/.current")
    [ -f "$ROOT/busy/$base" ] && { echo "$ROOT/busy/$base"; return 0; }
  fi
  if [ "$(item_files "$ROOT/busy" | wc -l | tr -d ' ')" = 1 ]; then
    item_files "$ROOT/busy"; return 0
  fi
  echo "no current item (nothing in busy, or several; use B<n>)" >&2; return 1
}

# ---------------------------------------------------------------- CLI layer

usage() {
  cat <<USAGE
todo — per-repo todo items in docs/todo/ (driven by the Claude Code /todo skill)

  todo                  this help
  todo i | index        list items (planned, plan, busy) of the current repo
  todo p | pick         pick an item with fzf, ENTER starts claude to execute it
  todo <id> [execute]   start claude to execute item <id>
  todo <id> plan        start claude to plan item <id> (PRP + clarifying questions, to 9/10 confidence)
  todo <id> skip        skip item <id>, asks for the reason
  todo <id> done        start claude to verify and archive item <id>
  todo <id> show        print the item file
  todo done|skip|show   same, for the item last started (see 'todo current')
  todo add <text>       start claude to add a new item

IDs:  1, 2, …  planned table      P1, P2, …  plan table (PRP written)      B1, B2, …  busy table
      an item filename (2026-…md) also works anywhere an <id> is expected.
USAGE
}

repo_root() {
  git rev-parse --show-toplevel 2>/dev/null || pwd
}

need_claude() {
  command -v claude >/dev/null 2>&1 || { echo "claude CLI not found in PATH" >&2; exit 1; }
}

run_claude() { # run_claude <prompt>
  need_claude
  echo "→ claude \"$1\""
  exec claude "$1"
}

resolve() { # resolve <id>  -> file path. 1 = planned, P1 = plan, B1 = busy, filename, or empty = current
  local spec="${1:-}" f
  spec="${spec#\#}"
  case "$spec" in
    "")            current; return $? ;;
    *.md)          f=$(find "$ROOT" -name "$(basename "$spec")" -type f | head -1) ;;
    [Pp][0-9]*)    f=$(nth "$ROOT/plan" "${spec#[Pp]}") ;;
    [Bb][0-9]*)    f=$(nth "$ROOT/busy" "${spec#[Bb]}") ;;
    [0-9]*)        f=$(nth "$ROOT" "$spec") ;;
    *)             echo "bad id: $spec (use 1, P1, B1 or a filename)" >&2; return 1 ;;
  esac
  [ -n "$f" ] || { echo "no item $spec" >&2; return 1; }
  echo "$f"
}

cli_skip() { # cli_skip <id|empty>
  local f; f=$(resolve "${1:-}")
  echo "Skipping: $(field "$f" title)  ($f)"
  echo "Reason (obsolete, out of scope, duplicate, won't fix, ...):"
  local reason; read -r -p "> " reason
  [ -n "$reason" ] || { echo "no reason given, aborted" >&2; exit 1; }
  printf '\n## Skipped\n\n%s\n' "$reason" >> "$f"
  move_file "$f" skipped
}

cli_pick() {
  local lines="" t f n px
  for t in plan planned; do
    n=0; px=""; [ "$t" = plan ] && px=P
    while IFS= read -r f; do
      [ -z "$f" ] && continue; n=$((n+1))
      lines+="$(printf '%s\t%-7s %-3s\t%s\t%s\t%s\t%s' "$f" "$t" "$px$n" "$(basename "$f" | cut -c1-10)" "$(basename "$f" | cut -d. -f2)" "$(field "$f" size)" "$(field "$f" title)")"$'\n'
    done <<< "$(item_files "$(dir_for "$t")")"
  done
  [ -n "$lines" ] || { echo "no planned items. Add one with: todo add <text>" >&2; exit 1; }
  local chosen
  if command -v fzf >/dev/null 2>&1; then
    chosen=$(printf '%s' "$lines" | fzf --delimiter=$'\t' --with-nth=2.. --tabstop=1 \
      --header="ENTER: execute with claude   ESC: cancel" \
      --preview='sed -n "1,60p" {1}' --preview-window=right:55%:wrap) || exit 0
  else
    echo "(fzf not installed, falling back to a numbered menu)" >&2
    local arr=() i=1
    while IFS= read -r l; do [ -n "$l" ] && arr+=("$l"); done <<< "$lines"
    for l in "${arr[@]}"; do printf '%2d) %s\n' "$i" "$(printf '%s' "$l" | cut -f2-)"; i=$((i+1)); done
    read -r -p "Pick [1-${#arr[@]}] " i
    [[ "$i" =~ ^[0-9]+$ ]] && [ "$i" -ge 1 ] && [ "$i" -le "${#arr[@]}" ] || exit 0
    chosen="${arr[$((i-1))]}"
  fi
  f=$(printf '%s' "$chosen" | cut -f1)
  run_claude "/todo $(basename "$f") execute"
}

cli() { # cli <args...>   (cwd = repo root)
  local cmd="${1:-}"; shift || true
  local f
  case "$cmd" in
    ""|-h|--help|help) usage ;;
    i|index) list ;;
    p|pick) cli_pick ;;
    add) [ $# -gt 0 ] || { echo "usage: todo add <text>" >&2; exit 1; }; run_claude "/todo add $*" ;;
    done) f=$(resolve ""); run_claude "/todo $(basename "$f") done" ;;
    skip) cli_skip "" ;;
    show) f=$(resolve ""); cat "$f" ;;
    current) resolve "" ;;
    \#*|[0-9]*|[PpBb][0-9]*|*.md)
      local verb="${1:-execute}"
      case "$verb" in
        execute|start) f=$(resolve "$cmd"); run_claude "/todo $(basename "$f") execute" ;;
        plan)  f=$(resolve "$cmd"); run_claude "/todo $(basename "$f") plan" ;;
        skip)  cli_skip "$cmd" ;;
        done)  f=$(resolve "$cmd"); run_claude "/todo $(basename "$f") done" ;;
        show)  f=$(resolve "$cmd"); cat "$f" ;;
        *) echo "unknown verb: $verb" >&2; usage; exit 1 ;;
      esac ;;
    *) echo "unknown command: $cmd" >&2; usage; exit 1 ;;
  esac
}

# ---------------------------------------------------------------- dispatch

cmd="${1:-}"; shift || true
case "$cmd" in
  # skill-internal (deterministic, used by SKILL.md)
  init) init ;;
  list) list ;;
  reindex) reindex ;;
  path|resolve) resolve "${1:-}" ;;
  current) current ;;
  move) f=$(resolve "$1"); move_file "$f" "$2" ;;
  move-file) move_file "$1" "$2" ;;
  set) set_field "$1" "$2" "$3" ;;
  # everything else is the human CLI; run from the repo root
  *) if [ "$cmd" != "" ] && [ "$cmd" != "-h" ] && [ "$cmd" != "--help" ] && [ "$cmd" != "help" ] && [ ! -f "$ROOT/index.md" ]; then
       init >/dev/null; echo "(initialised $ROOT)" >&2
     fi
     cli "$cmd" "$@" ;;
esac
