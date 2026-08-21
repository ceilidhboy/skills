---
name: serena-conventions
description: Use when navigating code with Serena tools — finding symbols, reading method bodies, inserting code, or deciding between Serena and context-mode for code tasks. Covers correct parameter shapes, the Serena-first workflow, and when to fall back to context-mode.
---

# Serena Conventions

## Overview

Serena provides semantic code navigation via LSP — symbol lookup, type info, references, and structural edits. Context-mode provides bulk reading and sandbox execution. Use both: Serena for precision, context-mode for reconnaissance and large outputs.

## Decision Tree

```
Need to understand code structure?
├─ Yes → Serena (find_symbol, get_symbols_overview)
│        Need full file contents for conventions/style?
│        └─ Yes → context-mode (ctx_batch_execute with cat)
├─ No → Need to insert/replace a specific method?
│        ├─ Yes → Serena (insert_after_symbol, replace_symbol_body)
│        └─ No → Need to search for a pattern across files?
│                 ├─ Yes → Serena (serena_search_for_pattern)
│                 └─ No → context-mode or bash as appropriate
```

**Use Serena for:**
- Finding a specific symbol by name (`serena_find_symbol`)
- Getting an outline of a file (`serena_get_symbols_overview`)
- Finding references to a symbol (`serena_find_referencing_symbols`)
- Inserting code before/after a symbol (`serena_insert_after_symbol`)
- Replacing a method body (`serena_replace_symbol_body`)
- Searching for text patterns in code (`serena_search_for_pattern`)
- Getting diagnostics for a file (`serena_get_diagnostics_for_file`)

**Use context-mode for:**
- Reading full files to understand conventions/style (`ctx_batch_execute` with `cat`)
- Running commands that produce large output (`ctx_batch_execute`)
- Bulk operations across multiple files
- Executing code in sandbox (`ctx_execute`)

**Use bash for:**
- File mutations (mkdir, mv, cp, rm)
- Git operations
- Running artisan/npm commands

## Parameter Shapes

**Critical distinction:** Two different keys for symbol names.

| Tool | Key | Example |
|---|---|---|
| `serena_find_symbol` | `name_path_pattern` | `Company/members` |
| `serena_safe_delete_symbol` | `name_path_pattern` | `Company/oldMethod` |
| `serena_find_referencing_symbols` | `name_path` | `Company/members` |
| `serena_find_declaration` | `name_path` | `Company/members` |
| `serena_find_implementations` | `name_path` | `Profile` |
| `serena_replace_symbol_body` | `name_path` | `Company/members` |
| `serena_insert_before_symbol` | `name_path` | `Company/members` |
| `serena_insert_after_symbol` | `name_path` | `Company/members` |
| `serena_rename_symbol` | `name_path` | `Company/members` |

**Name path format:** `ClassName/methodName` — not glob patterns, not fully qualified. Just `Company/members`, never `Company/*` or `App\Models\Company::members`.

**All tools also accept:**
- `relative_path` — path relative to project root (e.g., `app/Models/Company.php`)
- `project` — project path (defaults to CWD)
- `timeout_ms` — override default timeout

## Workflow: Adding a Relationship to a Model

1. **Outline the target file:**
   ```
   serena_get_symbols_overview(relative_path: "app/Models/Company.php")
   ```

2. **Find the insertion point** (last method before helper methods):
   ```
   serena_find_symbol(name_path_pattern: "Company/hasMember", relative_path: "app/Models/Company.php", include_body: true)
   ```

3. **Insert after it:**
   ```
   serena_insert_after_symbol(name_path: "Company/hasMember", relative_path: "app/Models/Company.php", body: "...")
   ```

4. **Check for missing imports:**
   ```
   serena_search_for_pattern(pattern: "use Illuminate.*HasMany", relative_path: "app/Models/Company.php", restrict_search_to_code_files: true)
   ```

5. **Run Pint:**
   ```
   vendor/bin/pint --dirty --format agent
   ```

## Workflow: Understanding Existing Code

1. **Outline the file:**
   ```
   serena_get_symbols_overview(relative_path: "app/Models/User.php")
   ```

2. **Find specific methods:**
   ```
   serena_find_symbol(name_path_pattern: "User/companies", include_body: true)
   ```

3. **Find what references a symbol:**
   ```
   serena_find_referencing_symbols(name_path: "Company/members", relative_path: "app/Models/Company.php")
   ```

4. **Need full file for style/conventions?** Fall back to context-mode:
   ```
   ctx_batch_execute(commands: [{label: "User model", command: "cat app/Models/User.php"}])
   ```

## Common Mistakes

### Using glob patterns in find_symbol

```
# ❌ Wrong — returns empty array
serena_find_symbol(name_path_pattern: "Company/*")

# ✅ Correct — exact name path
serena_find_symbol(name_path_pattern: "Company/members")
```

### Using name_path where name_path_pattern is expected

The adapter auto-repairs this, but it's better to use the correct key. When in doubt: `find_symbol` and `safe_delete_symbol` use `pattern`, everything else uses plain `name_path`.

### Reading full files via Serena when context-mode is faster

Serena's `get_symbols_overview` gives outlines, not full contents. If you need to understand coding conventions across 5 files, `ctx_batch_execute` with `cat` is faster and indexes the output for later search.

### Not checking for missing imports after insertions

After `serena_insert_after_symbol`, always verify the file has the required `use` statements. Search for the import pattern:
```
serena_search_for_pattern(pattern: "use Illuminate.*HasMany", relative_path: "app/Models/...")
```

## Environment Variables

| Variable | Effect |
|---|---|
| `PI_SERENA_STRICT=1` | Block raw code reads until Serena is used first |
| `PI_SERENA_REMIND_ON_FIRST_MISS=1` | Send reminder after first code-read miss |
| `SERENA_EAGER_STARTUP=1` | Pre-spawn worker on session start |
| `SERENA_LANGUAGE_BACKEND=LSP` | Use LSP backend (default) |
| `SERENA_LANGUAGE_BACKEND=JetBrains` | Use JetBrains backend (requires IDE) |

## Troubleshooting

**Stale results or errors:** Run `/serena-restart` to restart the worker.

**Overview returns only namespace/class:** Try `serena_get_symbols_overview` with `depth: 2` or higher. If still shallow, the language server may need indexing time after project activation.

**Tool returns empty array:** Check you're using `name_path_pattern` (not `name_path`) for `find_symbol`, and that the name path is exact (e.g., `Company/members`, not `Company/*`).
