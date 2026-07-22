---
name: writing-skills-readme-first
description: Before creating any new skill, check the user's personal skills repo if they have one. Use the write-a-skill skill for the template. This is the mandatory starting point for all skill creation work.
author: Mike Scott
version: '1.0.0'
updated: '2026-07-22'
---

# Writing Skills — Read Me First

**Activate this skill whenever skill creation, writing, or authoring is discussed.**

## Rule

Before creating or modifying any skill, check whether the user has a personal skills repo configured.

## Process

1. **Check for a local config** — Look for `~/.config/skills/config.json`. If it exists, read the `skillsRepo` field.
   - If found → you know where their skills repo is.
   - If not found → ask the user: *"Do you have a personal skills repo you'd like new skills created in?"*

2. **If the user provides a path** — Save it for next time:
   - Create `~/.config/skills/config.json` (and the `skills` directory if needed) with:
     ```json
     { "skillsRepo": "/path/to/repo" }
     ```

3. **Read the repo's conventions** — Navigate to the skills repo and read:
   - `README.md` — for the available skills and overview
   - `CONTRIBUTING.md` — for the exact process to add or update skills

4. **Use `write-a-skill`** — Follow the `write-a-skill` skill for the SKILL.md template and structure.

5. **If no repo exists** — Skip steps 1-3 and just use `write-a-skill` directly. The skill will go wherever the project or user context suggests.
