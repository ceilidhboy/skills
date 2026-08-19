---
name: Skills
---

# ceilidhboy/skills

Agent skills for Laravel and PHP development. Compatible with Pi, Claude Code, Cursor, Codex, and any agent that supports SKILL.md skills.

## Installation

```bash
# Global install (recommended)
npx skills@latest add ceilidhboy/skills -g

# Per-project install
npx skills@latest add ceilidhboy/skills
```

Select the skills you want when prompted.

After installing or updating, run `/reload` in Pi.

## Update

```bash
# Global update (recommended — use if installed globally)
npx skills@latest update -g

# Per-project update
npx skills@latest update -p

# Both
npx skills@latest update -g -p
```

Omitting both `-g` and `-p` will prompt interactively.

## Local Development

```bash
# Link skills locally for testing
bash scripts/link-skills.sh

# Verify links
bash scripts/verify-skills.sh --mode dev
```

> Looking for Pi-specific custom sub-agents?
> - `agents/` in this repo — the `reviewer` and `oracle` sub-agents used by the `pr-review` skill (linked into `~/.pi/agent/agents/` by `scripts/link-skills.sh`)
> - [pi-agent-workflows](https://github.com/ceilidhboy/pi-agent-workflows) — Orchestrator-mode and delegation skills for Pi (installed via `pi install`)

## Skills

| Skill | Description |
|---|---|
| action-pattern | Action classes with single responsibility and `execute()` convention |
| adr-creation | Dual-format ADR creation — Markdown (source of truth) + HTML (human explainer with diagrams). Keeps both in sync on updates |
| boost-documentation-search | Search Laravel Boost documentation effectively |
| component-composition-patterns | Building reusable components through composition |
| creating-pull-requests | Company pull request workflow and branch policy — know how (and how not) to create PRs |
| formatting-enforcement | Retrofit formatting enforcement on existing projects — fix silent-green lint CI, clear accumulated drift, resolve Prettier/Biome conflicts, install pre-commit hooks |
| github-cli-workarounds | Workarounds for shell escaping with `gh` CLI |
| html-output | Generate self-contained HTML documents with inline SVG diagrams, grids, and colour styling. Use when visual presentation benefits understanding |
| inertia-react-conventions | Inertia.js v2 React component architecture and project conventions |
| javascript-typescript-conventions | JS/TS coding conventions and best practices |
| monthly-report-generator | Generate monthly development reports for clients from git history, PRs, and ADRs — HTML for web, Markdown for email, optional wiki publishing |
| pest-testing-conventions | Pest 4 PHP testing conventions, workflows, and troubleshooting |
| pr-review | Orchestrated PR reviews — runs reviewer + oracle sub-agents directly, consolidates findings into a structured report, and asks for approval before posting (the former pi-pr-reviewer package has been retired; this skill is the replacement) |
| project-bootstrap | Company tooling standard for new Laravel + Inertia + React projects — Bun, Biome, Pint, Wayfinder, check-only CI, pre-commit hooks |
| refactor-comments-that-are-code-smells | Code quality — refactor comments that explain what code does |
| routing-and-controllers | Laravel controllers, routes, and Wayfinder mapping |
| serena-mcp-selection | Default to the LSP Serena MCP server; only use JetBrains when the user explicitly opts in |
| settings-system | Multi-tenant polymorphic settings system with agency-scoped records and global fallback chain |
| single-task-responsibility | Recognize SRP violations in task implementation |
| spatie-data-transfer-objects | Spatie Laravel Data transfer objects with TypeScript generation |
| tdd-laravel | Test-driven development with Pest PHP |
| troubleshooting | General troubleshooting diagnostic router |
| troubleshooting-backend | Laravel/PHP backend error troubleshooting |
| troubleshooting-frontend | TypeScript/React frontend error troubleshooting |
| unexpected-situations | Stop and consult when encountering unexpected situations |
| wayfinder-conventions | Routing conventions — actions over named routes |
| write-a-skill | Create new agent skills with proper structure |
| writing-skills-readme-first | Check the user's personal skills repo before creating new skills |

## License

MIT
