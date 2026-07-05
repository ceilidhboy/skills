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
