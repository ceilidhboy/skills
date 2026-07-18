---
name: Skills
---

# ceilidhboy/skills

Agent skills for Laravel and PHP development. Compatible with Pi, Claude Code, Cursor, Codex, and any agent that supports SKILL.md skills.

## Installation

```bash
npx skills@latest add ceilidhboy/skills
```

This installs skills only. This repo also includes **custom sub-agents** in `agents/` which must be installed separately:

```bash
# Clone the repo and link the custom agents
cd /tmp
git clone git@github.com:ceilidhboy/skills.git ceilidhboy-skills
cd ceilidhboy-skills
bash scripts/link-agents.sh
```

If you have the repo cloned locally for development, run both scripts from the repo root:

```bash
./scripts/link-skills.sh    # link skills to ~/.agents/skills/
./scripts/link-agents.sh   # link agents to ~/.pi/agent/agents/
```

Both scripts create symlinks so edits take effect after a Pi restart.

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
| orchestrator-mode | Strict orchestrator agent instructions |
| pest-testing | Pest 4 PHP testing framework |
| pr-review | Review a GitHub PR using reviewer + oracle sub-agents — post findings as a PR review comment |
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
| write-a-skill | Create new agent skills with proper structure |

## Custom Agents

This repo also includes custom Pi sub-agents in [`agents/`](agents/). These are installed to `~/.pi/agent/agents/` via `link-agents.sh`.

| Agent | Description |
|---|---|
| [pr-reviewer](agents/pr-reviewer.md) | Pull request review engine — delegates to reviewer + oracle, consolidates findings, posts comment |

## License

MIT

---

To add or update skills, see [CONTRIBUTING.md](CONTRIBUTING.md).
