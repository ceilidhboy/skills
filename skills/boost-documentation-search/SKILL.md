---
name: boost-documentation-search
description: Search Laravel Boost documentation effectively when Boost-specific information is needed.
---

# Boost Documentation Search

## When to use this skill

Use this skill when:
- Searching for Boost-specific documentation (guidelines, skills, boost:install, boost:update, etc.)
- Documentation searches are failing with "No results found"
- You need information about how Boost works internally
- You need to understand Boost's file structure or conventions

## How to Search Boost Documentation

### DO NOT Filter by Package

**CRITICAL**: Boost documentation is stored under `laravel/framework`, NOT `laravel/boost`.

❌ **WRONG:**
```
search-docs(queries: ["boost guidelines"], packages: ["laravel/boost"])
```

✅ **CORRECT:**
```
search-docs(queries: ["boost guidelines"])
```

### Use Simple, Broad Search Terms

- ✅ Good: `["boost guidelines", "custom guidelines", ".ai directory"]`
- ✅ Good: `["boost:install", "boost:update"]`
- ✅ Good: `["boost skills", "agent skills"]`
- ❌ Bad: `["how to override boost pint guidelines in .ai/guidelines/pint/core.blade.php"]` (too specific)

### Multiple Queries

Use multiple simple queries instead of one complex query:
```
queries: ["boost guidelines", "override guidelines", ".ai directory"]
```

## If Search Still Fails

If you get "No results found" even after following the above:

1. **Check if Boost MCP server is running** - Ask the user:
   > "The Boost documentation search is returning 'No results found'. Can you verify that the Boost MCP server is running correctly?"

2. **Try even broader terms** - Use single-word queries like `["boost"]` or `["guidelines"]`

3. **Ask the user for help** - The user may need to restart the Boost server or check the configuration

## Common Boost Documentation Topics

- **Custom Guidelines**: How to add/override guidelines in `.ai/guidelines/`
- **Skills**: How to create skills in `.ai/skills/`
- **Installation**: `boost:install` command and agent selection
- **Updates**: `boost:update` command to regenerate files
- **File Structure**: How `.ai/` directory maps to generated files
- **Agent Support**: Which agents are supported (Claude, Cursor, etc.)

