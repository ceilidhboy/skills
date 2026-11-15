# Replicating a Pi setup on another host

Goal: a second machine whose Pi reviews the same way as the reference machine. Parity has five
layers, and a missing one surfaces later as "the same skill behaves differently".

| Layer | Where | Compared how |
|---|---|---|
| Pi version | `pi --version` | must match exactly; pin it, never "latest" |
| Packages | `pi list` | against the reference's `pi list` |
| Package-shipped skills and prompts | `<pkg>/skills`, `<pkg>/prompts` under `$PI_CODING_AGENT_DIR` | names only — installing the package covers them |
| Standalone skills | `$PI_CODING_AGENT_DIR/skills` **and** `~/.agents/skills` | set difference |
| Context files | `APPEND_SYSTEM.md`, `AGENTS.md` in `$PI_CODING_AGENT_DIR` | copied verbatim |

## Procedure

1. Get the reference host's `pi list`. Install what it has:
   `pi install npm:<pkg>` or `pi install git:<host>/<owner>/<repo>.git`. No TTY needed — it does
   not prompt when stdin is not a terminal.
2. Drop host-specific packages (chimes, Windows helpers, history sync) instead of copying blindly.
3. Collect both skill inventories and diff them as **sets**, never by eye:

   ```python
   store = {p.name for p in pathlib.Path.home().joinpath('.agents/skills').iterdir()}
   # reference list: comma-separated names pasted from the other host's report
   ```

4. Read the residue, do not guess it. Package skills are already covered by step 1; whatever
   remains came from skills repos, so resolve it from the reference host's
   `~/.agents/.skill-lock.json`:

   ```bash
   jq -r '.skills | to_entries[] | "\(.value.source // "?")\t\(.key)"' ~/.agents/.skill-lock.json | sort -u
   ```

5. Copy context files verbatim — no package ships them, and they change system-prompt behaviour.
6. Re-run the diff until the only differences left are ones you knowingly accepted, and tell the
   user which those are and why.

## Pitfalls

- **`pi list` is only the package layer.** Two hosts can show identical packages and still differ
  by 30 skills, because most skills come from the store or from repos installed with a different
  tool. Always diff skills separately.
- **A package that fails to install silently takes its skills with it.** Check the exit status of
  every `pi install`; a compiler error means the skills never landed.
- **Prompts arrive with packages, not with skills.** Missing `/parallel-review`-style prompts mean
  a package is missing, so look at `pi list` before hunting the filesystem.
- **Naming a skill is not locating it.** A skill absent from every installed package came from a
  skills repo; the lock file is the only reliable attribution (see procedure step 4).
