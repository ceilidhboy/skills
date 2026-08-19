---
name: project-bootstrap
description: Use when setting up a new Laravel + Inertia + React project, onboarding a new project to company standards, or told to "apply company tooling" or "standardise tooling". For existing/deployed projects that already have legacy tooling, see the formatting-enforcement skill instead.
---

# Project Bootstrap — Company Tooling Standards

Apply the Socially-Free standard toolchain to a Laravel + Inertia + React project.

## Quick Start

1. **Bun** — Delete `package-lock.json`, run `bun install`. Update CI workflows to use `oven-sh/setup-bun@v2` and `bun install` / `bun run <script>`.
2. **Biome** — Replace ESLint deps with `@biomejs/biome: "2.4.13"`. Copy `references/biome.json` into the project. Update `package.json` scripts (`lint`, `lint:check`, `format:check`). Delete `eslint.config.js`. **Keep Prettier with its plugins** — the existing `.prettierrc` (Tailwind class ordering + import organization) stays; Biome does not offer Tailwind class sorting. Run `bun install`.
3. **Composer scripts** — Replace the starter kit's scripts section with `references/composer-scripts.json`. Keep the starter kit's `post-autoload-dump`, `post-update-cmd`, `post-root-package-install` scripts intact — only replace the user-facing ones. Ensure `test:lint` (`pint --parallel --test`) and `lint` (`pint --parallel`) exist.
4. **Laravel Wayfinder** — The `generate:routing` composer script relies on `php artisan wayfinder:generate`. Install the Laravel Wayfinder package so this command is available. Follow the [Laravel Wayfinder installation instructions](https://github.com/earendil-works/laravel-wayfinder#installation) for your project.
5. **CI workflows** — Copy `references/lint.yml` and `references/tests.yml` into `.github/workflows/`. The lint workflow uses **check-only** commands (`pint --test`, `biome ci`) so it FAILS on formatting drift instead of silently fixing and discarding it.
6. **Formatting enforcement (hooks)** — Add `husky` + `lint-staged` (merge `references/package-json.snippets.json` into package.json, copy `references/pre-commit` into `.husky/pre-commit`), run `bun install` to wire the hooks. Pre-commit runs pint / biome --write / prettier --write on staged files only — Biome first, Prettier last, so Prettier owns the final on-disk state (CSS quote style, import order, Tailwind class order).
7. **.gitignore** — Ensure `bun.lock` is tracked (not gitignored).

Run `bun run build`, `composer fix`, and `git commit` (to confirm the pre-commit hook fires) to verify.

## Verification

- [ ] `bun run build` passes
- [ ] `composer test:lint` passes (pint --test, exit 0 = no drift)
- [ ] `bun run lint:check` passes (biome ci, exit 0 = no drift)
- [ ] `git config core.hooksPath` outputs `.husky/_` (hooks wired)
- [ ] A deliberately misformatted staged file gets reformatted by the pre-commit hook on commit
- [ ] `eslint.config.js` is deleted; `.prettierrc` and `.prettierignore` are kept (Prettier owns Tailwind class ordering + import organization)
- [ ] `bun.lock` is committed, `package-lock.json` is deleted
- [ ] CI workflows reference Bun and Biome (check-only mode)

## References

- [Composer scripts](references/composer-scripts.json) — Standard scripts to merge into composer.json
- [Biome config](references/biome.json) — Canonical Biome configuration (CSS quote style single; composer.json excluded from formatting — composer.json keeps its conventional key order)
- [CI: Lint workflow](references/lint.yml) — Check-only Pint + Biome in CI (fails on drift)
- [CI: Tests workflow](references/tests.yml) — Multi-PHP-version matrix with Bun build
- [Pre-commit hook](references/pre-commit) — `.husky/pre-commit` contents (bare `lint-staged` — portable across npm and Bun)
- [package.json snippets](references/package-json.snippets.json) — Scripts, lint-staged config, and devDependencies to merge

## Notes

- If a project already exists in production with legacy tooling (npm, ESLint, Prettier, or an always-green lint CI), use the **formatting-enforcement** skill — it covers the retrofit runbook (chore-branch cleanup of accumulated drift + gate + hooks) that this bootstrap flow assumes is done at creation time.
- The pre-commit hook intentionally uses the bare `lint-staged` command (no `npx` / `bunx` prefix) — the husky runner puts `node_modules/.bin` on PATH, so the same hook file works under both npm and Bun.
- Hooks are per-worktree: each clone/worktree needs one `bun install` (or `npm install`) for `core.hooksPath` to be set. CI is the enforcement backstop for anyone who skips installs.