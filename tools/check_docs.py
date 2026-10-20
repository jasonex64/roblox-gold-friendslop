"""Fail loudly if any commit in a range is undocumented.

Usage:
  python tools/check_docs.py                # range origin/main..HEAD (run before opening a PR)
  python tools/check_docs.py BASE..HEAD     # explicit range (used by CI)

Rules, per non-merge commit in the range:
  1. Message starts with "T-###: " and docs/tickets/T-###.md exists at HEAD.
  2. If the commit touches any file other than its own ticket file, that ticket's
     Log must gain at least one new "### YYYY-MM-DD — " entry somewhere in the range.
"""
import re
import subprocess
import sys

LOG_ENTRY = re.compile(r"^### \d{4}-\d{2}-\d{2} — ", re.M)
SUBJECT = re.compile(r"^(T-\d{3}): \S")


def git(*args):
    r = subprocess.run(["git", *args], capture_output=True, text=True)
    if r.returncode != 0:
        sys.exit(f"git {' '.join(args)} failed:\n{r.stderr.strip()}")
    return r.stdout


def log_entries(rev, tid):
    path = f"docs/tickets/{tid}.md"
    r = subprocess.run(["git", "show", f"{rev}:{path}"], capture_output=True, text=True)
    if r.returncode != 0:
        return 0  # file did not exist at rev
    return len(LOG_ENTRY.findall(r.stdout))


def main():
    rng = sys.argv[1] if len(sys.argv) > 1 else "origin/main..HEAD"
    if ".." not in rng:
        sys.exit(f"range must look like BASE..HEAD, got {rng!r}")
    base, head = rng.split("..", 1)
    commits = git("rev-list", "--no-merges", "--reverse", rng).split()
    if not commits:
        print(f"check_docs: no commits in {rng}")
        return

    errors, needs_log = [], set()
    for sha in commits:
        subject = git("log", "-1", "--format=%s", sha).strip()
        short = sha[:7]
        m = SUBJECT.match(subject)
        if not m:
            errors.append(f"{short} '{subject}': message must start with 'T-###: '")
            continue
        tid = m.group(1)
        ticket = f"docs/tickets/{tid}.md"
        if subprocess.run(["git", "cat-file", "-e", f"{head}:{ticket}"],
                          capture_output=True).returncode != 0:
            errors.append(f"{short}: {ticket} does not exist")
            continue
        files = git("diff-tree", "--no-commit-id", "--name-only", "-r", "--root", sha).split()
        if any(f != ticket for f in files):
            needs_log.add(tid)

    for tid in sorted(needs_log):
        if log_entries(head, tid) <= log_entries(base, tid):
            errors.append(f"{tid}: code/docs changed but no new Log entry in docs/tickets/{tid}.md")

    if errors:
        print(f"check_docs FAILED for {rng}:", file=sys.stderr)
        for e in errors:
            print("  " + e, file=sys.stderr)
        sys.exit(1)
    print(f"check_docs OK: {len(commits)} commit(s) in {rng}")


if __name__ == "__main__":
    main()
