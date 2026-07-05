# Design System

Use these design tokens consistently across all HTML output. To use a
different design system, replace this file while keeping the same token names
or add your own.

## Color Palette

```css
:root {
  --ivory:   #FAF9F5;   /* page background */
  --slate:   #141413;   /* heading text */
  --clay:    #D97757;   /* accent / highlight / "in focus" */
  --oat:     #E3DACC;   /* warm neutral background */
  --olive:   #788C5D;   /* success / done / positive */
  --rust:    #B04A3F;   /* error / destructive (optional) */
  --gray-150:#F0EEE6;   /* subtle panel backgrounds */
  --gray-300:#D1CFC5;   /* borders, dividers */
  --gray-500:#87867F;   /* secondary / label / metadata text */
  --gray-700:#3D3D3A;   /* body text */
  --white:   #FFFFFF;   /* card backgrounds */

  --serif: ui-serif, Georgia, 'Times New Roman', serif;
  --sans:  system-ui, -apple-system, 'Segoe UI', Roboto, sans-serif;
  --mono:  ui-monospace, 'SF Mono', Menlo, Monaco, monospace;
}
```

## Typography

| Element | Font | Weight | Size |
|---|---|---|---|
| Page title (h1) | `--serif` | 500 | 30-40px |
| Section heading (h2) | `--serif` | 500 | 22-26px |
| Subheading (h3) | `--serif` | 500 | 19-21px |
| Body text | `--sans` | 400 | 14-15px |
| Code | `--mono` | 400 | 12-13px |
| Metadata/labels | `--mono` | 400 | 10-12px |
| Captions/secondary | `--sans` | 400 | 13-14px, `--gray-500` |

## Spacing & Layout

- **Page padding:** 48-56px top, 24-32px sides, 80-120px bottom
- **Content max-width:** 760-980px (narrow for reading), or wider for grids (1360px)
- **Card padding:** 24px
- **Border radius:** 12px for panels/cards, 8px for small elements, 999px for chips
- **Border:** 1.5px solid `--gray-300`
- **Grid gap:** 24-28px for comparison grids
- **Section margin:** 48-64px below each section
- **Body line-height:** 1.55-1.6

## CSS Patterns

### Prompt box
```css
.prompt-box {
  background: var(--gray-150);
  border: 1.5px solid var(--gray-300);
  border-radius: 12px;
  padding: 16px 20px;
  font-size: 14.5px;
}
.prompt-box .label {
  font-family: var(--mono);
  font-size: 11px;
  text-transform: uppercase;
  color: var(--gray-500);
}
```

### Tradeoff table (pro/con dots)
```css
.tradeoffs .pro::before {
  content: '';
  width: 6px; height: 6px;
  border-radius: 50%;
  background: var(--olive);
  margin-right: 8px;
  display: inline-block;
  vertical-align: middle;
}
.tradeoffs .con::before {
  content: '';
  width: 6px; height: 6px;
  border-radius: 50%;
  background: var(--clay);
  margin-right: 8px;
  display: inline-block;
  vertical-align: middle;
}
```

### Chips (metadata tags)
```css
.chip {
  font-family: var(--mono);
  font-size: 11.5px;
  background: var(--gray-150);
  border: 1.5px solid var(--gray-300);
  border-radius: 8px;
  padding: 5px 10px;
  white-space: nowrap;
}
.chip strong { color: var(--slate); font-weight: 600; }
```

### Recommendation callout
```css
.reco {
  border-left: 4px solid var(--clay);
  background: var(--white);
  border-radius: 0 12px 12px 0;
  padding: 24px 28px;
  max-width: 860px;
}
```

### Code panel (dark background)
```css
.code {
  background: var(--slate);
  border-radius: 12px;
  padding: 18px 20px;
  overflow-x: auto;
}
.code pre {
  font-family: var(--mono);
  font-size: 12.5px;
  line-height: 1.65;
  color: #E8E6DE;
  white-space: pre;
}
.code .kw  { color: var(--clay); }
.code .str { color: var(--olive); }
.code .cm  { color: var(--gray-500); }
.code .fn  { color: #C9B98A; }
```

## HTML Boilerplate

```html
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Document title</title>
<style>
  /* design system tokens + page-specific styles */
</style>
</head>
<body>
  <!-- content -->
</body>
</html>
```
