---
name: Skills
---

# ceilidhboy/skills

Agent skills for Laravel and PHP development. Compatible with Pi, Claude Code, Cursor, Codex, and any agent that supports SKILL.md skills.

## Installation

```bash
npx skills@latest add ceilidhboy/skills
```

Select the skills you want when prompted.

For local development, run from the repo root to link skills:

```bash
./scripts/link-skills.sh
```

After installing or updating, run `/reload` in Pi.

> Looking for Pi-specific skills and custom sub-agents? They've moved to dedicated Pi packages:
> - [pi-pr-reviewer](https://github.com/ceilidhboy/pi-pr-reviewer) — PR review agent + skill for Pi
> - [pi-agent-workflows](https://github.com/ceilidhboy/pi-agent-workflows) — Orchestrator-mode and delegation skills for Pi
> 
> These are installed via `pi install`, not the skills installer.

## Skills

| Skill | Description |
|---|---|
| action-pattern | Action classes with single responsibility and `execute()` convention |
| adr-creation | Dual-format ADR creation — Markdown (source of truth) + HTML (human explainer with diagrams). Keeps both in sync on updates |
| boost-documentation-search | Search Laravel Boost documentation effectively |
| component-composition-patterns | Building reusable components through composition |
| creating-pull-requests | Company pull request workflow and branch policy — know how (and how not) to create PRs |
| github-cli-workarounds | Workarounds for shell escaping with `gh` CLI |
| html-output | Generate self-contained HTML documents with inline SVG diagrams, grids, and colour styling — the html-output skill. Use when visual presentation benefits understanding |
| inertia-react-development | Inertia.js v2 React client-side development |
| javascript-typescript-conventions | JS/TS coding conventions and best practices |
| pest-testing | Pest 4 PHP testing framework |
| refactor-comments-that-are-code-smells | Code quality — refactor comments that explain what code does |
| routing-and-controllers | Laravel controllers, routes, and Wayfinder mapping |
| settings-system | Multi-tenant polymorphic settings system with agency-scoped records and global fallback chain |
| single-task-responsibility | Recognize SRP violations in task implementation |
| spatie-data-transfer-objects | Spatie Laravel Data transfer objects |
| tdd-laravel | Test-driven development with Pest PHP |
| troubleshooting | General troubleshooting diagnostic router |
| troubleshooting-backend | Laravel/PHP backend error troubleshooting |
| troubleshooting-frontend | TypeScript/React frontend error troubleshooting |
| unexpected-situations | Stop and consult when encountering unexpected situations |
| wayfinder-conventions | Routing conventions — actions over named routes |
| wayfinder-development | Laravel Wayfinder TypeScript route generation |
| monthly-report-generator | Generate monthly development reports for clients from git history, PRs, and ADRs — HTML for web, Markdown for email, optional wiki publishing |
| write-a-skill | Create new agent skills with proper structure |
| writing-skills-readme-first | Check the user's personal skills repo before creating new skills. Use `write-a-skill` for the template |

## License

MIT

---

To add or update skills, see [CONTRIBUTING.md](CONTRIBUTING.md).
