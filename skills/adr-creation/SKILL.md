---
name: adr-creation
description: Creates and maintains dual-format ADRs — Markdown (source of truth for agents) and HTML (rich explainer for humans with diagrams). Keeps both formats in sync on updates. Use when user says "create an ADR", "document this decision", "write an ADR", "ADR for X", or when creating or updating a file in docs/adr/.
author: Mike Scott
version: '2.0.0'
updated: '2026-07-12'
---

# ADR Creation (Dual Format)

## Core Principles

1. **Markdown (`docs/adr/YYYY-MM-DD_kebab-case-title.md`) is the source of truth.**
   - This is what AI agents read.
   - Concise, technical, captures the essence of the decision.

2. **HTML (`docs/adr/html/YYYY-MM-DD_kebab-case-title.html`) is the human-facing explainer.**
   - Richer, more detailed — includes SVG diagrams, explanatory prose, worked examples.
   - **Never a 1:1 translation of the markdown.** Expand freely to help non-technical humans understand.
   - Must convey the same information — never contradict the markdown — but go deeper on background, rationale, and visual presentation.

3. **Both files must stay in sync.** Updating an ADR means updating both formats. Stale HTML is worse than no HTML — it actively misleads human readers.

## File Naming

Both files share the **same name**, differing only by extension:

```
docs/adr/
├── 2026-07-11_three-layer-architecture.md
└── html/
    └── 2026-07-11_three-layer-architecture.html
```

- **Format:** `YYYY-MM-DD_kebab-case-title.md` / `.html`
- The date prefix ensures chronological sorting in directory listings.
- Underscore separates the date from the title.
- All lowercase, kebab-case for the title.
- **Do not use ADR numbering** — numbers clash across branches and create permanent links that break when numbers are reassigned or reordered. Refer to ADRs by date + title in cross-references (e.g. "see Three-Layer Architecture (2026-07-11)").

## Process: Creating a New ADR

### 1. Gather context

Ask the user enough to understand:
- What decision was made?
- What was the problem/context?
- What alternatives were considered?
- Why was this approach chosen?

