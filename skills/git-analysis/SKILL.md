---
name: git-analysis
description: |
  Diagnose a codebase's health from its git history BEFORE reading the code.
  Runs five git commands (churn hotspots, bus factor, bug clusters, velocity
  trend, firefighting frequency), interprets the results, and writes a formatted
  GIT-ANALYSIS.md report with conclusions to the repo root.
  Use when asked to "analyze the git history", "git analysis", "assess this
  codebase", "where are the risky files", or before diving into an unfamiliar repo.
allowed-tools:
  - Bash
  - Read
  - Write
triggers:
  - git analysis
  - analyze the git history
  - assess this codebase
  - risky files
---

# Git Analysis — Diagnose Before You Read

Based on Jakub Piechowski, *"5 git commands I run before reading any code"*
(https://piechowski.io/post/git-commands-before-reading-code/).

**Thesis:** Before reading a single line of code in an unfamiliar repo, build a
diagnostic picture of its health from commit history alone. Git knows which files
break repeatedly, who holds critical knowledge, whether momentum is fading, and how
often the team is firefighting. This skill runs those probes and writes the findings
to `GIT-ANALYSIS.md` in the repo root.

## Procedure

1. **Confirm you're in a git repo.** Run `git rev-parse --show-toplevel`. If it
   fails, tell the user this isn't a git repository and stop. All output goes to
   `<toplevel>/GIT-ANALYSIS.md`.

2. **Run the five probes** (below). Capture raw output for each. If a command
   returns nothing (e.g. no bug-keyword commits, or a repo younger than a year),
   note that explicitly — emptiness is itself a signal.

3. **Interpret and cross-reference.** The highest-value insight is the
   **intersection of churn and bug clusters**: files that appear in both lists are
   the highest-risk code — they break repeatedly and get patched rather than fixed.
   Call these out by name.

4. **Write `GIT-ANALYSIS.md`** to the repo root using the report template below.
   Include the raw command output AND your interpretation. Then give the user a
   short summary in chat with the top 3-5 conclusions.

## The Five Commands

Run each from the repo root. Adjust `--since` windows if the repo is very young or
very old (mention any adjustment in the report).

### 1. Code churn hotspots — the 20 most-modified files (last year)
```bash
git log --format=format: --name-only --since="1 year ago" | sort | uniq -c | sort -nr | head -20
```
High-churn files are often "a patch on a patch": unpredictable blast radius,
inflated estimates, the code most likely to surprise you.

### 2. Bus factor — knowledge concentration
```bash
git shortlog -sne HEAD --no-merges
```
Note: pass an explicit revision (`HEAD`). Without one, `git shortlog` reads from
stdin when stdout isn't a terminal — so in non-interactive shells it silently
returns nothing. If it still comes back empty, fall back to
`git log --format='%an <%ae>' | sort | uniq -c | sort -nr`.
One person owning 60%+ of commits is a critical dependency risk — especially if
their recent activity has dropped off. Note the top contributors and their share.

### 3. Bug clusters — files with the most bug-related commits
```bash
git log -i -E --grep="fix|bug|broken" --name-only --format='' | sort | uniq -c | sort -nr | head -20
```
Files that repeatedly attract bug fixes. **Cross-reference with #1** — overlap =
highest-risk code.

### 4. Velocity trend — commits per month over full history
```bash
git log --format='%ad' --date=format:'%Y-%m' | sort | uniq -c
```
A declining curve signals fading momentum; a sudden drop often correlates with a
key person leaving. Read the recent months against the peak.

### 5. Firefighting frequency — reverts, hotfixes, rollbacks (last year)
```bash
git log --oneline --since="1 year ago" | grep -iE 'revert|hotfix|emergency|rollback'
```
Frequent hits indicate deployment instability — unreliable tests, missing staging,
or a pipeline that makes safe rollbacks hard. Report the count and any clusters.

## GIT-ANALYSIS.md template

```markdown
# Git Analysis

> Repository: `<repo name / path>`
> Generated: <date> • Analysis window: <e.g. last 12 months / full history>
> Method: history-based diagnostics (per piechowski.io)

## TL;DR
- <3-5 bullet conclusions, sharpest first — highest-risk files, bus factor, trend>

## 1. Code Churn Hotspots
<raw output, as a code block or table>

**Read:** <which files are churn-heavy and what it implies>

## 2. Bus Factor
<raw output>

**Read:** <concentration %, who, recency of activity, risk level>

## 3. Bug Clusters
<raw output>

**Read:** <bug-magnet files; explicitly list files that ALSO appear in §1>

## 4. Velocity Trend
<raw output, or a compact summary of the monthly series>

**Read:** <trend direction, notable peaks/drops>

## 5. Firefighting Frequency
<raw output / count>

**Read:** <stability assessment>

## Highest-Risk Code (churn ∩ bugs)
- `path/to/file` — <why>

## Where to start reading
<2-4 concrete suggestions on what to read first given the findings>
```

## Notes
- Keep raw output trimmed to what's informative (the `head -20` caps already help).
- Be honest when a signal is weak (young repo, squash-merge history that hides
  authorship, conventional-commit noise) — say so rather than over-reading it.
- This is read-only on the repo; the only file written is `GIT-ANALYSIS.md`.
