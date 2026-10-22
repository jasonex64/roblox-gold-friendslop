"""Regression tests for tools/check_docs.py. Builds throwaway git repos in a temp dir.

Usage: python tools/test_check_docs.py    (exit 1 if any case fails)
"""
import os
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

SCRIPT = Path(__file__).resolve().parent / "check_docs.py"
TICKET = """---
id: T-002
---

## Goal
x

## Log
"""
ENTRY = "\n### 2026-10-19 — tester / agent\nDone: x\n"


def sh(repo, *args, env=None):
    r = subprocess.run(args, cwd=repo, capture_output=True, text=True, encoding="utf-8", env=env)
    if r.returncode != 0:
        raise RuntimeError(f"{' '.join(args)} failed: {r.stderr}")
    return r.stdout.strip()


def new_repo():
    repo = Path(tempfile.mkdtemp())
    sh(repo, "git", "init", "-q", "-b", "main")
    sh(repo, "git", "config", "user.email", "t@t")
    sh(repo, "git", "config", "user.name", "t")
    (repo / "docs" / "tickets").mkdir(parents=True)
    (repo / "docs" / "tickets" / "T-002.md").write_text(TICKET, encoding="utf-8")
    sh(repo, "git", "add", "-A")
    sh(repo, "git", "commit", "-qm", "T-002: create")
    return repo, sh(repo, "git", "rev-parse", "HEAD")


def commit(repo, msg, files=None, log=False):
    for name in files or []:
        (repo / name).write_text(msg, encoding="utf-8")
    if log:
        t = repo / "docs" / "tickets" / "T-002.md"
        t.write_text(t.read_text(encoding="utf-8") + ENTRY, encoding="utf-8")
    sh(repo, "git", "add", "-A")
    sh(repo, "git", "commit", "-qm", msg)


def run_check(repo, base, env=None):
    r = subprocess.run([sys.executable, str(SCRIPT), f"{base}..HEAD"], cwd=repo,
                       capture_output=True, text=True, encoding="utf-8", errors="replace", env=env)
    return r.returncode, (r.stdout + r.stderr).strip()


def case_no_prefix(repo, base):
    commit(repo, "add stuff", ["a.txt"], log=True)
    return run_check(repo, base)


def case_no_log(repo, base):
    commit(repo, "T-002: add stuff", ["a.txt"])
    return run_check(repo, base)


def case_documented(repo, base):
    commit(repo, "T-002: add stuff", ["a.txt"], log=True)
    return run_check(repo, base)


def case_missing_ticket(repo, base):
    commit(repo, "T-099: oops", ["a.txt"])
    return run_check(repo, base)


def case_heading_outside_log(repo, base):
    t = repo / "docs" / "tickets" / "T-002.md"
    t.write_text(t.read_text(encoding="utf-8").replace("## Goal", ENTRY + "\n## Goal"), encoding="utf-8")
    commit(repo, "T-002: add stuff", ["a.txt"])
    return run_check(repo, base)


def case_dirty_merge(repo, base):
    sh(repo, "git", "checkout", "-q", "-b", "side")
    commit(repo, "T-002: side", ["side.txt"], log=True)
    sh(repo, "git", "checkout", "-q", "main")
    commit(repo, "T-002: main", ["main.txt"], log=False)
    sh(repo, "git", "merge", "-q", "--no-ff", "--no-commit", "side")
    (repo / "sneaky.txt").write_text("x", encoding="utf-8")
    sh(repo, "git", "add", "-A")
    sh(repo, "git", "commit", "-qm", "Merge branch side")
    return run_check(repo, base)


def case_clean_merge(repo, base):
    sh(repo, "git", "checkout", "-q", "-b", "side")
    commit(repo, "T-002: side", ["side.txt"], log=True)
    sh(repo, "git", "checkout", "-q", "main")
    sh(repo, "git", "merge", "-q", "--no-ff", "-m", "Merge pull request #1 from x/side", "side")
    return run_check(repo, base)


def case_non_utf8_locale(repo, base):
    commit(repo, "T-002: add stuff", ["a.txt"], log=True)
    env = dict(os.environ, PYTHONUTF8="0", PYTHONCOERCECLOCALE="0", LC_ALL="C", LANG="C")
    return run_check(repo, base, env=env)


def case_next_revision_only(repo, base):
    (repo / "docs" / "NEXT_REVISION.md").write_text("| row |\n", encoding="utf-8")
    commit(repo, "T-002: note an idea")
    return run_check(repo, base)


def case_reviewer_closeout(repo, base):
    t = repo / "docs" / "tickets" / "T-002.md"
    t.write_text(t.read_text(encoding="utf-8").replace("id: T-002", "id: T-002\nstatus: done"), encoding="utf-8")
    commit(repo, "T-002: close out")
    return run_check(repo, base)


CASES = [  # (id, function, expected exit code)
    ("CHK-1 no T-### prefix", case_no_prefix, 1),
    ("CHK-2 change without Log entry", case_no_log, 1),
    ("CHK-3 documented change", case_documented, 0),
    ("CHK-4 ticket file missing", case_missing_ticket, 1),
    ("CHK-5 dated heading outside ## Log", case_heading_outside_log, 1),
    ("CHK-6 merge with its own undocumented change", case_dirty_merge, 1),
    ("CHK-7 clean merge of documented branch", case_clean_merge, 0),
    ("CHK-8 non-UTF-8 locale, documented change", case_non_utf8_locale, 0),
    ("CHK-9 NEXT_REVISION.md-only commit needs no Log", case_next_revision_only, 0),
    ("CHK-10 ticket-only closeout commit needs no Log", case_reviewer_closeout, 0),
]


def main():
    failed = 0
    for name, fn, want in CASES:
        repo, base = new_repo()
        try:
            got, out = fn(repo, base)
        finally:
            shutil.rmtree(repo, ignore_errors=True)
        ok = got == want
        failed += not ok
        print(f"{'PASS' if ok else 'FAIL'}  {name}: exit {got}, expected {want}")
        if not ok:
            print("      " + out.replace("\n", "\n      "))
    if failed:
        sys.exit(f"{failed} case(s) failed")


if __name__ == "__main__":
    main()
