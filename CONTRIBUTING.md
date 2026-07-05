# Contributing

Guidelines for adding or updating skills in this repository.

## Adding a new skill

1. Create `skills/{name}/SKILL.md` with frontmatter and instructions.
2. Add reference files as needed (`template-x.md`, reference docs, etc.) inside `skills/{name}/`.
3. Update the Skills table in `README.md` to list the new skill.
4. Run `bash scripts/link-skills.sh` to symlink into `~/.agents/skills/` for local use.
5. Commit and push to GitHub. No other registry or manifest needs updating — `npx skills@latest` discovers skills by scanning `skills/{name}/SKILL.md`.

## Updating an existing skill

Edit the `SKILL.md` file directly, then run `bash scripts/link-skills.sh` to update the local symlink. After pushing to GitHub, see [Verification after a GitHub install](#2-verification-after-a-github-install) below.

## Verification: two-step workflow

After adding or updating a skill, you should verify it works in two distinct ways:

### 1. Local development verification

Run this immediately after `link-skills.sh` to confirm the local symlinks are correct:

```bash
bash scripts/verify-skills.sh --mode dev
```

This confirms every skill in the repo has a working symlink pointing to the right location. All 21 should show ✓.

### 2. Verification after a GitHub install

After pushing to GitHub, install and verify as an end-user would. This catches any issues the installer might have (missing files, wrong structure, etc.):

```bash
# Prepare: backup and remove repo symlinks
bash scripts/prepare-test.sh

# Install fresh from GitHub (select all skills)
npx skills@latest add ceilidhboy/skills

# Verify — default auto mode accepts both symlinks and copies
bash scripts/verify-skills.sh

# Or use --mode prod for a stricter check (must be real copies)
bash scripts/verify-skills.sh --mode prod
```

If anything went wrong during the install:
```bash
rm -rf ~/.agents/skills && mv ~/.agents/skills.bak ~/.agents/skills
```

If everything succeeded, you can remove the backup:
```bash
rm -rf ~/.agents/skills.bak
```

## Verify script reference

| `--mode` | What it checks | When to use |
|----------|---------------|-------------|
| `auto` (default) | Accepts symlinks or real directories. Passes either way. | Quick check, or after a GitHub install |
| `dev` | Must be a symlink pointing back to this repo. | After `link-skills.sh` during development |
| `prod` | Must be a real directory with `SKILL.md` (not a symlink). | After `npx skills@latest add` to confirm end-user install |

## Notes

- Only `skills/{name}/SKILL.md` matters to installers. The `.claude-plugin/plugin.json` is for Claude Code's plugin system — do not edit it manually.
- The `README.md` is user-facing (how to install, what's available). Keep the Skills table in sync.
- Run `bash scripts/link-skills.sh` after any add or update to keep `~/.agents/skills/` current.
