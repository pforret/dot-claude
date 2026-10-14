---
name: todo
description: >
  Per-repo todo management under docs/todo/. "/todo" lists planned items with reference numbers,
  "/todo init" scaffolds the folders, "/todo add <text>" creates an item, "/todo <n> plan" researches
  item n and writes a PRP (Product Requirements Prompt) with clarifying questions until 9/10
  confidence (moves it to docs/todo/plan), "/todo <n>" or "/todo <n> execute" starts/implements item n
  (moves it to docs/todo/busy), "/todo <n> done" verifies and archives it to docs/todo/done,
  "/todo <n> skip" asks for a reason and moves it to docs/todo/skipped. IDs: 1,2 = planned,
  P1,P2 = plan, B1,B2 = busy; a bare "/todo done" refers to the item last started.
  This skill replaces the former /generate-prp and /execute-prp commands.
  Use when asked to "show the todo list", "plan todo 3", "write a PRP for", "generate a PRP",
  "execute the PRP", "start todo 3", "mark todo 2 done", "skip todo item",
  or "set up todo tracking for this repo".
---

# todo — per-repo todo items in docs/todo/

All state lives in the current repo under `docs/todo/`:

```
docs/todo/
  index.md                       planned items (numbered table)   ← source for "/todo"
  <yyyy-mm-dd>.<type>.<slug>.md  one planned item per file
  plan/index.md  + items         planned in depth (PRP written, confidence ≥ 9/10), waiting for execute
  busy/index.md  + items         in progress
  done/index.md  + items         finished
  skipped/index.md + items       deliberately not done (with reason)
```

Lifecycle: `planned → (plan) → busy → done | skipped`. The `plan` stage is optional: small,
unambiguous items go straight from planned to busy with `/todo <n>`.

`<type>` is one of `bug`, `change`, `feature`.

**IDs** are positional per table and carry a table prefix so they are never ambiguous:

| ID form | Table | Example |
|---------|-------|---------|
| `1`, `2`, … | planned (`docs/todo/`) | `/todo 2 plan` |
| `P1`, `P2`, … | plan (`docs/todo/plan/`) | `/todo P1 execute` |
| `B1`, `B2`, … | busy (`docs/todo/busy/`) | `/todo B1 done` |
| `<filename>.md` | any table | `/todo 2026-10-14.feature.add-login.md done` |
| (none) | the item last started | `/todo done`, `/todo skip` |

The n-th row of a table is the n-th file sorted by name (i.e. by date). IDs shift when items move,
so always re-list after a move and never store an ID inside an item. `todo.sh path <id>` resolves
any of these forms to a file path; use it instead of parsing tables yourself.

`docs/todo/.current` holds the filename of the item last moved to busy (written by the helper on
every move to busy, cleared when that item leaves busy). A bare `/todo done` / `/todo skip` /
`/todo show` means that item; if the file is missing and exactly one item is busy, that one is
meant; otherwise ask which `B<n>`.

**Always use the helper** `bash <skill-dir>/todo.sh` (skill-dir = the directory holding this
SKILL.md) for folder setup, listing, moving, frontmatter edits and index rebuilding. It rewrites
every `index.md` from the files on disk, so indexes never drift. Run it from the repo root.

```
todo.sh init | list | reindex
todo.sh path <id>                           → file path for 1 / P1 / B1 / filename / "" (= current)
todo.sh current                             → file path of the item last started
todo.sh move <id> <plan|busy|done|skipped>  → move item <id>
todo.sh move-file <file> <plan|busy|done|skipped>
todo.sh set <file> <key> <value>            → set a frontmatter field (e.g. confidence)
```

## Shell command `todo`

`todo.sh` is also symlinked in `$PATH` as `todo` / `todo.sh`. Run outside Claude, it is a thin
launcher: `todo` prints usage, `todo i` lists, `todo p` is an fzf picker, `todo <id> [execute|plan|done]`
starts `claude "/todo <file> <verb>"`, and `todo <id> skip` asks the reason and moves the file itself.
Bare `todo done|skip|show` act on the current item.
Inside Claude you never call those CLI verbs; use the skill-internal commands listed above.

## Auto-init

Before any command other than `init`: if `docs/todo/index.md` does not exist, run
`todo.sh init` first and mention that you did. (`init` is also safe to run on an older
`docs/todo/` that has no `plan/` folder yet; it just adds it.)

## Dispatch on arguments

