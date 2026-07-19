# HTML Narrative Guide

Reference for creating the HTML version of an ADR — audience, story approach,
readability, and before/after diagrams.

## Audience

Non-technical stakeholders — project leads, product managers, future team members.
They may not know the codebase, but they understand friction, wasted time, and user
frustration. Speak to that.

## The narrative approach

Every ADR exists because something was worse before. The HTML explainer's job is to
make that tangible.

- **Open with the problem**, not the solution. A reader who doesn't understand the
  pain won't appreciate the fix.
- **Use a story** — a short first-person narrative from the perspective of someone
  who experienced the before-state. This gives the reader something to identify with.
  - For a user-facing issue: *"I was looking at a property, clicked Log In, and ended
    up on the homepage. I had to find it again."*
  - For a developer-facing issue: *"Every time we add a new property type, we touch
    six files in a specific order. Last week we broke the search page because we
    forgot one."*
  - For a missed opportunity: *"Users visit the site and see the same properties
    every time. They have no way to tell us what they like, so we send them
    irrelevant recommendations."*
- **Give the problem equal weight.** Spend as much effort explaining what was wrong
  and why it mattered as you do explaining the solution. If the markdown mentions the
  problem in one sentence, the HTML can devote multiple paragraphs and a diagram to it.
- **Adapt the story to the pain type.** Not every ADR has a user-facing impact. An
  architectural improvement might affect developers (build times, deployment risk),
  operations (monitoring gaps), or compliance (data retention). Choose a story that
  fits the audience who most needs to understand the change.

## Readability principles

- **diagrams > tables > paragraphs.** SVG flowcharts for architecture decisions and
  before/after flows. Comparison tables for trade-offs. Timeline diagrams for sequencing.
- **Structure for scanning:** clear h2/h3 hierarchy, metadata badges, callout boxes
  for key insights, pro/con columns.
- **Use the story-bubble callout** — a styled blockquote with a left accent border,
  distinguished from explanatory prose. This makes it clear the story is illustrative,
  not the formal ADR content.
- **Don't be constrained by the markdown.** If the markdown says "three approaches
  were considered" in a sentence, the HTML can expand each approach into its own
  subsection with diagrams, pros/cons, and rationale.

## Before-and-after diagrams

For any ADR where the decision changes a flow (login, checkout, search, etc.), include
an SVG diagram of the **old flow** (annotated with the problem areas) and the **new
flow** (annotated with the improvements). This is the single most effective way for a
non-technical reader to understand what changed.
