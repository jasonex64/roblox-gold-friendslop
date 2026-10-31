# AGENTS.md

You are one of several AI agents (Claude Code and Codex) working for three humans, asynchronously.
This file is enough to do a session. `WORKFLOW.md` has the reasons and the human-side process; read it only when a rule here is unclear.

## Every session
1. `git checkout main && git pull`, then `python tools/board.py`. Non-zero exit → fix only the tickets it names.
2. Pick one ticket: assigned to your human, or `todo` with all `depends_on` done and not shown as `(claimed: ...)`. For the Gatekeeper pilot, first follow the session sequence in `docs/GATEKEEPER.md`; mapped work must satisfy both systems' eligibility and ownership checks.
3. Claim it: create branch `T-###-short-name` from main, set `status: doing`, `owner`, `agent` in the ticket, commit `T-###: claim`, push the branch. The pushed branch is the lock. If the branch name is taken, pick another ticket.
4. Read the whole ticket, especially the last Log entry. Do only what its acceptance criteria need.
5. Before ending your turn, even if unfinished, append a Log entry and push:
   ```
   ### YYYY-MM-DD — <human> / <agent+model>
   Done: <what changed, file paths>
   Verified: <commands run and their result>
   Stopped at: <exact next step>
   Open questions: <or "none">
   ```
6. Finished: every criterion ticked with evidence in the Log, `status: review`, `reviewer: <a different human>`. Open a PR titled `T-###: <summary>`. Never merge your own PR.

## Gatekeeper pilot
- Git remains authoritative for implementation, decisions, evidence and review. Gatekeeper coordinates accepted Features and short progress updates. Existing unmapped tickets keep the normal workflow.
- Before working on a mapped ticket, read `docs/GATEKEEPER.md`. Resume with `my_work`, read `last_outcome` and notices, and reconcile the returned branch with the ticket's pushed branch. An expired claim never authorizes taking over another person's branch.
- First pilot: one Feature maps to one approved ticket via optional `gatekeeper_feature` frontmatter. No invented Feature IDs, bulk migration or automatic status synchronization. A Feature does not override ticket dependencies, scope or numeric approvals.
- Post Feature steps with `add_tasks` before coding; after each push use `report_progress`. Keep detailed verification in the ticket Log. Never commit credentials or claim tokens.
- `complete_feature` submits for human review; it does not mark the Git ticket done. CI and independent review remain required. Read the runbook for outages, release, already-built Features and Verify/Send back.

## Reviewing someone else's PR (when your human asks)
Re-run the gates, re-check each ticked criterion yourself, confirm the Log matches the diff. If OK: append a Log entry, set `status: done` and `reviewer: <your human>` on that PR's branch, push. Your human merges. If not OK: list blocking findings in a PR comment; only failing tests, wrong behavior, an uncited number, a silent failure path, or a missing dependency block.

## Gates (all must pass before opening or updating a PR)
- `python tools/check_docs.py`
- `python tools/board.py`
- `python tools/numbers.py`
- `lune run scripts/check` (ends with `ALL CHECKS PASSED`)

## Hard rules
- **Never push to `main`.** Everything goes through a `T-###-*` branch and a PR.
- **Every commit message starts with `T-###: `.**
- **Every change gets a Log entry** in the same PR (edits to only your own ticket file or `docs/NEXT_REVISION.md` are exempt).
- **Numbers live in `src/shared/Config.luau`, one per line, each cited.** `-- D-###` (human-approved) or `-- EXP-###`. If neither exists, use the value `docs/DESIGN.md` proposes and mark it `-- PROVISIONAL DESIGN §N`. If DESIGN.md has no value either, ask in the Log and set `status: blocked`, `blocked_on: needs-number`. Never put a gameplay number anywhere else.
- **`docs/DECISIONS.md` is human decisions only.** You may append a row only to transcribe a decision a human gave you explicitly; the Source column names that human and says "transcribed".
- **Write `docs/experiments/EXP-###.md` before running any experiment.** Hypothesis and expected result first.
- **Fail loudly.** `error()`/`assert()` with a clear message. No swallowed `pcall`, no `or <default>` hiding a missing value, no silent `return`, no retry loops.
- **Build only what the acceptance criteria need.** No extra params, wrappers, config, or "future-proofing". Ideas go to `docs/NEXT_REVISION.md`.
- **Stay in scope.** Don't refactor, reformat, or "clean up" files the ticket doesn't need.
- **Don't tick a criterion without evidence** (test output or exact manual check result) in the Log.
- **Never set yourself or your own human as `reviewer` of a ticket your human owns.**

## Roblox (code, Studio, testing)
- Code lives in `src/` and reaches Studio through Rojo (`rojo serve`). Edit files only. Never edit Rojo-synced scripts inside Studio or through the Studio MCP `multi_edit` tool: Rojo overwrites them.
- Use the Studio MCP to verify, not to author: `start_stop_play`, `get_console_output`, `execute_luau`, `inspect_instance`, `search_game_tree`, `screen_capture`. Paste the console lines you relied on into the Log.
- Game logic goes in `src/shared/Pure/`: no Roblox APIs, no `require`, no `math.random`, no `os.time`. Pass randomness, time, and config values in. Each module gets `tests/unit/<Name>.spec.luau`.
- `--!strict` at the top of every `.luau` file. Server is authoritative; validate every RemoteEvent argument on the server.
- Non-script content (maps, models, UI) is built from code when possible, otherwise saved as `.rbxm` in `assets/` and mapped in `default.project.json`. Content that only exists in someone's Studio does not exist.
- Unsure about a Roblox API? Look it up (Studio MCP `http_get` on create.roblox.com or its `skill` tool). Never guess API names.

## When unsure
Stop, write the question in the ticket Log, push. A logged question is always better than a guess.
