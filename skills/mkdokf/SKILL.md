---
name: mkdokf
description: >
  Create and maintain an OKF-format agent knowledge base under docs/agents/ for any repo.
  "/mkdokf init" scaffolds the bundle with sections adapted to the repo's content (a pure code
  library gets no operations/ or design/). "/mkdokf <some information>" files that information
  into the right doc — updating or creating docs, and keeping indexes, cross-links, frontmatter
  timestamps, and the log up to date. Use when asked to "init the agent docs", "set up docs/agents",
  "add this to the agent docs / knowledge base", or "document this decision".
---

# mkdokf — OKF agent knowledge base

Builds and maintains `docs/agents/` — a bundle of markdown concept docs with YAML frontmatter,
following the [OKF v0.1 spec](https://github.com/GoogleCloudPlatform/knowledge-catalog/blob/main/okf/SPEC.md),
written FOR coding agents: exact values, exact file paths, decisions with reasoning. It goes one
level deeper than CLAUDE.md and never contradicts it (fix drift in both when found).

**First, read `reference.md` in this skill's directory** — it holds the OKF rules, file templates,
the section menu, and style rules. Everything below assumes those conventions.

## Dispatch on arguments

- `init` → INIT mode (scaffold the bundle)
- anything else → ADD mode (file that information into the bundle)
- empty → print a one-paragraph status: does `docs/agents/index.md` exist, how many sections/docs,
  and the two usage forms. Do nothing else.

Always finish either mode by running `bash <skill-dir>/validate.sh [bundle-dir]` and fixing every
finding before reporting done.

## INIT mode

1. **Guard.** If `docs/agents/index.md` already exists, stop and say so — suggest ADD mode instead.
   Never overwrite an existing bundle.

2. **Survey the repo** before deciding structure (parallel Explore agents for large repos, direct
   reads for small ones). Determine: project type (app / library / CLI / service), languages and
   frameworks, whether it has a UI, tests, CI, deployment story, AI/LLM usage, a docs site
   (mkdocs/docusaurus — affects link rules), and where decisions hide (ADRs, done PRPs/RFCs,
   `git log` for migrations/renames/"switch to X" commits, load-bearing config comments).

3. **Pick sections** from the menu in `reference.md` — only those the repo actually warrants
   (architecture/ and decisions/ almost always qualify; a headless library gets no design/, a
   non-deployed library no operations/). Invent a section not on the menu when the repo has a
   domain that deserves one (e.g. `api/`, `cli/`, `data/`) — the menu is examples, not a cage.

4. **Research each section's facts from the code** — configs, entry points, schemas, CI files,
   env samples. Rules: every number/path/name you write must be verifiable by a grep you could run;
   what you can't verify, don't write; what's genuinely unknown but belongs (prod specs, URLs),
   write explicitly as "not on record" with a fill-in placeholder. Existing good docs in the repo
   are migration candidates: move them in (`git mv`), add frontmatter, verify their claims against
   current code (migrated docs are stale more often than not), and delete/redirect the original —
   move, don't copy.

5. **Reconstruct decisions** (target 8–16 records for a mature repo, fewer is fine for a young one)
   from git history, ADR/PRP archives, and "intentional — don't change" comments. Each uses the ADR
   template in `reference.md`. Cross-link superseding pairs both directions.

6. **Write the bundle**: root `index.md` (the only index with frontmatter: `okf_version: "0.1"`),
   `log.md` with a Creation entry, then per section `index.md` + concept docs per the templates.

7. **Wire into CLAUDE.md** (if the repo has one): add/extend an "## Agent documentation" section —
   one short paragraph per section index, each naming its path and the kind of info inside. If
   there is no CLAUDE.md, mention the bundle in the README's development section instead.

8. **Validate** (see above), then report: sections chosen and why, sections skipped and why,
   doc count, and any drift found between existing docs and code.

## ADD mode

The argument is information to file: a fact, a decision, a correction, a chunk of prose, or a
pointer to something ("document how X works").

1. **Locate the bundle.** No `docs/agents/index.md` → stop, suggest `/mkdokf init`.

2. **Verify before writing.** If the info makes checkable claims about the code, check them
   (grep/read). If the code disagrees, the code wins — say so and write what's true. Convert
   relative dates ("since last week") to absolute ISO dates.

3. **Route it.** Read the root index + section indexes (cheap: they're listings) to find the home:
   - Fits an existing concept doc → edit that doc; bump its frontmatter `timestamp`.
   - Is a decision (a choice with alternatives/consequences, "we decided", "don't do X because") →
     new `decisions/YYYY-MM-DD-slug.md` from the ADR template, dated by when the decision was made
     (today if new). If it reverses/amends an existing record, wire `supersedes`/`superseded_by`
     both ways instead of silently editing history.
   - New topic in an existing section → new concept doc with full frontmatter.
   - No section fits → create the section (index.md + doc), add it to the root index, and — if
     CLAUDE.md has an "Agent documentation" section — add its paragraph there.
   When genuinely ambiguous between two homes, put the content in ONE doc and a cross-link in the
   other; never duplicate the content.

4. **Keep the bundle consistent** — this is the point of the command:
   - New doc → listed in its section's `index.md` (`* [Title](file.md) - description` format).
   - `log.md` gets an entry under today's date (newest date-group first): `**Creation**` for new
     docs, `**Update**` for edits, with `[Title](path)` links.
   - Add cross-links from related existing docs when the new info is load-bearing for them.
   - Respect style rules (`reference.md`): ≤150 lines/doc, tables over prose, code spans (never
     markdown links) for source-file paths.

5. **Validate**, then report in one or two sentences: where the info landed and why, what was
   created vs updated, any claim corrected against the code.
