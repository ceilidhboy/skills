# Use Case Templates

## 1. Exploration & Planning

Comparison grid of multiple approaches. 3-column layout with code panels,
tradeoff tables, and chip metadata per option. End with a recommendation
callout.

**Prompt pattern:** *"Generate N distinctly different approaches, lay them
out in a grid so I can compare them side by side. Label each with the
tradeoff it's making."*

## 2. Code Review

Annotated diff with color-coded severity. Include key files changed and a
summary table. Margin annotations for inline commentary.

**Prompt pattern:** *"Create an HTML artifact describing the PR. Render the
diff with inline margin annotations, color-code findings by severity."*

## 3. Design & Prototyping

Color swatches, component variants, interactive controls (sliders, toggles).
Always end with a copy-button to export parameters.

**Prompt pattern:** *"Create an HTML file with sliders and options for me to
try different parameters. Include a copy button to export the result."*

## 4. Reports

Timeline or status layout with color-coded sections (olive=done, clay=in-progress,
gray=planned). Include a summary callout.

**Prompt pattern:** *"Generate an HTML status report with a timeline,
color-coded sections, and a summary callout."*

## 5. Explainer / Learning

Collapsible sections, tabbed code samples, margin glossary for key terms.
Use SVG diagrams for flow explanations.

**Prompt pattern:** *"Produce a single HTML explainer page with a diagram,
annotated code snippets, and a 'gotchas' section."*

## 6. Slide Deck

`scroll-snap-type: y mandatory` for full-screen slides with keyboard
navigation. Max 5-8 slides.

**Prompt pattern:** *"Make an HTML slide deck with full-screen slides and
keyboard navigation."*

## 7. Custom Editor (Advanced)

Purpose-built editor for specific data. Always end with an export button
("copy as JSON", "copy as prompt", "copy as Markdown").

**Prompt pattern:** *"Make an HTML file with interactive controls for
[specific task]. Add a copy button that exports the result."*

---

## Interactive Elements

### Sliders
```html
<input type="range" min="0" max="1000" value="300" id="param">
<span id="param-value">300</span>
<script>
document.getElementById('param').addEventListener('input', function(){
  document.getElementById('param-value').textContent = this.value + 'ms';
});
</script>
```

### Copy Buttons
```html
<button onclick="navigator.clipboard.writeText(content)">Copy</button>
```

### Live Preview (Side-by-Side)
Editable content on left, rendered preview on right. Re-render on input events.
