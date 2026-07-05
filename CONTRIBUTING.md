# Contributing

Guidelines for adding or updating skills in this repository.

## Adding a new skill

1. Create `skills/{name}/SKILL.md` with frontmatter and instructions.
2. Add reference files as needed (`template-x.md`, reference docs, etc.) inside `skills/{name}/`.
3. Update the Skills table in `README.md` to list the new skill.
4. Run `bash scripts/link-skills.sh` to symlink into `~/.agents/skills/` for local use.
5. Commit and push to GitHub. No other registry or manifest needs updating — `npx skills@latest` discovers skills by scanning `skills/{name}/SKILL.md`.

## Updating an existing skill

Edit the `SKILL.md` file directly, then run `bash scripts/link-skills.sh` if you want the local symlink updated immediately.

## Notes

- Only `skills/{name}/SKILL.md` matters to installers. The `.claude-plugin/plugin.json` is for Claude Code's plugin system and is regenerated automatically by the Vercel skills tooling — do not edit it manually.
- The `README.md` is user-facing (how to install, what's available). Keep the Skills table in sync.
- Run `bash scripts/link-skills.sh` after any add/update to keep `~/.agents/skills/` current.
