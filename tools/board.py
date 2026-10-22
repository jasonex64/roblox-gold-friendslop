"""Validate ticket files and print the board. Exits 1 on any invalid ticket.

Usage: python tools/board.py            # claims read from `git ls-remote origin`
       python tools/board.py --local    # skip the remote claim lookup (offline)
Stdlib only. Source of truth is docs/tickets/T-*.md frontmatter on main,
plus pushed `T-###-*` branches, which are claims (D-010).
"""
import re
import subprocess
import sys
from pathlib import Path

TICKET_DIR = Path(__file__).resolve().parent.parent / "docs" / "tickets"
STATUSES = ["todo", "doing", "blocked", "review", "done"]
REQUIRED = ["id", "title", "milestone", "status", "owner", "agent",
            "reviewer", "depends_on", "blocked_on"]


def parse(path):
    text = path.read_text(encoding="utf-8")
    m = re.match(r"^---\n(.*?)\n---\n", text, re.S)
    if not m:
        raise ValueError("missing frontmatter")
    fields = {}
    for line in m.group(1).splitlines():
        key, sep, value = line.partition(":")
        if not sep:
            raise ValueError(f"bad frontmatter line: {line!r}")
        fields[key.strip()] = value.strip()
    deps = fields.get("depends_on", "")
    if not re.fullmatch(r"\[(\s*T-\d{3}\s*(,\s*T-\d{3}\s*)*)?\]", deps):
        raise ValueError(f"depends_on must look like [T-001, T-002], got {deps!r}")
    fields["depends_on"] = re.findall(r"T-\d{3}", deps)
    return fields


def check(t, path, all_ids):
    errs = []
    missing = [k for k in REQUIRED if k not in t]
    if missing:
        return [f"missing fields {missing}"]
    if t["id"] != path.stem:
        errs.append(f"id {t['id']} does not match filename")
    if t["status"] not in STATUSES:
        errs.append(f"status {t['status']!r} not in {STATUSES}")
    if t["status"] != "todo" and not (t["owner"] and t["agent"]):
        errs.append("owner and agent required once status leaves todo")
    if t["status"] == "blocked" and not t["blocked_on"]:
        errs.append("blocked requires blocked_on")
    if t["status"] in ("review", "done"):
        if not t["reviewer"]:
            errs.append("reviewer required for review/done")
        elif t["reviewer"] == t["owner"]:
            errs.append("reviewer must differ from owner")
    for d in t["depends_on"]:
        if d not in all_ids:
            errs.append(f"depends_on {d} does not exist")
    return errs


def remote_claims():
    """Map ticket id -> claiming branch names, from pushed T-###-* branches on origin."""
    r = subprocess.run(["git", "ls-remote", "--heads", "origin", "refs/heads/T-*"],
                       capture_output=True, text=True, encoding="utf-8")
    if r.returncode != 0:
        sys.exit(f"git ls-remote origin failed (use --local offline):\n{r.stderr.strip()}")
    claims = {}
    for line in r.stdout.splitlines():
        branch = line.split("refs/heads/", 1)[1]
        m = re.match(r"(T-\d{3})-", branch)
        if m:
            claims.setdefault(m.group(1), []).append(branch)
    return claims


def main():
    args = sys.argv[1:]
    if args not in ([], ["--local"]):
        sys.exit(f"usage: python tools/board.py [--local], got {args}")
    claims = {} if args else remote_claims()
    paths = sorted(TICKET_DIR.glob("T-*.md"))
    tickets, errors = {}, []
    for p in paths:
        try:
            tickets[p.stem] = (parse(p), p)
        except ValueError as e:
            errors.append(f"{p.name}: {e}")
    for tid, (t, p) in tickets.items():
        errors += [f"{p.name}: {e}" for e in check(t, p, tickets)]
    if errors:
        print("INVALID TICKETS:", file=sys.stderr)
        for e in errors:
            print("  " + e, file=sys.stderr)
        sys.exit(1)

    by_ms = {}
    for t, _ in tickets.values():
        by_ms.setdefault(t["milestone"], []).append(t)
    for ms in sorted(by_ms):
        print(f"== {ms} ==")
        for t in sorted(by_ms[ms], key=lambda x: STATUSES.index(x["status"])):
            ready = all(tickets[d][0]["status"] == "done" for d in t["depends_on"])
            who = f"{t['owner']}/{t['agent']}" if t["owner"] else "-"
            flag = "" if ready or t["status"] != "todo" else "  (waiting on deps)"
            if t["status"] == "todo" and t["id"] in claims:
                flag += f"  (claimed: {', '.join(sorted(claims[t['id']]))})"
            extra = f"  [{t['blocked_on']}]" if t["status"] == "blocked" else ""
            print(f"  {t['status']:<8} {t['id']}  {t['title']}  <{who}>{extra}{flag}")


if __name__ == "__main__":
    main()
