---
name: serena-mcp-selection
description: Rules for selecting between the LSP and JetBrains Serena MCP servers when both are configured. Default to LSP unless the user explicitly opts in to JetBrains.
author: Mike Scott
version: '1.0.0'
updated: '2026-07-22'
---

# Serena MCP Server Selection

## Rule

When both `Serena (LSP)` and `Serena (JetBrains)` MCP servers are available, **always default to LSP** unless the user explicitly tells you to use the JetBrains backend.

## Guidance

- Use `mcp({ server: "Serena (LSP)", ... })` for all routine code navigation, editing, and search.
- Only switch to `mcp({ server: "Serena (JetBrains)", ... })` when the user says something like *"use the JetBrains version"*, *"switch to JetBrains"*, or otherwise explicitly opts in.
- JetBrains may be useful for deep sessions on a single project where the IDE is open alongside the agent. It is not robust for multi-project workflows.
- There is no auto-detection or fallback logic. The user chooses.
