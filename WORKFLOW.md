# Workflow (MVP draft)

Source of truth for how humans and agents work in this repo. AGENTS.md will be distilled from this.
If this file and anything else disagree, this file wins until it is changed by a reviewed PR.

## 1. Where state lives

Everything is a file in git. No state lives in chat history, Discord, or an agent's memory.

| What | Where | Who writes it |
|---|---|---|
| Milestones / roadmap | `docs/ROADMAP.md` | humans |
| Work items | `docs/tickets/T-###.md` (one file per ticket) | humans create, agents update Log |
| Current board | output of `python tools/board.py` | generated, never hand-edited |
| Every number / threshold | `docs/DECISIONS.md` | humans only |
| Experiments | `docs/experiments/EXP-###.md` | agents, written BEFORE running |
| Milestone reviews | `docs/reviews/M#-review.md` | reviewer (not an author of that milestone's tickets) |
| Small / deferred stuff | `docs/NEXT_REVISION.md` | anyone, append-only |

## 2. Starting a session (every agent, every time)

1. `git pull`
2. Run `python tools/board.py`. If it exits non-zero, fix the reported ticket files first. Do nothing else.
3. Pick work: a ticket assigned to your human, or a `todo` ticket in the current milestone whose `depends_on` are all `done`.
4. Read that ticket fully, including its Log. The last Log entry tells you where the previous agent stopped.
5. Claim it: set `status: doing`, `owner`, `agent`, commit + push that one change alone. The push is the lock. If the push conflicts, someone else claimed it — pick another.

## 3. Doing the work

- Branch: `T-###-short-name`. One ticket per branch.
- Only build what the ticket's acceptance criteria need. No extra params, config, abstractions, or "future" hooks. Ideas go to `NEXT_REVISION.md`.
- No invented numbers. Any literal that affects gameplay, timing, economy, limits, or retries must cite a `D-###` or `EXP-###` in a comment. If none exists: stop that part, add a question to the ticket Log, set `status: blocked`, `blocked_on: needs-number`.
- Reason before experimenting. Write `EXP-###.md` (hypothesis, why, expected result, how measured) and commit it before running anything.
- Fail loudly. Use `error()` / `assert()` with a message naming what was wrong. Banned without a D-### that justifies it: `pcall` that swallows the error, `or <default>` covering a value that should exist, silent `return` on bad input, retry loops.
- Tests: every acceptance criterion maps to a test or a written manual check with exact steps and expected result.
- Long-running systems (sessions, saves, economy loops, timers) are tested with the player count and duration listed in the ticket. Those values come from `DECISIONS.md` like any other number.

## 4. Stopping a session (even mid-task)

Append to the ticket Log, then commit + push the branch:

```
### YYYY-MM-DD — <human> / <agent+model>
Done: <what changed, file paths>
Verified: <tests/checks run and result>
Stopped at: <exact next step>
Open questions: <or "none">
```

Unfinished work is fine. An unlogged session is not.

## 5. Finishing a ticket

1. All acceptance criteria checked, with evidence (test output or manual check result) in the Log.
2. Set `status: review`, `reviewer: <a different human>`. Open PR.
3. Reviewer merges or returns it. Then `status: done`.

## 6. Milestone review

When every ticket in a milestone is `done`, a human who authored none of them (or the fewest) runs a review using `docs/templates/review.md`, preferably with a different model than the authors used.

- **Blocking** findings = a real problem: wrong behavior, failed test, silent failure path, unsourced number, missing docs for shipped behavior. These become tickets in the same milestone.
- **Non-blocking** = style, nice-to-have, small improvements. These go to `NEXT_REVISION.md`. They never block.

Next milestone starts only after the review file is merged with zero open blocking findings.

## 7. What blocks change

Only: failing tests, wrong behavior, an unsourced number, a silent failure path, or a missing dependency. Nothing else. Preference disagreements go to `NEXT_REVISION.md` and get decided at the next milestone planning.

## 8. Agent habits to reject in review

- Defensive checks on values that are guaranteed by the caller
- Wrapper functions / modules used exactly once
- Parameters or options nobody passes
- Catching errors and logging instead of propagating
- Numbers that "seem reasonable"
- Rewriting files outside the ticket's scope
- Long explanatory comments restating the code
