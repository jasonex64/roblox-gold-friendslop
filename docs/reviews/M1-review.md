# M1-review

Reviewer: jason / claude-opus-5.5 (Claude; M1 code was written with Codex)
Authors of this milestone: yukicide (T-004..T-011, T-014..T-017); jason authored none
Date: 2026-10-26
Commit reviewed: 7da9889 (main; includes later M2/M3 work built on M1)

## Checklist
- [x] Every ticket's acceptance criteria re-verified by the reviewer (not just read from the Log): all 12 tickets were re-checked against current code earlier today; see each ticket's "jason / claude-opus-5.5 (review)" Log entry (PR #47). Criteria later changed by humans are checked against the newer decision: D-015/D-016 grading, D-023 no sale at the bell, D-027 one-time help, D-045 deferred find sound.
- [x] Tests run by the reviewer, output pasted below
- [x] Long-running behavior tested at the D-### player count and duration: Gate A is solo (D-025) with a 600-second shift (D-024). The reviewer ran the full-duration real-remote journey (`tests/studio/FullShift.client.luau`) solo on main (below).
- [x] Every gameplay literal traces to D-### or EXP-### (`python tools/numbers.py --strict` exits 0). M1 code has no uncited timing, economy or limit literals; Camp station positions are placeholder layout geometry.
- [x] No swallowed errors / silent fallbacks: no `pcall`, no `or <default>`, no silent return on invalid state in M1 code. Misleading but harmless feedback paths are listed as non-blocking.
- [x] No code beyond acceptance criteria: several leftovers, listed as non-blocking.
- [x] Docs match shipped behavior. One blocking finding (below), fixed by T-036.

## Test output
```
python tools/check_docs.py      -> check_docs OK
python tools/board.py           -> exit 0
python tools/numbers.py --strict -> numbers: 0 provisional value(s)
lune run scripts/check          -> unit: 123 passed, 0 failed ... ALL CHECKS PASSED

Studio, solo Play of main (fixtures as repaired in PR #47; per-ticket runs logged in the T-005..T-011 review entries):
[T011 DIG-2/3] real avatar death/reset preserves batch identities, opening count, completed finds, money/upgrade and SAME starter Tool instances
[T011 DIG-1/2/3] forged/rate/range/phase/full requests reject; duration/cancel correct; five immutable opening batches; sixth fixture batch retains distinct source/quality; production inventory untouched
[SIFT fixtures] all assertions passed; live attributes restored
[ECON fixtures] all assertions passed; live attributes restored
[UX-1/2 fixture] forged/closed/wrong-location/empty/full/poor/already-owned requests reject; single sale/purchase correct; busy/cancel and server guidance correct; live attributes restored
[END fixtures] all assertions passed; live attributes and position restored
[UX-2 layout] 2376x1153: timer/phase/haul/cash/bucket/backpack match server; persistent reminder absent; visible text fits and 3 buttons meet 44px targets

Full 600-second shift, real remotes and wall-clock time, main 7a1decd:
[T011 FULL] real shift started; duration=600; run=e51c0b0b-4f73-4331-9d29-df24b32db0b3
[T011 FULL] shop haul=95; wallet=45; upgrade verified; holding one unsold find and two raw batches
[T011 FULL] real bell PASS: prior shop haul preserved; unsold completed/raw/processing discarded without payment
```

## Blocking findings
<!-- real problems only. each becomes a ticket in this milestone -->
- `docs/HANDOFF.md` presented the October 22 state as current, and the README called it "the latest development summary". It said T-011 was outstanding, 68 tests, 34 provisional values, and gave pre-D-040 sweep timings. Docs did not match shipped behavior. Ticket T-036 (PR #50) marks it as a historical snapshot and repoints the README.

## Non-blocking findings
<!-- copied into NEXT_REVISION.md, do not block -->
- Pressing cancel while idle says "Action cancelled. Incomplete sift dirt is discarded." `Dig.cancel` always returns `cancelled`.
- A dead or unarmed player who tries to dig mid-shift gets `wrong_phase` ("Production is closed").
- Rejected shop/sift actions sent through ActionRequest reach the client twice, once per remote. At the bell, `sifting.cancel` re-runs after Settlement and flashes an "idle" toast.
- Unused code: `Batch.cancel`/`Batch.retry` and the `active` flag (contradicted by D-014/D-015); the SkillCheck `success` grade without `perfectWidth`; `Sifting` `controller.rate` is always 1; `Dig` `limits.digInterval` initial value is always overwritten; the `ProductionAllowed` BindableFunction has no caller; player attributes DirtPerBatch, BucketBatches, OutputCapacity and SiftSeconds are never read.
- Each empty sale with a new GUID adds an entry to `ledger.requests` for the shift.
- `docs/ROADMAP.md` (human-owned) still calls M1 a draft with provisional numbers and missing skill-check rules, and lists shipped Gate C features as deferred.

## Verdict
PASS once T-036 (PR #50) is merged. That is the only blocking finding, and it is docs-only.
