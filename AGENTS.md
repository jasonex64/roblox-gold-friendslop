# AGENTS.md

You are one of several AI agents (Claude Code and Codex) working for three humans, asynchronously.
Full process: `WORKFLOW.md`. Read it at the start of every session. This file is the short list of rules you must never break.

## Every session
1. `git pull`, then `python tools/board.py`. Non-zero exit → fix the tickets it names, nothing else.
2. Work only on one ticket: `docs/tickets/T-###.md`. Read all of it, especially the last Log entry.
3. Before ending your turn, even if unfinished, append a Log entry (format in WORKFLOW.md §4) and push your branch.

## Hard rules
- **Never push to `main`** except a commit that only creates or claims a ticket file (`T-###: claim`). Everything else goes through a branch `T-###-name` and a PR titled `T-###: <summary>`.
- **Every commit message starts with `T-###: `.**
- **Every change gets a Log entry.** If you touched any file, the ticket Log must say what changed (file paths), how you verified it, and where you stopped. Run `python tools/check_docs.py` before opening or updating a PR. It must exit 0.
- **Never invent a number.** Any gameplay/timing/limit/retry value must cite a `D-###` in `docs/DECISIONS.md` or an `EXP-###`. If none exists, ask in the Log, set `status: blocked`, `blocked_on: needs-number`.
- **Never edit `docs/DECISIONS.md`.** Humans only. Propose values in the Log.
- **Write `docs/experiments/EXP-###.md` before running any experiment.** Hypothesis and expected result first.
- **Fail loudly.** `error()`/`assert()` with a clear message. No swallowed `pcall`, no `or <default>` hiding a missing value, no silent `return`, no retry loops.
- **Build only what the acceptance criteria need.** No extra params, wrappers, config, or "future-proofing". Ideas go to `docs/NEXT_REVISION.md`, not into code.
- **Stay in scope.** Don't refactor, reformat, or "clean up" files the ticket doesn't need.
- **Don't mark acceptance criteria done without evidence** (test output or exact manual check result) in the Log.
- **Never set yourself or your own human as `reviewer`.**

## When unsure
Stop, write the question in the ticket Log, push. A logged question is always better than a guess.
