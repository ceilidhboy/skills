# HTML Design System

CSS tokens and visual style rules for all HTML ADRs. Embed these directly in the
`<style>` block of each HTML file.

## CSS Tokens

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

## Visual Rules

| Element | Style |
|---------|-------|
| Content width | 760–880px max-width, centred |
| Body font | 15px sans-serif, line-height 1.6 |
| Headings | serif font family |
| Code blocks | Dark background (`--slate`), light text |
| Tables | White background, rounded 12px corners, subtle borders |
| Status badge | Coloured chip — olive for Accepted, clay for Draft, rust for Superseded |
| Metadata grid | Card with key-value pairs |
| Callout boxes | Info (gray), Warning (amber), Danger (rust), Success (olive) variants |
| Flow diagrams | SVG or monospace ASCII, centred in a card |
| Story bubble | Blockquote with left accent border, italic text, attribution |
| Border radius | 12px for cards, panels, tables |
