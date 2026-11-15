#!/usr/bin/env python3
"""Measure one real Pi run: wall time, peak RSS of its whole process tree,
exit status.

Use when sizing concurrency on a RAM-limited box. Sampling the *tree* beats
`/usr/bin/time` (slim images often lack it) and beats `VmHWM` read from the
parent alone: a run that fans out into subagents spends most of its memory in
child processes, which the parent's own high-water mark never sees. Subprocess
ownership beats shell backgrounding, which a terminal tool rejects.

    ./measure_session_rss.py --workdir /path/to/repo \
        --model opencode-go/deepseek-v4.1-flash --print-only

Set the provider env var (or pass --env-file) so the CHILD inherits the key.
"""
import argparse
import os
import subprocess
import sys
import time


def load_env_file(path, env):
    try:
        with open(path) as fh:
            for line in fh:
                line = line.strip()
                if line and not line.startswith("#") and "=" in line:
                    k, v = line.split("=", 1)
                    env.setdefault(k, v.strip().strip('"').strip("'"))
    except FileNotFoundError:
        pass


def tree_rss_kb(root):
    """Sum VmRSS over root and every descendant, from one /proc scan."""
    children, rss = {}, {}
    for entry in os.listdir("/proc"):
        if not entry.isdigit():
            continue
        pid = int(entry)
        try:
            with open(f"/proc/{pid}/stat") as fh:
                ppid = int(fh.read().rsplit(")", 1)[1].split()[1])
            with open(f"/proc/{pid}/status") as fh:
                for line in fh:
                    if line.startswith("VmRSS:"):
                        rss[pid] = int(line.split()[1])
                        break
        except (FileNotFoundError, ProcessLookupError, IndexError, ValueError):
            continue
        children.setdefault(ppid, []).append(pid)
    total, stack = 0, [root]
    while stack:
        cur = stack.pop()
        total += rss.get(cur, 0)
        stack.extend(children.get(cur, []))
    return total


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--pi", default="/opt/data/tools/bin/pi")
    ap.add_argument("--workdir", default=".")
    ap.add_argument("--model", default=os.environ.get("PI_MODEL", ""))
    ap.add_argument("--tools", default="read,grep,find,ls")
    ap.add_argument("--prompt", default="Read the source files and produce a "
                                       "5-bullet code review.")
    ap.add_argument("--env-file", default="/opt/data/.env")
    ap.add_argument("--print-only", action="store_true",
                    help="do not print the model output")
    a = ap.parse_args()

    env = dict(os.environ)
    load_env_file(a.env_file, env)

    cmd = [a.pi, "--tools", a.tools, "-p", a.prompt]
    if a.model:
        cmd[1:1] = ["--model", a.model]

    t0 = time.time()
    proc = subprocess.Popen(cmd, cwd=a.workdir, env=env,
                            stdout=subprocess.PIPE, stderr=subprocess.DEVNULL,
                            text=True)
    peak = 0
    while proc.poll() is None:
        peak = max(peak, tree_rss_kb(proc.pid))
        time.sleep(0.5)
    out = proc.stdout.read() or ""

    print(f"wall={int(time.time() - t0)}s peak_tree_rss={peak // 1024}MB "
          f"exit={proc.returncode}")
    if not a.print_only:
        print(out[:500])
    return 0 if proc.returncode == 0 else 1


if __name__ == "__main__":
    sys.exit(main())
