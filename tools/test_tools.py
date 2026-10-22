"""Regression tests for tools/board.py claims and tools/numbers.py. Throwaway repos in a temp dir.

Usage: python tools/test_tools.py    (exit 1 if any case fails)
"""
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

TOOLS = Path(__file__).resolve().parent
TICKET = """---
id: T-005
title: Example
milestone: M1
status: todo
owner:
agent:
reviewer:
depends_on: []
blocked_on:
---

## Log
"""
DECISIONS = "| ID | Date | Decision | Source | Supersedes |\n|---|---|---|---|---|\n| D-020 | x | x | x | — |\n"
DESIGN = "# Design\n\n## 8 Finds and starter tuning\n"


def sh(cwd, *args):
    r = subprocess.run(args, cwd=cwd, capture_output=True, text=True, encoding="utf-8")
    if r.returncode != 0:
        raise RuntimeError(f"{' '.join(args)} failed: {r.stderr}")
    return r.stdout


def new_repo(config=None):
    repo = Path(tempfile.mkdtemp())
    (repo / "tools").mkdir()
    for name in ("board.py", "numbers.py"):
        shutil.copy(TOOLS / name, repo / "tools" / name)
    (repo / "docs" / "tickets").mkdir(parents=True)
    (repo / "docs" / "tickets" / "T-005.md").write_text(TICKET, encoding="utf-8")
    (repo / "docs" / "DECISIONS.md").write_text(DECISIONS, encoding="utf-8")
    (repo / "docs" / "DESIGN.md").write_text(DESIGN, encoding="utf-8")
    if config is not None:
        (repo / "src" / "shared").mkdir(parents=True)
        (repo / "src" / "shared" / "Config.luau").write_text(config, encoding="utf-8")
    return repo


def run(repo, *args):
    r = subprocess.run([sys.executable, *args], cwd=repo, capture_output=True, text=True,
                       encoding="utf-8", errors="replace")
    return r.returncode, (r.stdout + r.stderr).strip()


def case_claim_branch(repo):
    origin = Path(tempfile.mkdtemp())
    sh(origin, "git", "init", "-q", "--bare")
    sh(repo, "git", "init", "-q", "-b", "main")
    sh(repo, "git", "config", "user.email", "t@t")
    sh(repo, "git", "config", "user.name", "t")
    sh(repo, "git", "add", "-A")
    sh(repo, "git", "commit", "-qm", "T-005: create")
    sh(repo, "git", "remote", "add", "origin", str(origin))
    sh(repo, "git", "push", "-q", "origin", "main", "main:T-005-run-place")
    code, out = run(repo, "tools/board.py")
    shutil.rmtree(origin, ignore_errors=True)
    if "(claimed: T-005-run-place)" not in out:
        return 1, "claim not shown:\n" + out
    return code, out


def case_word_cap(repo):
    t = repo / "docs" / "tickets" / "T-005.md"
    t.write_text(t.read_text(encoding="utf-8").replace("## Log", "word " * 301 + "\n\n## Log"), encoding="utf-8")
    return run(repo, "tools/board.py", "--local")


def case_word_cap_done(repo):
    t = repo / "docs" / "tickets" / "T-005.md"
    text = t.read_text(encoding="utf-8").replace("## Log", "word " * 301 + "\n\n## Log")
    text = text.replace("status: todo", "status: done").replace("owner:\n", "owner: a\n").replace("agent:\n", "agent: b\n").replace("reviewer:\n", "reviewer: c\n")
    t.write_text(text, encoding="utf-8")
    return run(repo, "tools/board.py", "--local")


def case_cited_decision(repo):
    return run(repo, "tools/numbers.py")


def case_uncited(repo):
    return run(repo, "tools/numbers.py")


def case_bad_section(repo):
    return run(repo, "tools/numbers.py")


def case_strict_provisional(repo):
    return run(repo, "tools/numbers.py", "--strict")


def case_provisional_ok(repo):
    return run(repo, "tools/numbers.py")


CASES = [  # (id, function, Config.luau or None, expected exit code)
    ("BRD-1 pushed T-###-* branch shows as a claim", case_claim_branch, None, 0),
    ("BRD-2 todo ticket over 300 words above Log fails", case_word_cap, None, 1),
    ("BRD-3 done ticket is exempt from the word cap", case_word_cap_done, None, 0),
    ("NUM-1 value citing an existing D-### passes", case_cited_decision,
     "return {\n\tShiftSeconds = 600, -- D-020\n}\n", 0),
    ("NUM-2 value with no citation fails", case_uncited,
     "return {\n\tShiftSeconds = 600,\n}\n", 1),
    ("NUM-3 PROVISIONAL citing a missing DESIGN section fails", case_bad_section,
     "return {\n\tShiftSeconds = 600, -- PROVISIONAL DESIGN §99\n}\n", 1),
    ("NUM-4 PROVISIONAL value passes normally", case_provisional_ok,
     "return {\n\tNuggetValue = 25, -- PROVISIONAL DESIGN §8\n}\n", 0),
    ("NUM-5 --strict fails while any value is PROVISIONAL", case_strict_provisional,
     "return {\n\tNuggetValue = 25, -- PROVISIONAL DESIGN §8\n}\n", 1),
]


def main():
    failed = 0
    for name, fn, config, want in CASES:
        repo = new_repo(config)
        try:
            got, out = fn(repo)
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