| Argument            | Action |
|---------------------|--------|
| (empty)             | LIST |
| `init`              | INIT |
| `add <text>`        | ADD |
| `<id> plan`         | PLAN item (write a PRP, ask questions until 9/10 confidence); planned items only |
| `<id>`              | START item (planned `n` or plan `Pn`) |
| `<id> execute`      | START item (same thing; the natural verb after a PLAN) |
| `<id> done`         | DONE item (normally `Bn`) |
| `<id> skip`         | SKIP item (any table) |
| `<id> show`         | print the item file |
| `done` / `skip` / `show` | same, for the current item (see IDs above) |

`<id>` may be prefixed with `#`. Resolve every form with `todo.sh path <id>`; if it prints an error
(out of range, unknown table, no current item) show the list and stop. `plan` on a `Pn`/`Bn` item,
or `execute` on a `Bn` item, is a no-op: say the item is already in that stage.

## INIT

Run `todo.sh init`. Creates `docs/todo/` with `plan/`, `busy/`, `done/` and `skipped/` plus an
`index.md` in each. Idempotent: creates only missing folders and (re)builds indexes, never deletes
items. Report the resulting path. If the repo has a CLAUDE.md, offer nothing else, do not edit it.

## LIST

Run `todo.sh list` and show its output verbatim (the planned table, plus the plan and busy tables
if anything is there). Do not paraphrase the tables. If empty, say so and show the usage forms
`/todo add <text>`, `/todo <n> plan` and `/todo <n>`.

## ADD (`/todo add <text>`)

1. **Classify the type** from the text:
   - `bug` — something existing behaves wrongly
   - `change` — modify/improve/refactor existing behaviour
   - `feature` — net-new capability
2. **Estimate the size** by actually looking at the codebase (grep/read the areas the text
   mentions) and listing the files that would plausibly change:
   - `small` — 1–2 files
   - `medium` — 3–10 files
   - `large` — >10 files or architectural change (new subsystem, schema/API redesign, framework swap)
