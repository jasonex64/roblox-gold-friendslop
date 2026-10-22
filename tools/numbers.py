"""List every gameplay number and fail loudly if one has no source (D-011).

Usage: python tools/numbers.py            # exit 1 if any value is uncited or cites something missing
       python tools/numbers.py --strict   # also exit 1 if any value is still PROVISIONAL (milestone review)

All gameplay/timing/economy/limit values live in src/shared/Config.luau, one per line.
Every line holding a number literal must end with one of:
    -- D-###                    an approved row in docs/DECISIONS.md
    -- EXP-###                  docs/experiments/EXP-###.md exists
    -- PROVISIONAL DESIGN §N    agent-chosen from docs/DESIGN.md section N, awaiting a human
Stdlib only.
"""
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CONFIG = ROOT / "src" / "shared" / "Config.luau"
# Any Luau number literal: 10, 1_000, 2.5, .5, 1e3, 1.5E-2, 0x10, 0XFF_FF, 0b1010.
NUMBER = re.compile(
    r"(?<![\w.])("
    r"0[xX][0-9a-fA-F_]+|0[bB][01_]+"
    r"|(\d[\d_]*(\.[\d_]*)?|\.\d[\d_]*)([eE][+-]?\d[\d_]*)?"
    r")(?![\w.])"
)
CITE = re.compile(r"--\s*(D-\d{3}|EXP-\d{3}|PROVISIONAL DESIGN §(\d+))\s*$")


def main():
    args = sys.argv[1:]
    if args not in ([], ["--strict"]):
        sys.exit(f"usage: python tools/numbers.py [--strict], got {args}")
    strict = args == ["--strict"]
    if not CONFIG.exists():
        print("numbers: no src/shared/Config.luau yet, nothing to check")
        return

    decisions = set(re.findall(r"^\| (D-\d{3}) \|", (ROOT / "docs" / "DECISIONS.md").read_text(encoding="utf-8"), re.M))
    sections = set(re.findall(r"^## (\d+) ", (ROOT / "docs" / "DESIGN.md").read_text(encoding="utf-8"), re.M))

    errors, provisional = [], []
    for n, line in enumerate(CONFIG.read_text(encoding="utf-8").splitlines(), 1):
        code = line.split("--", 1)[0]
        if not NUMBER.search(code):
            continue
        where = f"Config.luau:{n}"
        m = CITE.search(line)
        if not m:
            errors.append(f"{where}: number without '-- D-###', '-- EXP-###' or '-- PROVISIONAL DESIGN §N': {line.strip()}")
            continue
        cite = m.group(1)
        if cite.startswith("D-") and cite not in decisions:
            errors.append(f"{where}: {cite} is not in docs/DECISIONS.md")
        elif cite.startswith("EXP-") and not (ROOT / "docs" / "experiments" / f"{cite}.md").exists():
            errors.append(f"{where}: docs/experiments/{cite}.md does not exist")
        elif m.group(2) and m.group(2) not in sections:
            errors.append(f"{where}: DESIGN.md has no section {m.group(2)}")
        elif m.group(2):
            provisional.append(f"{where}: {code.strip()}  ({cite})")

    for p in provisional:
        print("PROVISIONAL  " + p)
    print(f"numbers: {len(provisional)} provisional value(s)")
    if strict and provisional:
        errors.append(f"--strict: {len(provisional)} PROVISIONAL value(s) need a human D-### before this milestone closes")
    if errors:
        print("numbers FAILED:", file=sys.stderr)
        for e in errors:
            print("  " + e, file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