**Project detection (automatic):** Determine the project name and repo URL:
1. Read `README.md` from the project root — if it has YAML frontmatter with a `name` field, use that as the project name
2. If no frontmatter or no `name` field, extract the first `# ` heading as the project name
3. If neither exists, fall back to the repo name from `git remote get-url origin`
4. Repo URL is always derived from `git remote get-url origin` (see [Cross-Reference URLs](#cross-reference-urls))

### 2. Create the Markdown ADR

Write to `docs/adr/YYYY-MM-DD_kebab-title.md`.

Use the template in the [Markdown Template](#markdown-template) section below.

### 3. Create the HTML ADR

Write to `docs/adr/html/YYYY-MM-DD_kebab-title.html`.

Create the `html/` subdirectory if it doesn't exist.

The HTML version should:
- Use the same information as the markdown (never contradict)
- Expand generously on background, rationale, and consequences
- Include SVG diagrams for architectural flows, data flow, comparison, or decision trees
- Use the established design system (ivory/slate/clay palette — see [HTML Design System](#html-design-system))
- Link back to the markdown on GitHub (both relative and absolute URL)
- Be self-contained (single HTML file, no external dependencies)

**Delegate HTML generation to the `html-output` skill** if available (it handles the design system boilerplate, SVG conventions, and output path). Otherwise embed the design system inline.

### 4. Add cross-links

- **Markdown frontmatter:** include `html` (relative path) and `html_github` (absolute GitHub URL) fields
- **HTML header area:** include a link back to the markdown on GitHub

### 5. Present to the user

Show both files for review before committing. Use the `html-output` skill's link format when presenting HTML files on WSL (prefix with `file://wsl.localhost/Ubuntu-24.04/...`).

## Process: Updating an Existing ADR

### 1. Edit the Markdown first

The markdown is the source of truth. Update all relevant sections (status, date, version, content).

### 2. Regenerate the HTML

Update the HTML to match. Keep the richer explanation and diagrams, but ensure the factual content is consistent with the markdown.

- Update `date`/`updated`/`version` in the YAML frontmatter
- Update `html`/`HTML` in the markdown if the filename changed
- Regenerate the HTML from the updated markdown

### 3. Cross-link consistency

Ensure both files still link to each other correctly.

### 4. Present to the user for review.

## Markdown Template

```markdown
---
title: 'Short Decision Title'
date: YYYY-MM-DD
status: Draft | Accepted | Superseded
deciders: Project lead, Development team
project: Project Name
repo: https://github.com/owner/repo
version: '1.0'
updated: YYYY-MM-DD
html: ./html/YYYY-MM-DD_kebab-title.html
# html_github: https://github.com/{owner}/{repo}/blob/HEAD/docs/adr/html/YYYY-MM-DD_kebab-title.html
# supersedes: Previous ADR Title (YYYY-MM-DD)
---

# Short Decision Title

- **Project:** Project Name — [GitHub](https://github.com/owner/repo)
- **Date:** YYYY-MM-DD
- **Status:** Draft | Accepted | Superseded
- **Deciders:** [list]

## Context

What problem were we solving? What constraints existed? What options were considered?

## Decision

What did we decide and why?

## Consequences

### Positive

1. [benefit]
2. [benefit]

### Negative

1. [trade-off]
2. [trade-off]

## Related

- Previous ADR Title (YYYY-MM-DD): [related decision]
- [file paths or links to relevant code]
```

## HTML Design System

Use these tokens for consistent visual style across all HTML ADRs:

```css
:root {
  --ivory:   #FAF9F5;   /* page background */
  --slate:   #141413;   /* heading text */
  --clay:    #D97757;   /* accent / highlight */
  --oat:     #E3DACC;   /* warm neutral background */
  --olive:   #788C5D;   /* success / positive */
  --rust:    #B04A3F;   /* error / destructive */
  --gray-150:#F0EEE6;   /* subtle panel backgrounds */
  --gray-300:#D1CFC5;   /* borders, dividers */
  --gray-500:#87867F;   /* secondary text / metadata */
  --gray-700:#3D3D3A;   /* body text */
  --white:   #FFFFFF;   /* card backgrounds */
  --serif: ui-serif, Georgia, 'Times New Roman', serif;
  --sans:  system-ui, -apple-system, 'Segoe UI', Roboto, sans-serif;
  --mono:  ui-monospace, 'SF Mono', Menlo, Monaco, monospace;
}
```

- Content max-width: 760-880px
- Body font: 15px sans-serif, line-height 1.6
- Headings: serif font family
- Code blocks: dark background (`--slate`), light text
- Tables: white background, rounded corners, subtle borders
- Status badge: colored chip (olive for Accepted, clay for Draft, etc.)
- Metadata grid: card with key-value pairs
- Callout boxes: info (gray) and warning (amber) variants
- Flow diagrams: SVG or monospace ASCII
- Border radius: 12px for cards/panels

## Cross-Reference URLs

When computing GitHub absolute URLs, use the pattern:

```
https://github.com/{owner}/{repo}/blob/HEAD/docs/adr/YYYY-MM-DD_kebab-title.md
https://github.com/{owner}/{repo}/blob/HEAD/docs/adr/html/YYYY-MM-DD_kebab-title.html
```

Use `HEAD` instead of a branch name — it always resolves to the repository's default branch regardless of whether it's called `master`, `main`, or anything else.

Detect `{owner}` and `{repo}` from the git remote (`git remote get-url origin`).

## Design Notes for the HTML

When writing the HTML version, consider:

- **Who is reading this?** Non-technical stakeholders — project leads, product managers, future team members who need to understand why something was done.
- **What makes it easier to digest?** diagrams > tables > paragraphs. Use SVG flowcharts for architecture decisions, comparison tables for trade-offs, timeline diagrams for sequencing.
- **Structure for scanning:** clear h2/h3 hierarchy, metadata badges, callout boxes for key insights, pro/con columns.
- **Don't be constrained by the markdown.** If the markdown says "three approaches were considered" in a sentence, the HTML can expand each approach into its own subsection with diagrams, pros/cons, and rationale.

## Reference Files

See [template-markdown.md](template-markdown.md) for the full markdown template.
See [template-html.html](template-html.html) for the full HTML boilerplate.
