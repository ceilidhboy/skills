---
name: Skills
---

# ceilidhboy/skills

Agent skills for Laravel and PHP development. Compatible with Pi, Claude Code, Cursor, Codex, and any agent that supports SKILL.md skills.

## Installation

> This repo includes **skills** (for the Pi main agent) and **custom sub-agents** (reusable specialist sub-agents). Most users only need the skills. The custom sub-agents are only needed if you use the `pr-review` skill.

### Install skills

```bash
npx skills@latest add ceilidhboy/skills
```

Select the skills you want when prompted. Installing `pr-review` also makes the `pr-reviewer` sub-agent available.

### Install custom sub-agents (optional)

Only needed if you installed the `pr-review` skill above. Skip this if you didn't.

1. Clone the repo to a permanent location:

   ```bash
   git clone git@github.com:ceilidhboy/skills.git ~/.pi/skills-source
   cd ~/.pi/skills-source
   ```

2. Symlink the sub-agents into Pi:

   ```bash
   bash scripts/link-agents.sh
   ```

3. Run `/reload` in Pi (or restart Pi if you prefer).

**Keep the clone in place.** The script creates symlinks, so the clone must stay for the agents to work.

### 🚨 Updating

When the repo receives updates, refresh your installed skills and agents.

**Skills** update automatically:

```bash
npx skills@latest update
```

**Custom sub-agents** need a manual update:

```bash
cd ~/.pi/skills-source
git pull
bash scripts/link-agents.sh
```

After updating either, run `/reload` in Pi.

### Local development

If you have the repo cloned for development, both scripts create symlinks so edits take effect after `/reload`:

```bash
./scripts/link-skills.sh    # link skills to ~/.agents/skills/
./scripts/link-agents.sh   # link agents to ~/.pi/agent/agents/
```

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
