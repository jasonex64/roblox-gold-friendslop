# Decisions

Every number, threshold, limit, timing, and rule an agent might otherwise guess lives here.
Humans add entries. Agents may propose one in a ticket Log or EXP conclusion; it isn't real until a human commits it here.
Never edit an entry's value in place — add a new entry that supersedes it.

| ID | Date | Decision / value | Source (who / EXP) | Supersedes |
|---|---|---|---|---|
| D-001 | 2026-10-19 | `main` is NOT branch-protected (free private repo can't enable it). Review is enforced by convention + `tools/check_docs.py` in CI, which flags undocumented pushes but cannot block them. Revisit before real game code lands. | jason | — |
| D-002 | 2026-10-19 | shared crew success. | yukicide and jason | — |
| D-003 | 2026-10-19 | everyone should have their personal wallet, and the sold items value should be split amongst them evenly. everyrone should be able to contribute to group purchases, such as automation | yukicide and jason | — |
| D-004 | 2026-10-19 | mix between relaxed mining and a production rush towards the end of the run. night should add another layer of complexity, whether it be wolves come out and u have to defend ur setup, or another farther bank opening up and having more valuable dirt to sift. | yukicide and jason | — |
| D-005 | 2026-10-19 | paid power should able to get ur tool upgrades, one time or permanent, as well as being able to buy classes or buy the in game premium currency. serious competition is not that intended, since there is a p2w aspect. | yukicide and jason | — |
| D-006 | 2026-10-19 | classes have different rarities, and getting a new class will not replace ur current one, you will have the ability to swap between any of the classes you own between runs. | yukicide and jason | — |
| D-007 | 2026-10-19 | personal cash | yukicide and jason | — |
| D-008 | 2026-10-19 | timing minigame similar to dead by daylight skillchecks | yukicide and jason | — |
| D-009 | 2026-10-21 | Toolchain: Rojo syncs `src/` into Studio; Lune runs Luau tests (`tests/run.luau`, zero dependencies); StyLua formats; Selene lints. Exact versions pinned in `rokit.toml`, installed with Rokit locally and by `scripts/ci-install.sh` in CI. Agents playtest through Roblox Studio's built-in MCP server. Git `main` is the source of truth, not any Studio place. | jason (transcribed from chat by claude-opus-5.5, T-001) | — |
| D-010 | 2026-10-21 | Upgrade to GitHub Pro and protect `main` (require PR, require `docs` and `luau` checks, require 1 approval). Nobody pushes to `main`; a ticket is claimed by pushing a `T-###-*` branch, which `tools/board.py` shows. Until protection is turned on, this is enforced by convention + CI. | jason (transcribed from chat by claude-opus-5.5, T-012) | D-001 |
| D-011 | 2026-10-21 | Agents may use the value `docs/DESIGN.md` proposes for a missing number, marked `PROVISIONAL DESIGN §N` in `src/shared/Config.luau`, so work is not blocked on humans. All gameplay numbers live in that one file, each cited. A milestone cannot close while any value is PROVISIONAL (`tools/numbers.py --strict`). | jason (transcribed from chat by claude-opus-5.5, T-012) | — |
| D-012 | 2026-10-21 | One PR per ticket: the reviewer sets `status: done` in the work PR before merging. Commits touching only `docs/NEXT_REVISION.md` need no Log entry. Ticket text above `## Log` is capped at 300 words for tickets not yet done (enforced by `tools/board.py` from T-013). | jason (transcribed from chat by claude-opus-5.5, T-012) | — |
| D-013 | 2026-10-21 | Digging requires the character to stand on a bank pad, with no proximity radius. Bank pads may exist at multiple locations and have differing dirt quality. | yukicide (transcribed from chat by Codex, T-006) | — |
| D-014 | 2026-10-21 | Sifting uses Dead by Daylight-style skill checks, easier and slower, with a perfect zone flanked by two good zones. Three checks occur per sift. Upgraded tools make the zones easier to hit. Perfect/good hits increase the sifted product's value; misses decrease it down to a minimum. Canceling a sift trashes its dirt, requiring more digging. Exact timing, widths, upgrade scaling, value adjustments and floor remain to be specified. | yukicide (transcribed from chat by Codex, T-007) | D-008 (refines) |
