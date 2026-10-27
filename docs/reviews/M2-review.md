# M2-review

Reviewer: jason / claude-opus-5.5 (Claude; most M2 code was written with Codex)
Authors of this milestone: yukicide (T-019, T-020, T-021, T-022), jason (T-023, T-028)
Date: 2026-10-26
Commit reviewed: 7da9889 (main; includes later M3 work built on M2)

## Checklist
- [x] Every ticket's acceptance criteria re-verified by the reviewer (not just read from the Log): T-019, T-020, T-021, T-022, T-023 and T-028 were re-checked against current code and specs; all met. Where a later human decision changed a criterion, the current code matches that decision: D-043/D-044 replaced "Upgrades coming later", and D-044 made the hopper the only automatic bin-to-sluice path.
- [x] Tests run by the reviewer, output pasted below
- [x] Long-running behavior tested at the D-### player count and duration. Duration: the reviewer ran a full 600-second shift (D-024) through real remotes, solo (below). Player count: crews of up to 4 (D-032) are covered by T-022's four-client automated runs and the owner's four-player human shift through bell and replay (EXP-001). The reviewer's Studio MCP could only start solo Play sessions, so `tests/studio/GateB.luau` (2-4 clients) was not re-run.
- [x] Every gameplay literal traces to D-### or EXP-### (`python tools/numbers.py --strict` exits 0). M2 values are in `Config.luau` with D-032..D-036 citations.
- [x] No swallowed errors / silent fallbacks: no `pcall` in `src/`. The one quiet fallback, Settlement's `crewHaul == nil` path, is unreachable from production; it is listed as non-blocking.
- [x] No code beyond acceptance criteria: only small test-only leftovers, listed as non-blocking.
- [x] Docs match shipped behavior: README pointed to the stale October 22 handoff as current. Fixed by T-036 (PR #50); see M1-review.

## Test output
```
python tools/check_docs.py      -> check_docs OK
python tools/board.py           -> exit 0
python tools/numbers.py --strict -> numbers: 0 provisional value(s)
lune run scripts/check          -> unit: 123 passed, 0 failed ... ALL CHECKS PASSED

Studio, fresh solo Play of main 7a1decd (fixtures unchanged apart from the T-027/T-030 repairs merged in PR #47):
[server] boot ok
[CREW server] $200 sale -> four $50 wallets; four correct notifications; duplicate/forged requests rejected; purchase preserves haul
[CREW server] exact 60/70-second warning/pause; empty sale stays paused; real sale resumes seller before payout; odd dollar conserved
[CREW server] late/reconnected player blocked on production/shop/replay; departed sales retain $258 haul; unsold $19 discarded; remaining vote+departure releases replay and resets cash
[CREW server] PASS; one real avatar + three simulated recipients; live state restored
[BIN fixture] 1 real player(s): deposit -> teammate withdraw -> sift -> shared sale; identity/outcome/provenance preserved; wallets sum to $5
[BIN fixture] malformed/out-of-range/repeated/full/empty/cutoff requests safe; bell discards shared dirt without payment; unanimous replay clears bin and cash
[BIN fixture] PASS; live attributes and positions restored
[MACHINE fixture] 1 real avatar(s): capped final contribution built once; no haul spent; bin unchanged; Bucket dirt queued; nearby collection preserves provenance; only Backpack finds sold through crew shares; empty sale adds nothing
[MACHINE fixture] invalid/location/stale/cutoff requests rejected; bell destroys unfinished dirt without payment; replay clears wallets, funding, lanes and output
[MACHINE fixture] PASS; isolated fixture restored avatar attributes/positions
ServerStorage.Fixtures.GateB:6: GATE B fixture needs 2 to cap clients   (expected: solo session)
[T011 FULL] real shift started; duration=600; run=e51c0b0b-4f73-4331-9d29-df24b32db0b3
[T011 FULL] shop haul=95; wallet=45; upgrade verified; holding one unsold find and two raw batches
[T011 FULL] real bell PASS: prior shop haul preserved; unsold completed/raw/processing discarded without payment
```

## Blocking findings
<!-- real problems only. each becomes a ticket in this milestone -->
- None in M2 code. The stale handoff document affects both milestones and is tracked as T-036 (see M1-review).

## Non-blocking findings
<!-- copied into NEXT_REVISION.md, do not block -->
- `docs/ROADMAP.md` M2 list omits T-028; its "hopper, more tiers ... later work" line is now M3 work (human-owned file).
- `docs/DESIGN.md` §5/§6/§8/§12 still describe the bin as 20 × N, players loading the sluice from the bin, bin transfers refreshing activity, and same-run rejoin. DECISIONS D-032, D-033, D-036 and D-038 supersede these (DESIGN is kept verbatim on purpose).
- `Settlement.finish` falls back to summing ledgers when `crewHaul` is nil; only unit tests use it. Make `crewHaul` required.
- `Pure/Economy.sell` is only called from tests; production sells via `Crew.sale`.
- Hud messages `sluice_loaded`, `lanes_full`, `output_full` and `duplicate_batch` can no longer reach the client since D-036.
- The cash-shares-paused notice says "dig, sift or sell". Buying, contributing and quick transfer also resume shares (D-038).
- The in-game help panel does not mention the crew bin or sluice.
- No D-031 row in DECISIONS (numbering gap; nothing references it).

## Verdict
PASS. No blocking findings in M2. The shared docs finding is fixed by T-036 (PR #50).
