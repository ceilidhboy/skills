---
name: github-cli-workarounds
description: Workarounds for shell escaping issues when using the GitHub CLI (`gh`) for creating issues, gists, and pull requests with content containing special characters like `$`, backticks, or quotes. Use when creating GitHub issues, gists, or pull requests where content contains `$variables`, backtick-enclosed code, or multi-line bodies that cause shell parsing errors.
author: Mike Scott
version: '1.0.1'
updated: '2026-08-18'
---

# GitHub CLI Workarounds

## The Problem

When using `gh issue create --body "..."` or `gh gist create` with inline content, the shell interprets special characters:

- **`$variable`** — expanded as a shell variable (e.g., `$content`, `$images`)
- **Backticks `` ` ``** — interpreted as command substitution
- **Double quotes** — broken nesting with the shell's quoting

This causes `Syntax error: word unexpected` or truncated content.

## The Fix: Always Use Temp Files

### Where to write it

Use `mktemp` — it lands in `$XDG_RUNTIME_DIR` (the per-user ramdisk, e.g. `/run/user/$(id -u)`: RAM-backed, wiped on logout, mode-700 private) when set, else `/tmp`. Prefer `/tmp` deliberately only when the file must outlive the session (e.g. a background job's log — the ramdisk is wiped on logout). Scratch files are transient: delete them after the `gh` command.

### For Issues

Write the body to a temp file, then use `--body-file`:

```bash
body_file=$(mktemp)
cat > "$body_file" << 'ISSUEBODY'
Content with $variables, `backticks`, and "quotes" works fine here.
ISSUEBODY

gh issue create --repo owner/repo \
  --title "Issue title" \
  --body-file "$body_file" \
  --label enhancement
rm -f "$body_file"
```

**Important:** Use `<< 'EOF'` (single-quoted delimiter) to prevent shell expansion in the heredoc.

### For Gists

Write to a temp file, then pipe it:

```bash
body_file=$(mktemp)
cat > "$body_file" << 'GISTCONTENT'
Content with $variables here.
GISTCONTENT

gh gist create "$body_file" --desc "Description"
rm -f "$body_file"
```

### For Pull Requests

Same pattern as issues:

```bash
body_file=$(mktemp)
cat > "$body_file" << 'PRBODY'
PR description with $special chars.
PRBODY

gh pr create --repo owner/repo \
  --title "PR title" \
  --body-file "$body_file"
rm -f "$body_file"
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
body_file=$(mktemp)
cat > "$body_file" << 'BODY'
line1
line2
BODY
ga pr create --body-file "$body_file"
rm -f "$body_file"
```

**Rule of thumb:** Any time your body/description has more than one line, use `--body-file` with a heredoc. Never use `\n` in inline `--body` / `-F` arguments — it will appear literally on GitHub.

## When to Activate This Skill

- Creating GitHub issues, gists, or pull requests where the content contains PHP code examples with `$variables`, backtick-enclosed code, or special characters
- Any `gh` command where the body/description is longer than a single line or contains syntax examples
