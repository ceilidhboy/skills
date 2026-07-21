---
name: monthly-report-generator
description: Generate monthly development reports for clients using git history, PRs, and ADRs. Research commits/PRs/ADRs for a given repo and date range, then produce a plain-English HTML report for non-technical clients plus a Markdown version for email. Optionally update the project wiki. Use when user says "monthly report", "client report", "development report", "report for [client]", "summarise work", or asks you to document work done over a period.
author: Mike Scott
version: '1.0.0'
updated: '2026-07-21'
---

# Monthly Report Generator

## Quick Start

1. Identify the repo, date range (typically last 1–2 months), and client name.
2. Determine if the repo uses worktrees. If so, locate the `master` worktree.
3. Run the research phase (see Workflow below) using async sub-agents.
4. Compile findings into HTML and Markdown reports using the templates.
5. Optionally update the project wiki.

## Workflow

### 1. Research Phase (delegate to async sub-agents)

Dispatch **4 parallel async sub-agents** to gather evidence:

| Agent | Focus | Key Data Sources |
|-------|-------|-----------------|
| **Infrastructure & Security** | Framework upgrades, dependency changes, security patches, error monitoring, queue systems | `git log` on master, `composer.json` diffs, `config/` changes |
| **Frontend & UI** | Visual changes, new features, mobile fixes, content updates, search refactoring | `git log`, branch diffs, PR descriptions |
| **PDF & Document Systems** | PDF generation, image handling, document architecture | `git log`, `docs/` architecture docs, ADRs |
| **Localisation & Translations** | Multi-language support, AI translation, CSV pipelines, translation fixes | `git log`, `lang/` files, `docs/translation-*` |

Each sub-agent should:
- Read commit messages and dates from `git log --oneline --since="..." --until="..." --format="%ai %h %s"`
- Read PR descriptions via `gh pr list --state merged --json number,title,body,mergedAt`
- Read ADR and architecture docs from `docs/adr/` and `docs/`
- Separate **completed** (merged to `master`) from **in-progress** (unmerged branches)

### 2. Compile Phase

Organise findings into these themes (adjust per project):

1. **Infrastructure & Security** — Framework upgrades, security hardening, monitoring
2. **Search & Navigation** — Property/search refactoring, pagination, mobile menu
3. **PDF/Document Systems** — Generation, image quality, filenames, localisation
4. **Content & Design** — Page updates, CTAs, images, staff data, SEO
5. **Localisation** — Translation pipeline, AI translation, new languages
6. **Work In Progress** — Active unmerged branches clearly separated

For each item, determine:
- **Status** (completed/live or in-progress)
- **Date** (merge date or "Live since" in UK format: `Mon, 13 Jul`)
- **PR reference** (number and branch name)
- **Plain English explanation** — every technical concept needs a glossary entry or lay translation

### 3. Generate HTML Report

Use the `html-output` skill and [report-template.html](report-template.html) for the design system. The HTML must be:
- Self-contained (no external dependencies)
- UK date format with day abbreviations (`Mon, 13 Jul`)
- `Live since` badges with dates on every completed card
- PR boxes with stats (lines changed, merge date)
- Timeline section with chronological milestones
- Stats row (PR count, lines changed, bug fixes, features)
- Glossary callouts for technical terms
- "Work In Progress" section with branch references

### 4. Generate Markdown Version

Produce a Markdown version suitable for email (no images, no complex formatting, plain English). Structure:
- Executive summary (bullet points)
- By-the-numbers stats
- Themed sections matching the HTML report
- For each change: date, description in plain English, PR link

### 5. Update Project Wiki (Optional)

If the project has a wiki:
- Add a "Monthly Development Reports" section to the wiki homepage (`Home.md`)
- Add a bullet point with the date range and a brief summary
- Commit and push the wiki repo (usually at `{project-root}/{repo-name}.wiki/`)

## Reference Files

- [report-template.html](report-template.html) — HTML report template with design system
- [report-template.md](report-template.md) — Markdown report template for email
