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
# 1. Back up current symlinks
cp -a ~/.agents/skills ~/.agents/skills.bak

# 2. Remove only your repo's symlinks
for skill in skills/*/; do
  name=$(basename "$skill")
  if [ -L "$HOME/.agents/skills/$name" ]; then
    rm "$HOME/.agents/skills/$name"
  fi
done

# 3. Install fresh from GitHub
npx skills@latest add ceilidhboy/skills

# 4. Verify the result
bash scripts/verify-skills.sh

# 5. If anything went wrong, restore
rm -rf ~/.agents/skills && mv ~/.agents/skills.bak ~/.agents/skills
```

## Notes

- Only `skills/{name}/SKILL.md` matters to installers. The `.claude-plugin/plugin.json` is for Claude Code's plugin system — do not edit it manually.
- The `README.md` is user-facing (how to install, what's available). Keep the Skills table in sync.
- Run `bash scripts/link-skills.sh` after any add or update to keep `~/.agents/skills/` current.
