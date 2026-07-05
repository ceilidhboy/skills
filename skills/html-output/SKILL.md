---
name: html-output
description: >-
  HTML output generator for output that would benefit from being presented in
  a visually rich document. Use when communicating architectural plans, design
  options, code review summaries, workflows, comparisons, novel concepts, color
  choices, or any information that benefits from visual illustration — inline
  SVG diagrams, color swatches, structured comparison grids, interactive
  controls. Not needed for simple lists, linear text, or straightforward data
  using well-understood terminology.
compatibility: Any agent harness supporting HTML output
---

# HTML Output

Generate self-contained HTML documents instead of Markdown when the
information benefits from visual illustration. Read the supporting files
below as needed for the specific task.

## Output Location

Resolve the output directory using this fallback chain:

1. **Environment variable** `PI_HTML_OUTPUT_DIR` — if set, use this path
2. **Pi global settings** — check `htmlOutputDir` key in `~/.pi/agent/settings.json`
3. **Fallback** — use `~/.pi/agent/html-output/` (creates it if needed)

Name files descriptively, e.g. `oauth-flows-explainer.html`.

### Presenting the result

When the file is written, present the clickable link to the user on its own
line, prefixed with the pointing-finger emoji:

👉 **`file:///C:/Users/YourName/Documents/Pi%20Output/filename.html`**

- If `htmlOutputFileUri` is set, construct the link by replacing `{filename}`
  with the actual filename, then present it as above.
- If `htmlOutputFileUri` is not set, present the raw filesystem path instead:

👉 **`/home/user/output/filename.html`**

This format is mandatory — every agent invoking this skill must use the
👉 emoji before the file link in its response. This applies universally
across all users, platforms, and sessions.

### Windows / WSL file:// URIs

On Windows with WSL, the resolved path (e.g. `/mnt/c/Users/...`) is correct for
file operations but won't work as a clickable link. To produce a working
`file://` URI in the agent's response, use one of these settings in
`~/.pi/agent/settings.json`:

#### Option A: `htmlOutputFileUri` (filename template)

```json
"htmlOutputFileUri": "file:///C:/Users/YourName/Documents/Pi%20Output/{filename}"
```

The placeholder `{filename}` is replaced with the actual output filename. When
this setting is present, the agent reports a clickable link instead of the raw
filesystem path.

#### Option B: `htmlOutputFileUriPrefix` (WSL path prefix)

```json
"htmlOutputFileUriPrefix": "file://wsl.localhost/Ubuntu-24.04"
```

When this setting is present, the agent presents the link as:

👉 **`{prefix}/home/.../full/filesystem/path/to/filename.html`**

Where `{prefix}` is the value of `htmlOutputFileUriPrefix`. The agent appends
the full filesystem path (from `/home` onwards) to the prefix to form the
clickable WSL link.

Prefer this option when the project files live directly on the WSL filesystem
and don't have a C: drive equivalent. The agent outputs the HTML file to the
project's `docs/adr/html/` directory (not to a separate Pi Output directory).

**Setup instructions for Pi agents:** When a user says "set up HTML output"
or "I'm on Windows/WSL and the links don't work", do this:

1. Check if `htmlOutputDir` is already set in `~/.pi/agent/settings.json`
2. If using a C: drive path:
   - Convert `/mnt/c/...` → `file:///C:/...`
   - Replace spaces with `%20`
   - Append `/{filename}` and write it as `htmlOutputFileUri`
3. If using WSL native paths:
   - Get the WSL distro name from the user (e.g. `Ubuntu-24.04`)
   - Write `"htmlOutputFileUriPrefix": "file://wsl.localhost/{distro}"`
   - The agent will append the full filesystem path from `/home` onwards
4. Note the change to the user so they know what was set

## Decision Heuristic

> *"Would the human reader get more understanding from **seeing** this than from **reading** it?"*

**Use HTML when** the information has *depth* — novel concepts, relationships,
tradeoffs, workflows, color choices — anything requiring mental visualization.

**Use Markdown when** the information is *wide* — linear lists using standard
terminology that carries the meaning. HTML adds no cognitive value there.

**Cost awareness:** HTML takes 2-4× longer to generate. Only use when the
cognitive benefit justifies the cost.

## Supporting Files

| File | When to read it |
|---|---|
| [DESIGN_SYSTEM.md](references/DESIGN_SYSTEM.md) | When building the HTML — contains color palette, typography, layout tokens, CSS patterns, and HTML boilerplate. **Swap this file to use a custom design system.** |
| [SVG_GUIDELINES.md](references/SVG_GUIDELINES.md) | When a diagram or illustration would help — contains SVG conventions, diagram types (flowchart, timeline, fan-out), and download button code. |
| [TEMPLATES.md](references/TEMPLATES.md) | When choosing a document structure — contains 7 use case templates with prompt patterns for exploration, code review, design, reports, explainers, slide decks, and custom editors. |

## References

- Blog post: https://claude.com/blog/using-claude-code-the-unreasonable-effectiveness-of-html
- Examples: https://thariqs.github.io/html-effectiveness/
- GitHub: https://github.com/thariqs/html-effectiveness
