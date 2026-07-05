# mkdokf reference — OKF rules, templates, section menu, style

## OKF v0.1 operative rules

- A **bundle** = a directory tree of markdown files rooted at `docs/agents/`.
- Reserved filenames (lowercase): `index.md` (directory listing) and `log.md` (update history).
  Never use them for concept docs. Treat `tags.md` as reserved too if the repo's docs site uses a
  tags plugin.
- **Every concept doc** starts with YAML frontmatter. Required: `type`. Recommended: `title`,
  `description` (one sentence), `tags` (YAML list), `timestamp` (ISO 8601). Extra keys allowed
  (used for `status`, `supersedes`, `superseded_by` on decision records).
- **Index files have NO frontmatter** — except the bundle-root `index.md`, which may carry only
  `okf_version: "0.1"`.
- Index format: intro line(s), then sections of bullets: `* [Title](relative-file.md) - short description`
- `log.md`: `# Directory Update Log`, then `## YYYY-MM-DD` groups (newest first) with
  `* **Creation**: …` / `* **Update**: …` bullets linking the affected docs.
- Cross-links: relative markdown links between docs. Consumers tolerate broken links, but this
  skill does not — validate.sh checks them.
- Optional body conventions: `# Schema`, `# Examples`, `# Citations` (numbered
  `[1] [Title](url-or-path)` list — use it on decision records and migrated docs).

## Type values

Pick from this set for consistency; extend it only when a new section genuinely needs a new type
(record the addition in the root index prose):

`Design Guideline` · `Architecture Guide` · `Operations Runbook` · `Decision Record` ·
`AI Guideline` · `Testing Guide` · `Reference` · `API Guide` · `CLI Guide` · `Product Guide`

## Section menu (pick what the repo warrants; invent others when justified)

| Section               | Include when                                                | Typical docs                                                                                                                  |
|-----------------------|-------------------------------------------------------------|-------------------------------------------------------------------------------------------------------------------------------|
| `architecture/`       | almost always                                               | core flow/pipeline, data models, storage, module layout, domain economies                                                     |
| `decisions/`          | almost always                                               | ADR-style records mined from git/ADRs/PRPs/config comments                                                                    |
| `testing/`            | a test suite exists                                         | runner conventions, DB/fixture rules, CI skips, guard tests                                                                   |
| `design/`             | the repo ships UI or designed artifacts (web, PDF, TUI)     | fonts, colors, theming, component conventions, brand assets                                                                   |
| `operations/`         | the repo is deployed/run somewhere                          | env vars, infrastructure (DB/storage/dimensioning), deployment, CI/CD, monitoring, maintenance                                |
| `ai/`                 | the repo calls LLMs/AI services                             | models & providers, cost monitoring, modalities, prompt conventions                                                           |
| `api/`                | the repo is a library or exposes a public API               | public surface, versioning/compat rules, usage patterns                                                                       |
| `cli/`                | the repo is/ships a CLI                                     | commands, flags, exit codes, shell conventions                                                                                |
| `product/`            | the repo is a product with business context worth recording | product vision, competitor landscape, marketing approach, responsibilities (software dev, marketing, product mgt, support, …) |
| `rating/`, `data/`, … | a domain-specific reference corpus exists                   | per-entity reference pages + an overview                                                                                      |

`product/` is the one section whose facts are mostly **not code-verifiable** — they come from the
user, existing product/business docs, or public sources (competitor sites). Ask rather than infer
vision/positioning; date market claims (competitor features change); name people/roles only as the
user states them.

## Templates

### Concept doc frontmatter

```markdown
---
type: Architecture Guide
title: QC Pipeline
description: One sentence saying what this doc answers.
tags: [queues, jobs, pipeline]
timestamp: 2026-07-04T00:00:00Z
---

# Title

Dense content: tables over prose, exact values, `file/paths.php` as code spans.
```

### Root index.md (the ONLY index with frontmatter)

```markdown
---
okf_version: "0.1"
---

# <Project> Agent Knowledge Base

Documentation bundle for coding agents (OKF v0.1). Concept docs carry YAML frontmatter
(`type` required); every folder has an `index.md`. These docs go one level deeper than
CLAUDE.md — exact values, exact file paths, and the reasoning behind non-obvious choices.
When a doc and the code disagree, the code wins: fix the doc.

# Sections

* [Architecture](architecture/index.md) - one-line hook
* [Decisions](decisions/index.md) - decision records with motivation, consequences, drawbacks
```

### Section index.md (no frontmatter)

```markdown
# Architecture

One or two intro lines saying what belongs here.

* [QC Pipeline](qc-pipeline.md) - short description
* [Data Models](data-models.md) - short description
```

### log.md

```markdown
# Directory Update Log

## 2026-07-04

* **Creation**: Established the bundle with [Architecture](architecture/index.md), …
```

### Decision record (`decisions/YYYY-MM-DD-slug.md`)

```markdown
---
type: Decision Record
title: Short imperative title
description: One sentence: what was decided and the core why.
tags: [domain, topic]
timestamp: 2026-07-04T00:00:00Z
status: accepted            # accepted | superseded
# supersedes: other-record.md     (both directions when applicable)
# superseded_by: other-record.md
---

# Title

**Date:** YYYY-MM-DD (when decided, not when documented)

## Decision
What was decided, concretely.

## Motivation
Why — the problem and the forces.

## Consequences
What follows (including advantages); what other docs/code now rely on this.

## Drawbacks / Alternatives considered
What was rejected and why; accepted costs; deferred follow-ups (recorded so they
aren't re-proposed piecemeal).

# Citations

[1] Source: PR/PRP/commit/file that evidences this
```

## Style rules

- **≤150 lines per doc.** These are lookup cards, not essays. Tables beat prose.
- **Exact values**: hex codes, env vars with defaults, cadences, versions, paths.
- **Source-file paths as code spans**, never markdown links (`app/Services/Foo.php` — a link like
  `[Foo](../../app/Services/Foo.php)` breaks docs-site builds like MkDocs and rots on refactors).
- **Verify, don't invent.** Every claim greppable; unknowns marked "not on record".
- **One home per fact** — cross-link from elsewhere, never paste twice.
- **Decisions are history**: never rewrite a superseded record to match the present; add a new
  record and wire supersedes/superseded_by.
- Dates absolute ISO (`2026-07-04`), never "recently"/"last month".
- Binary source material (images, PDFs) goes in a `references/` subfolder inside its section,
  unlisted in the index.
