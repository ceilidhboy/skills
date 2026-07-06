---
name: github-cli-workarounds
description: Workarounds for shell escaping issues when using the GitHub CLI (`gh`) for creating issues, gists, and pull requests with content containing special characters like `$`, backticks, or quotes. Use when creating GitHub issues, gists, or pull requests where content contains `$variables`, backtick-enclosed code, or multi-line bodies that cause shell parsing errors.
author: Mike Scott
---

# GitHub CLI Workarounds

## The Problem

When using `gh issue create --body "..."` or `gh gist create` with inline content, the shell interprets special characters:

- **`$variable`** — expanded as a shell variable (e.g., `$content`, `$images`)
- **Backticks `` ` ``** — interpreted as command substitution
- **Double quotes** — broken nesting with the shell's quoting

This causes `Syntax error: word unexpected` or truncated content.

## The Fix: Always Use Temp Files

### For Issues

Write the body to a temp file, then use `--body-file`:

```bash
cat > /tmp/gh-body.md << 'ISSUEBODY'
Content with $variables, `backticks`, and "quotes" works fine here.
ISSUEBODY

gh issue create --repo owner/repo \
  --title "Issue title" \
  --body-file /tmp/gh-body.md \
  --label enhancement
```

**Important:** Use `<< 'EOF'` (single-quoted delimiter) to prevent shell expansion in the heredoc.

### For Gists

Write to a temp file, then pipe it:

```bash
cat > /tmp/gh-gist-content.md << 'GISTCONTENT'
Content with $variables here.
GISTCONTENT

gh gist create /tmp/gh-gist-content.md --desc "Description"
```

### For Pull Requests

Same pattern as issues:

```bash
cat > /tmp/gh-pr-body.md << 'PRBODY'
PR description with $special chars.
PRBODY

gh pr create --repo owner/repo \
  --title "PR title" \
  --body-file /tmp/gh-pr-body.md
```

## Why This Works

- The heredoc (`<< 'EOF'`) with a quoted delimiter prevents ALL shell expansion
- `--body-file` reads the file directly, bypassing shell parsing entirely
- No escaping, no quoting gymnastics, no syntax errors

## Common Pitfall: `\n` in Multi-line Bodies

Inside bash single quotes, `\n` is **two literal characters** (backslash + n), not a newline. This means:

```bash
# BROKEN — \n is literal text, not a newline
ga pr create --body 'line1\nline2'

# BROKEN — same issue with ga api -F
ga api ... -F body="line1\nline2"

# WORKS — heredoc + --body-file (or --field with real newlines)
cat > /tmp/body.md << 'BODY'
line1
line2
BODY
ga pr create --body-file /tmp/body.md
```

**Rule of thumb:** Any time your body/description has more than one line, use `--body-file` with a heredoc. Never use `\n` in inline `--body` / `-F` arguments — it will appear literally on GitHub.

## When to Activate This Skill

- Creating GitHub issues, gists, or pull requests where the content contains PHP code examples with `$variables`, backtick-enclosed code, or special characters
- Any `gh` command where the body/description is longer than a single line or contains syntax examples
