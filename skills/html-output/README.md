# html-output

Generate self-contained HTML documents instead of raw Markdown when the
information benefits from visual illustration.

Part of the [ceilidhboy/skills](https://github.com/ceilidhboy/skills) collection.

## Installation

```bash
# Via npx skills (all agents)
npx skills@latest add ceilidhboy/skills

# Or via Pi
pi install github:ceilidhboy/skills
```

Then select `html-output` from the skill picker.

## What It Does

When you ask an agent a question whose answer would benefit from visual
illustration — architectural plans, design options, code reviews, workflows,
comparisons, novel concepts, color choices — this skill kicks in and generates
a self-contained HTML file instead of Markdown.

The HTML includes:

- **Visual hierarchy** — cards, grids, callouts, responsive layouts
- **Inline SVG diagrams** — flowcharts, architecture, timelines, fan-out/in
- **Color swatches** — for design discussions where hex codes aren't enough
- **Tradeoff tables** — with green/red dot indicators
- **Code panels** — dark background with syntax highlighting
- **Interactive controls** — sliders, toggles, copy buttons (optional)
- **Export buttons** — download SVG diagrams as standalone files

## Configuration

The output directory is resolved using this fallback chain:

1. **Environment variable** — set `PI_HTML_OUTPUT_DIR` to your preferred path
2. **Pi settings** — add `"htmlOutputDir": "/path/to/output"` to `~/.pi/agent/settings.json`
3. **Fallback** — `~/.pi/agent/html-output/`

### Quick setup

```bash
# Option A: settings.json (recommended)
# Add this line to ~/.pi/agent/settings.json:
# "htmlOutputDir": "/path/to/your/output"

# Option B: environment variable
echo 'export PI_HTML_OUTPUT_DIR="/path/to/your/output"' >> ~/.bashrc
```

Then restart your agent or run `/reload`.

### Windows / WSL users

If you're running inside WSL (Windows Subsystem for Linux), the output path
will look like `/mnt/c/Users/You/Documents/Pi Output/file.html`. This path is
correct for file writes but won't work as a clickable link from Windows.

To get a working `file://` link, add this to `~/.pi/agent/settings.json`:

```json
{
  ...
  "htmlOutputDir": "/mnt/c/Users/YourName/Documents/Pi Output",
  "htmlOutputFileUri": "file:///C:/Users/YourName/Documents/Pi%20Output/{filename}"
}
```

The `{filename}` placeholder is replaced automatically. With this set, the
agent will report a clickable link like:

```
file:///C:/Users/YourName/Documents/Pi%20Output/sql-vs-nosql-social-media.html
```

**Tip:** If you change `htmlOutputDir`, update `htmlOutputFileUri` to match —
the WSL path (`/mnt/c/...`) and the Windows URI (`file:///C:/...`) are two
representations of the same location.

## How It Works

### Skill structure

```
skills/html-output/
├── SKILL.md                    ← Entry point (agent instructions)
├── README.md                   ← This file (human documentation)
└── references/
    ├── DESIGN_SYSTEM.md        ← Color palette, typography, CSS
    ├── SVG_GUIDELINES.md       ← SVG conventions and diagram types
    └── TEMPLATES.md            ← Use case templates
```

The entry point (`SKILL.md`) is concise and contains only the decision
heuristic, output path resolution, and pointers to the reference files. The
reference files are read on-demand when the agent needs that specific
information.

### Decision heuristic

The agent asks itself:

> *"Would the human reader get more understanding from **seeing** this than
> from **reading** it?"*

If yes → HTML. If no → Markdown.

**Use HTML when** the information has *depth* — relationships, tradeoffs,
workflows, color choices, novel concepts — anything requiring mental
visualization.

**Use Markdown when** the information is *wide* — linear lists using standard
terminology that carries the meaning.

### Customizing the design system

Replace `references/DESIGN_SYSTEM.md` with your own color palette, typography,
and CSS patterns. Keep the same token names (`--ivory`, `--slate`, `--clay`,
etc.) for consistency, or add your own.

## Requirements

- Any SKILL.md-compatible agent (Pi, Claude Code, Cursor, Codex, OpenCode, etc.)
- Any compatible LLM model
