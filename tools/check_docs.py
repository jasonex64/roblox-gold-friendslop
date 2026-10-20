"""Fail loudly if any commit in a range is undocumented.

Usage:
  python tools/check_docs.py                # range origin/main..HEAD (run before opening a PR)
  python tools/check_docs.py BASE..HEAD     # explicit range (used by CI)

Rules, per commit in the range:
  1. Message starts with "T-###: " and docs/tickets/T-###.md exists at HEAD.
  2. If the commit touches any file other than its own ticket file, that ticket's
     "## Log" section must gain at least one new "### YYYY-MM-DD — " entry in the range.
A merge commit is exempt only if it introduces no changes of its own (a clean merge:
every file it brings in comes from commits that are themselves checked).
"""
import re
import subprocess
import sys

LOG_ENTRY = re.compile(r"^### \d{4}-\d{2}-\d{2} — ", re.M)
SUBJECT = re.compile(r"^(T-\d{3}): \S")


def run(*args):
    return subprocess.run(["git", *args], capture_output=True, text=True, encoding="utf-8")


def git(*args):
    r = run(*args)
    if r.returncode != 0:
        sys.exit(f"git {' '.join(args)} failed:\n{r.stderr.strip()}")
    return r.stdout


def log_entries(rev, tid):
    path = f"docs/tickets/{tid}.md"
    r = run("show", f"{rev}:{path}")
    if r.returncode != 0:
        return 0  # file did not exist at rev
    m = re.search(r"^## Log[ \t]*$(.*?)(?=^## |\Z)", r.stdout, re.M | re.S)
    if not m:
        sys.exit(f"{path} at {rev[:7]} has no '## Log' section")
    return len(LOG_ENTRY.findall(m.group(1)))


def changed_files(sha):
    if len(git("rev-list", "--parents", "-n", "1", sha).split()) > 2:
        # merge: only paths that differ from every parent, i.e. the merge's own changes
        return git("diff-tree", "--no-commit-id", "--name-only", "--cc", sha).splitlines()
    return git("diff-tree", "--no-commit-id", "--name-only", "-r", "--root", sha).splitlines()


def main():
    rng = sys.argv[1] if len(sys.argv) > 1 else "origin/main..HEAD"
    if ".." not in rng:
        sys.exit(f"range must look like BASE..HEAD, got {rng!r}")
    base, head = rng.split("..", 1)
    commits = git("rev-list", "--reverse", rng).split()
    if not commits:
        print(f"check_docs: no commits in {rng}")
        return

    errors, needs_log = [], set()
    for sha in commits:
        files = changed_files(sha)
        if not files:
            continue  # clean merge or empty commit: nothing of its own to document
        subject = git("log", "-1", "--format=%s", sha).strip()
        short = sha[:7]
        m = SUBJECT.match(subject)
        if not m:
            errors.append(f"{short} '{subject}': message must start with 'T-###: '")
            continue
        tid = m.group(1)
        ticket = f"docs/tickets/{tid}.md"
        if run("cat-file", "-e", f"{head}:{ticket}").returncode != 0:
            errors.append(f"{short}: {ticket} does not exist")
            continue
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
