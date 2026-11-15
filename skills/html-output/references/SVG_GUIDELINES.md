# SVG Illustration Guidelines

Use inline SVG for diagrams, flowcharts, timelines, and architecture — pure
vector art, no external assets.

## Conventions

- **ViewBox:** 720×320 default for header/hero illustrations
- **Background:** `<rect width="720" height="320" fill="#FAF9F5">` as first element
- **Strokes:** 1.5px for neutral elements, 2px for emphasized containers
- **Corner radius:** `rx="10"` on all rectangles
- **No drop shadows or gradients** — flat fills only
- **Labels inside boxes:** 11px `--mono`, centered with `text-anchor="middle"`
- **Annotations outside boxes:** 12px `--sans`, color `--gray-500`
- **Clay (`#D97757`)** marks "the thing in focus"
- **Olive (`#788C5D`)** marks "success / done"

## Style scoping — mandatory when a page has more than one SVG

An SVG `<style>` block is **document-scoped**, not figure-scoped. Classes leak across
every figure on the page, and with equal specificity the last block wins — so a
`.bx { text-anchor: middle }` in figure 3 silently re-anchors every `.bx` in figures 1
and 2, and those labels slide left out of their boxes.

Scope every rule to its own figure id:

```css
#diagram-queue .bx { font-family: ui-monospace, Menlo, monospace; font-size: 10px; }
```

The id travels with the SVG when the download button serialises it, so a scoped block
is still self-contained for the downloaded file. Write selectors pre-scoped rather than
fixing collisions later — the failure is invisible inside any one figure and obvious
only on the assembled page.

## Verification — run these before calling the page finished

Two checks catch almost every layout defect. Run both in the browser against the
rendered page, not by eye: a label 3px outside its box is invisible in a screenshot and
obvious to a tabulation.

**1. Text escaping its viewBox** (clipped by the SVG frame):

```javascript
(() => { const bad = [];
  document.querySelectorAll('svg').forEach(s => {
    const n = s.getAttribute('viewBox').trim().split(/\s+/).map(Number);
    s.querySelectorAll('text').forEach(t => { const b = t.getBBox();
      if (b.x + b.width > n[2] - 1 || b.x < -1 || b.y + b.height > n[3] - 1)
        bad.push(s.id + ' | ' + t.textContent.slice(0, 40) + ' | r=' + Math.round(b.x + b.width));
    });
  });
  return JSON.stringify(bad);
})()
```

**2. A label wider than the box it sits in** (touching the border reads as clipped):

```javascript
(() => { const bad = [];
  document.querySelectorAll('svg').forEach(svg => {
    const rects = [...svg.querySelectorAll('rect')]
      .map(r => ({x:+r.getAttribute('x'), y:+r.getAttribute('y'),
                  w:+r.getAttribute('width'), h:+r.getAttribute('height')}))
      .filter(r => r.w > 20 && r.h > 14 && r.w < 700);
    svg.querySelectorAll('text').forEach(t => { const b = t.getBBox();
      const cx = b.x + b.width/2, cy = b.y + b.height/2;
      const host = rects.find(r => cx > r.x+2 && cx < r.x+r.w-2 && cy > r.y+2 && cy < r.y+r.h-2);
      if (!host) return;
      const L = b.x - host.x, R = (host.x + host.w) - (b.x + b.width);
      if (L < 4 || R < 4) bad.push(svg.id + ' | ' + t.textContent.slice(0,30) + ' | L' + Math.round(L) + ' R' + Math.round(R));
    });
  });
  return JSON.stringify(bad);
})()
```

Both should return `[]`. `L-1 R-1` means the label overhangs both edges by a pixel —
fix by shortening the label text or widening the rect, never by nudging `x`. Estimate
width from measurement rather than character count: at 11.5px system-ui a 120-character
annotation measures ~850 user units, roughly 40% wider than a 7px-per-character guess.

## Figure Structure

Wrap SVG in a figure with caption and optional download button:

```html
<figure>
  <div class="canvas">
    <svg id="diagram-name" width="720" height="320" viewBox="0 0 720 320">
      <!-- diagram content -->
    </svg>
  </div>
  <figcaption>
    <div class="cap-title">Diagram title</div>
    <div class="cap-sub">Description of what the diagram shows.</div>
  </figcaption>
</figure>
```

### Download button
```html
<button class="dl-btn" data-target="diagram-name" data-filename="diagram.svg">Download SVG</button>
```

Include this JS at the bottom of the page:
```javascript
document.querySelectorAll('.dl-btn').forEach(function(btn){
  btn.addEventListener('click', function(){
    var svg = document.getElementById(btn.dataset.target);
    var src = new XMLSerializer().serializeToString(svg);
    var blob = new Blob([src], {type:'image/svg+xml;charset=utf-8'});
    var url = URL.createObjectURL(blob);
    var a = document.createElement('a');
    a.href = url;
    a.download = btn.dataset.filename || 'illustration.svg';
    a.click();
    setTimeout(function(){ URL.revokeObjectURL(url); }, 1000);
  });
});
```

Each SVG should carry its own `<style>` block so the download stands alone.

## Common Diagram Types

### Flowchart / Architecture
Boxes connected by `<line>` elements with arrow markers. Use a `<defs>`
section for markers. Pull direction arrows from the center of each box edge.

### Timeline
Horizontal axis line at y=190, evenly-spaced event circles. Annotation text
below. Dashed arc paths for temporal gaps with labels showing duration.

### Fan-out / Fan-in
Single source box on left, angled lines to multiple parallel boxes in center,
converging lines to single merge box on right.

### Queue
Horizontal row of job boxes with arrow to a highlighted worker box.
