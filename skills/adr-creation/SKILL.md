---
name: adr-creation
description: Creates and maintains dual-format ADRs — Markdown (source of truth for agents) and HTML (rich explainer for humans with diagrams). Keeps both formats in sync on updates. Use when user says "create an ADR", "document this decision", "write an ADR", "ADR for X", or when creating or updating a file in docs/adr/.
author: Mike Scott
version: '2.2.0'
updated: '2026-07-19'
---

# ADR Creation (Dual Format)

## Core Principles

1. **Markdown** (`docs/adr/YYYY-MM-DD_kebab-title.md`) is the source of truth.
   Concise, technical — for AI agents.

2. **HTML** (`docs/adr/html/YYYY-MM-DD_kebab-title.html`) is the human explainer.
   Rich, narrative, with diagrams. **Lead with the problem** — open with a concrete
   before-state so the reader feels the pain before learning the fix.

3. **Keep both in sync.** Stale HTML is worse than no HTML.

## File Naming

Both files share the same YYYY-MM-DD_kebab-case-title, differing only by extension.
No ADR numbering — numbers clash across branches. Refer by date + title
(e.g. "see Capture Referrer As Intended Login URL (2026-07-19)").

## Process: Creating a New ADR

### 1. Gather context

Ask: What decision was made? What was the problem? What alternatives were considered?
Why was this approach chosen?

Auto-detect project name and repo URL from README.md or `git remote get-url origin`.

### 2. Create the Markdown ADR

Write to `docs/adr/YYYY-MM-DD_kebab-title.md`. Use the template in
[template-markdown.md](template-markdown.md).

### 3. Create the HTML ADR

Write to `docs/adr/html/YYYY-MM-DD_kebab-title.html`. The HTML should:
- Expand freely — diagrams, narrative, safety checks. Never contradict the markdown.
- Follow the **section order** below.
- Use the design system in [html-design-system.md](html-design-system.md) — CSS tokens,
  callout boxes, status badges, metadata grid.
- Follow the narrative guide in [html-narrative-guide.md](html-narrative-guide.md) —
  audience, story examples, readability principles, before/after diagrams.
- Be self-contained (single HTML file, no external dependencies).

Delegate to the `html-output` skill if available for boilerplate and SVG conventions.

#### HTML section order

1. **Problem in plain English** — Concrete before-state example. A story that answers
   "why should I care?"
2. **Why it happened** — Root cause in lay terms. Before/after flow diagrams.
3. **What we changed** — The fix or improvement. Include any safety guards added.
4. **Consequences** — Positive outcomes and trade-offs, in plain language.

### 4. Add cross-links

- Markdown frontmatter: add `html` (relative) and `html_github` (absolute) fields.
- HTML header: link back to the markdown on GitHub.

### 5. Present to the user

Show both files for review before committing. On WSL, link HTML files as
`file://wsl.localhost/Ubuntu-24.04/...`.

## Process: Updating an Existing ADR

1. Edit the markdown first (source of truth).
2. Regenerate the HTML — same narrative depth, consistent facts.
3. Cross-link consistency — both files link to each other correctly.
4. Present for review.

## Cross-Reference URLs

```
Markdown: https://github.com/{owner}/{repo}/blob/HEAD/docs/adr/YYYY-MM-DD_kebab-title.md
HTML:     https://github.com/{owner}/{repo}/blob/HEAD/docs/adr/html/YYYY-MM-DD_kebab-title.html
```

Use `HEAD` (not a branch name). Derive `{owner}` and `{repo}` from `git remote get-url origin`.

## Markdown Notes

- The markdown is for AI agents. Keep it concise and technical.
- Context → Decision → Consequences is sufficient. No narrative treatment.
- Only explain non-obvious system behaviour; skip what's self-evident.

## Reference Files

- [template-markdown.md](template-markdown.md) — Markdown template
- [template-html.html](template-html.html) — HTML boilerplate
- [html-design-system.md](html-design-system.md) — CSS tokens, visual style rules
- [html-narrative-guide.md](html-narrative-guide.md) — Audience, story examples, readability principles, before/after diagrams