3. **Slug**: 2–6 lowercase words, hyphenated, from the title (e.g. `fix-login-redirect`).
4. **Write** `docs/todo/<yyyy-mm-dd>.<type>.<slug>.md` (today's date, ISO) using this template:

```markdown
---
title: <short imperative title>
type: bug | change | feature
size: small | medium | large
status: planned
created: <yyyy-mm-dd>
files:
  - path/to/file.ext        # one per line; "(unknown)" if not yet determinable
---

# <title>

## Request
<the user's text, verbatim>

## Analysis
<why it is a bug/change/feature, what part of the system is involved, any risks or open questions>

## Impacted files
<bullet list with a one-line reason each>

## Plan
<numbered steps to implement>

## Acceptance criteria
<bullet list — how we will know it's done>
```

5. Run `todo.sh reindex`, then show the new item's reference number and one-line summary.
   If the same title already exists as a planned item, append to it instead of creating a duplicate
   and say so. For `medium`/`large` items, suggest `/todo <n> plan` before starting.

## PLAN (`/todo <n> plan`)

Turns a planned item into a PRP: a self-contained brief that lets an agent implement the item in
one pass with only the item file and the repo. This replaces the old `/generate-prp`.

1. `todo.sh path <id>` → read the item file fully.
2. `todo.sh move <id> plan` → print the new path. From now on the item has a `P<n>` ID
   (re-list to show it).
3. **Research** (do all of this before writing anything):
   - *Codebase*: find similar features/patterns and the conventions they follow, the files to
     reference or mirror, the test patterns and the lint/test commands that exist (package.json,
     composer.json, Makefile, CI config). Read CLAUDE.md and any `docs/agents/` knowledge base.
   - *External*: for libraries/APIs involved, find the documentation URLs with the specific
     sections, known pitfalls and version quirks. Pass URLs, not summaries.
   - *Options*: list every decision that is genuinely open: architecture, library choice, data
     model, UX behaviour, scope boundaries, backwards compatibility, naming the user may care about.
4. **Score your confidence** 1–10 that an agent can implement this in one pass from the PRP alone.
   Be honest: an open design decision, an unknown integration, or no executable validation each
   cost points.
5. **Ask until ≥ 9/10.** While confidence < 9, use AskUserQuestion with the open options
   (up to 4 questions per round, each with 2–4 concrete options, your recommendation first and
   marked "(Recommended)", with the trade-off in each description). Record every answer under
   `### Decisions taken`. Re-score, and repeat rounds until ≥ 9. Never pad the score to escape
   the loop; if the user says "just pick", use your recommendation and note that in the decision.
   When the user cannot answer (needs to check something), stop here, leave the item in `plan/`
   with its current confidence, and say what is still open.
6. **Write the PRP**: append the sections from `<skill-dir>/prp_template.md` to the item file
   (after `## Acceptance criteria`), fully filled in, and update the earlier sections so they
   agree with the decisions (`## Plan` becomes a short pointer to the blueprint, `files:` and
   `size:` are corrected). Then `todo.sh set <path> confidence <n>` and `todo.sh reindex`.
   Quality gate before saving: all needed context included · validation commands are real and
   executable in this repo · existing patterns referenced by path · clear ordered tasks · error
   handling covered.
7. **Finish** by re-listing and telling the user, verbatim in form:
   `Plan ready (<n>/10). Start the implementation with "/todo P<k> execute" (or just "/todo P<k>").`
   where `P<k>` is the item's ID in the plan table. Do **not** start implementing.

## START (`/todo <id>` or `/todo <id> execute`)

`<id>` is `n` (planned) or `Pn` (plan). This replaces the old `/execute-prp` when the item has a PRP.

1. `todo.sh path <id>` → read the item file fully.
2. `todo.sh move-file <path> busy` (sets `status: busy`, adds `busy_at`, moves the file, rebuilds
   indexes and records it as the current item). Print the new path and its new `B<n>` ID.
3. **If the item has a `## PRP` section**: follow it. Read every file and URL under "Context the
   implementer MUST read", extend the research only where the PRP points at something that has
   changed, then execute the blueprint tasks in order, tracking them with your task list. Run the
   validation loop level by level; fix and re-run until each level passes (never mock to pass).
   Re-read the PRP at the end to check nothing was skipped.
   **If it has no PRP**: execute the item's `## Plan` directly: implement the change, run the
   relevant tests/linters.
   In both cases update the item file's plan/blueprint with checkmarks and notes as you go, and
   jot down deviations from the spec and discoveries the moment they happen (a `## Notes` section
   is fine); DONE turns them into the Result section.
   If the item is `large` or you find an open design decision mid-way and it has no PRP,
   suggest `/todo <n> plan` instead of guessing.
4. Do not mark it done automatically — the user decides with `/todo done` (current item) or
   `/todo B<n> done`.

## DONE (`/todo done` or `/todo <id> done`)

Bare `done` = current item (`todo.sh path ""`). Otherwise `<id>` is normally a `Bn`.

1. Read the item fully (Request, Acceptance criteria, Plan/PRP, and any notes added during START).
2. **Verify it is actually done**: check every acceptance criterion (and, if there is a PRP, every
   validation command and success criterion) against the working tree: grep for the change, run the
   tests/linters named in the plan, look at `git status`/`git log`/`git diff`. Keep the exact
   commands and their outcome; they go into the file. If anything is unmet, say exactly what and
   stop — do not write the Result section and do not move the file.
3. **Always append a `## Result` section** to the item file, with these four sub-sections (write
   "none" rather than omitting one):

```markdown
## Result

### Verification
<one bullet per acceptance criterion / validation gate: the command or check that was run and its
 outcome, e.g. "`composer test` → 42 passed", "grep confirms `oldName` no longer referenced">

### Deviations from the spec
<where the implementation differs from the Request, Plan or PRP, and why: scope dropped or added,
 a different approach, a decision taken that the plan left open. "none" if it matched exactly>

### Discoveries
<things learned during execution worth keeping: surprising behaviour, hidden coupling, bugs found
 elsewhere, tech debt noticed, follow-up work that should become its own todo item>

### Changes
<files touched (one line each), commits involved if any>
```

   Base this on what actually happened in the session and on the notes/checkmarks in the item's
   Plan or blueprint, not on what the plan intended. If a Discovery deserves follow-up, offer to
   create it with `/todo add` after the move; do not create it silently.
4. Move: `todo.sh move-file <path> done` (sets `status: done`, `done_at`, clears the current item).
   Report the new path.

## SKIP (`/todo skip` or `/todo <id> skip`)

Bare `skip` = current item. Any table is allowed.

1. **Ask the user for the reason** (AskUserQuestion, free text) — never guess or skip without one.
2. Append `## Skipped\n\n<reason>` to the item file.
3. Move: `todo.sh move-file <path> skipped` (works for planned, plan or busy items). Report the new path.

## Rules

- Never delete item files; every item ends in `done/` or `skipped/`.
- Never hand-edit an `index.md` or `.current`; always go through `todo.sh`.
- Item filenames are immutable once created (they are the stable identity).
- Use `git mv` semantics (the helper does this when the file is tracked) so history follows the file.
- Do not commit unless the user asks.
