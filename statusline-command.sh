#!/usr/bin/env bash
# Claude Code statusLine command
# Reads JSON from stdin and outputs a colored status line

input=$(cat)

# ANSI colors
CYAN='\033[36m'
YELLOW='\033[33m'
MAGENTA='\033[35m'
RESET='\033[0m'

# --- 1) Folder/repo details (cyan) ---
cwd=$(echo "$input" | jq -r '.workspace.current_dir // .cwd // empty')
dir=$(basename "$cwd")

php_ver=$(php -r 'echo PHP_MAJOR_VERSION.".".PHP_MINOR_VERSION;' 2>/dev/null)

# Repo version: VERSION.md or latest git tag
repo_ver=""
if [ -f "$cwd/VERSION.md" ]; then
  repo_ver=$(head -1 "$cwd/VERSION.md" | tr -d '[:space:]')
elif [ -d "$cwd/.git" ]; then
  repo_ver=$(git -C "$cwd" --no-optional-locks describe --tags --abbrev=0 2>/dev/null)
fi

folder_parts=("$dir")
[ -n "$repo_ver" ] && folder_parts+=("v$repo_ver")
[ -n "$php_ver" ]  && folder_parts+=("php:$php_ver")
folder_str="${folder_parts[*]}"

# --- 2) Git details (yellow) ---
git_branch=$(git -C "$cwd" --no-optional-locks branch --show-current 2>/dev/null)
git_str=""
if [ -n "$git_branch" ]; then
  porcelain=$(git -C "$cwd" --no-optional-locks status --porcelain 2>/dev/null)
  staged=$(echo "$porcelain" | grep -c '^[MADRC]')
  modified=$(echo "$porcelain" | grep -c '^.M\|^M')
  untracked=$(echo "$porcelain" | grep -c '^??')
  git_str="$git_branch"
  [ "$staged" -gt 0 ]    && git_str="$git_str +$staged"
  [ "$modified" -gt 0 ]  && git_str="$git_str ~$modified"
  [ "$untracked" -gt 0 ] && git_str="$git_str ?$untracked"
  git_str="[$git_str]"
fi

# --- 3) Claude details (magenta) ---
model=$(echo "$input" | jq -r '.model.display_name // empty' | sed 's/Claude //' | sed 's/ /-/g')
used_pct=$(echo "$input" | jq -r '.context_window.used_percentage // empty')
if [ -n "$used_pct" ]; then
  used_int=${used_pct%.*}
  ctx="${used_int}%ctx"

  # Progress bar: 20 chars, color based on usage
  bar_len=20
  filled=$(( used_int * bar_len / 100 ))
  empty=$(( bar_len - filled ))
  if [ "$used_int" -ge 80 ]; then
    BAR_COLOR='\033[31m'   # red
  elif [ "$used_int" -ge 60 ]; then
    BAR_COLOR='\033[33m'   # orange/yellow
  else
    BAR_COLOR='\033[90m'   # grey
  fi
  bar="${BAR_COLOR}"
  for ((i=0; i<filled; i++)); do bar+="█"; done
  DIMMED='\033[90m'
  bar+="${DIMMED}"
  for ((i=0; i<empty; i++)); do bar+="░"; done
  bar+="${RESET}"
else
  ctx="ctx:?"
  bar=""
fi
claude_parts=()
[ -n "$model" ] && claude_parts+=("$model")
claude_parts+=("$ctx")
claude_str="${claude_parts[*]}"
[ -n "$bar" ] && claude_str="$claude_str $bar"

# Assemble with colors
output="${CYAN}${folder_str}${RESET}"
[ -n "$git_str" ] && output="$output ${YELLOW}${git_str}${RESET}"
output="$output ${MAGENTA}${claude_str}${RESET}"

printf '%b' "$output"
