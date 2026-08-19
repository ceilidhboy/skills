---
name: formatting-enforcement
description: Retrofit formatting enforcement onto an existing Laravel project that has accumulated drift (badly formatted code committed under an always-green lint CI) or legacy tooling conflicts (Prettier vs Biome). Use when told to "harden linting", "fix formatting drift", "stop formatting merge conflicts", "apply the quality pipeline", or when an existing project's CI uses fix-mode formatters (pint/biome/prettier --write) that never fail. For new projects, use project-bootstrap instead.
---

# Formatting Enforcement — Existing Project Retrofit

Existing projects typically have two problems this skill fixes:

1. **Silent-green lint CI** — the workflow runs formatters in fix mode (`pint`, `biome --write`, `prettier --write`), which always exit 0, so unformatted code merges forever and drift accumulates. Reformatting it later collides with open PRs.
2. **Conflicting formatters** — Prettier (with organize-imports/tailwind plugins) and Biome disagree on CSS quote style, import ordering, and JSON key sorting, so a pipeline that runs both can never satisfy a gate that checks both.

## Procedure

### Phase 0 — Measure the drift (check-only commands)

```bash
# PHP: Pint dry-run — exits 1 when files need reformatting
composer test:lint            # pint --parallel --test

# Frontend: check-only, no writes
npm run format:check          # prettier --check resources/  (if prettier is kept)
npm run lint:check            # biome ci .  (if biome is kept)
```

A non-zero exit on a clean checkout of master = drift exists. Record which files are flagged — that is the one-time cleanup list.

### Phase 1 — Clean the drift on a chore branch (never on a feature branch)

1. `git checkout -b chore/apply-quality-pipeline` from fresh `master`
2. Run the repo's pipeline in **gate-consistent order** (whichever formatter runs last owns the files on disk):
   - Biome + Prettier project: `npm run lint` (biome --write) **then** `npm run format` (prettier --write) — Prettier last, so it owns the final on-disk state (CSS quote style, import order, Tailwind class order)
   - Biome-only project: `npm run lint` (biome --write)
   - PHP: `composer lint` (pint)
3. **Resolve formatter conflicts before committing** (see Conflict Matrix below)
4. Commit the delta as a single commit: `chore: apply quality pipeline formatting to clear accumulated drift`
5. PR to `master`, get it merged. Master is now self-consistent.
6. In each open feature branch: `git merge master` (or rebase) — the formatting is now underneath, so the feature branch's own churn dissolves and its diff shrinks to the feature.

### Phase 2 — Install the gate (CI) and hooks

1. Replace fix-mode CI commands with check-only ones in `.github/workflows/lint.yml` (see `references/lint.yml` for the npm variant). Set `permissions: contents: read`; delete any dead auto-commit step.
2. Add husky + lint-staged (merge `references/package-json.snippets.json`; copy `references/pre-commit` into `.husky/pre-commit`; `npm install` or `bun install` to wire hooks).
3. Verify the gate is green on the cleaned tree:

```bash
composer test:lint && npm run format:check && npm run lint:check   # all exit 0
git config core.hooksPath   # -> .husky/_  (hooks wired)
```

## Conflict Matrix (Prettier + Biome coexistence)

When an existing project keeps Prettier AND Biome, align them or the gate is unsatisfiable. Apply **all** of:

| Conflict | Fix | Where |
|---|---|---|
| CSS quotes (prettier single vs biome double) | `css.formatter.quoteStyle = "single"` | biome.json |
| Import ordering (prettier's organize-imports vs biome's organizeImports sort differently) | `assist.enabled = false` (prettier owns imports) | biome.json |
| JSON key sorting (biome sorts keys, prettier preserves order) | exclude composer.json from biome formatter (`!composer.json` in `formatter.includes`) | biome.json |

These apply to every project that keeps Prettier (the company standard keeps Prettier for Tailwind class ordering and import organization, so the retrofit uses these in every case). A project that drops Prettier entirely (Biome-only) needs none of them — Biome owns everything, and the gate checks only `pint --test` + `biome ci`.

## Verification

- [ ] All check commands exit 0 on the cleaned tree
- [ ] `git diff --stat origin/master` shows only the expected drift files
- [ ] A deliberately misformatted staged file is reformatted by the pre-commit hook
- [ ] Open feature branches re-based onto the cleaned master show no formatting churn

## References

- [Runbook](references/runbook.md) — Expanded step-by-step with commands and rationale
- [CI workflow (npm variant)](references/lint.yml) — Check-only gate for npm projects
- [Pre-commit hook](references/pre-commit) — Bare `lint-staged` (portable across npm and Bun)
- [package.json snippets](references/package-json.snippets.json) — Scripts, lint-staged config, devDependencies

## Notes

- Hooks are per-worktree: each clone/worktree needs one `npm install`/`bun install` for `core.hooksPath` to be set. CI is the enforcement backstop for anyone who skips installs.
- Do NOT run the pipeline on a feature branch and commit the results there — that is exactly what caused the churn-in-PR problem. Drift cleanup belongs on its own chore branch off master.