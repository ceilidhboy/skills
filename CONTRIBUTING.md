# Contributing

Guidelines for adding or updating skills in this repository.

## Adding a new skill

1. Create `skills/{name}/SKILL.md` with frontmatter and instructions.
2. Add reference files as needed (`template-x.md`, reference docs, etc.) inside `skills/{name}/`.
3. Update the Skills table in `README.md` to list the new skill.
4. Run `bash scripts/link-skills.sh` to symlink into `~/.agents/skills/` for local use.
5. Commit and push to GitHub. No other registry or manifest needs updating — `npx skills@latest` discovers skills by scanning `skills/{name}/SKILL.md`.

## Updating an existing skill

Edit the `SKILL.md` file directly, then run `bash scripts/link-skills.sh` to update the local symlink.

## Verifying

After linking, run the verify script to confirm every skill has a correct symlink:

```bash
bash scripts/verify-skills.sh
```

All 21 (✓) and a clean summary means everything is in place.

## Testing a clean install

To test the repo as if on a fresh machine (e.g. after adding a new skill):

```bash
# 1. Prepare: backup and remove current repo symlinks
bash scripts/prepare-test.sh

# 2. Install fresh from GitHub
npx skills@latest add ceilidhboy/skills

# 3. Verify the result
bash scripts/verify-skills.sh

# 4. If anything went wrong, restore
rm -rf ~/.agents/skills && mv ~/.agents/skills.bak ~/.agents/skills
```

If all skills verify OK, no cleanup is needed — the verify script confirms this.
Remove the backup once you're satisfied:
```bash
rm -rf ~/.agents/skills.bak
```

## Notes

- Only `skills/{name}/SKILL.md` matters to installers. The `.claude-plugin/plugin.json` is for Claude Code's plugin system — do not edit it manually.
- The `README.md` is user-facing (how to install, what's available). Keep the Skills table in sync.
- Run `bash scripts/link-skills.sh` after any add or update to keep `~/.agents/skills/` current.
