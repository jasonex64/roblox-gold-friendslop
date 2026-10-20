# Roadmap

Milestones are written by humans. A milestone is done when all its tickets are `done` and its review is merged with no blocking findings.

## M0 — Workflow + toolchain
Exit criteria: all three of us can clone, sync code into Studio, run tests, and run `tools/board.py` clean.
- T-001 Pick and set up the Studio <-> git sync and test runner

- T-003 Turn MVP design into M1 roadmap and tickets (draft planning; owner requested)

## M1 — Smallest playable manual shift (DRAFT: Gate A only)

Proposed outcome: enter the placeholder river camp, dig and carry dirt, manually sift and reveal a find, sell it, buy an approved existing tool upgrade, reach the bell, see the run result, and reset for another manual shift.

Source: docs/DESIGN.md sections 3, 5, 8, 13, 15 (Gate A), and applicable checks from sections 14-16. The original design is preserved unchanged. Its section 18 handoff is source material, not an instruction to implement all gates now.

This boundary is a proposal under T-003 Q10: Gate A is the document's first playable build, not its complete cooperative core-validation MVP (Gates A-C) or public-launch package (D-E). It does not yet prove the game's cooperative differentiator. The owner may revise this draft before implementation; the owners' answers now live verbatim in D-002..D-008; unanswered details remain open.

### Preconditions

- Finish M0 and its independent review before starting M1 implementation (WORKFLOW section 6); T-001 is still open. Drafting these tickets does not start M1.
- Review/merge T-003, then T-004 must resolve only the remaining Gate A scope/contract and skill-check questions and obtain the applicable human-authored numeric decisions in docs/DECISIONS.md. The attached design's proposed values are not approved decisions.
- No dates, team capacity, workstream owners, toolchain choices, or numeric defaults are invented. Unassigned ticket owners stay blank; T-004 is explicitly an owner decision task.

### Included, subject to T-004 approval

- Direct entry into the run place and placeholder river/camp/bank/buyer layout, as section 13 permits for validation.
- Starter loadout, manual dig/carry/sift/reveal, server-owned batch identity/outcomes, capacity handling, and mutually exclusive actions.
- Run-local sale ledger, cumulative Crew Haul, personal cash, and the owner-selected documented shovel/pan upgrade.
- Server-owned start/end, final sale of completed finds, specified disposal of unfinished material, honest results, and in-place reset.
- D-008 timing-based sifting, with success/miss/cancel rules and tuning still to be supplied; contextual inputs/HUD/guidance and the owner-approved Gate A device/first-time-player checks; report observations without claiming public-launch readiness.

### Dependency order and tickets

| Ticket | Player/owner outcome | Depends on |
|---|---|---|
| T-004 | Confirm the Gate A boundary and approve required decisions | T-003 |
| T-005 | Enter the run place with starter loadout and authoritative clock | T-001, T-004 |
| T-006 | Dig/carry valid batches without duplication or rerolls | T-005 |
| T-007 | Manually process batches into completed finds | T-006 |
| T-008 | Sell and buy the chosen temporary tool upgrade | T-007 |
| T-009 | Finish, settle run-local output, and reset | T-008 |
| T-010 | Use contextual controls, HUD, and first-run prompts | T-009 |
| T-011 | Produce Gate A playability and integrity evidence | T-010 |

T-004 is a human decision task. Each implementation ticket carries a source reference, data contract, exact checks, and a Numbers used section pointing to the unresolved inventory. No gameplay implementation begins with missing decisions; stop that part and log it under WORKFLOW.

### Exit criteria

- Every included ticket is done with independent evidence, and the M1 review is merged with zero open blocking findings.
- Using the approved player count, full shift duration, device/input matrix, and tuning, a fresh build completes the entire manual journey through an upgrade, bell, result, and restart (T-011 GATE-A-1).
- Rejected/forged actions, full inventory, cancellation, exact-end completion, repeated sale/purchase/result requests, and reset cannot create extra inventory/cash/haul; spending does not reduce cumulative haul (GATE-A-2).
- Applicable usability/timing checks use only human-approved thresholds; observed outcomes and open issues are recorded separately from design hypotheses (GATE-A-3).
- D-002..D-008 approve only the owners' words; the preserved Q/ND inventory marks later items deferred to Gate B+ planning and identifies the remaining Gate A subset/ND39; every implemented gameplay quantity traces to a human decision. This milestone neither claims multiplayer readiness nor permanent reward durability.

### Explicitly deferred design scope (no tickets created here)

- Gate B: cooperative admission/roster, shared sale shares, AFK eligibility, shared bin/funding and sluice. Gate C: hopper, remaining tool/machine tiers, night bank, final surge and the fuller replay decision flow. These remain in DESIGN.md, not silently removed from the game concept.
- Gate D: permanent classes/nodes, pets/eggs, discoveries/records, tokens and durable reward persistence. Gate E: lobby teleports/rejoin, entitlements/monetization, touch polish, launch instrumentation and reliability/performance matrix. Gate F: evidence-based expansion decisions.
- All P1/P2 candidates, combat/survival, paid randomness, crash-resume, external backend, procedural terrain and construction editors. No such feature is added to M1.

### Owner decisions recorded in this revision
D-002: shared crew success. D-003: personal wallets, even sale-value splits and voluntary group funding. D-004: relaxed mining with a late production rush; the night alternative is not selected. D-005: paid-power direction with no serious-competition requirement. D-006: rarities and retained class ownership with between-run swaps. D-007: personal cash. D-008: a timing minigame similar to dead by daylight skillchecks. The exact statements and source names are in DECISIONS.md; these summaries introduce no additional decision. Multiplayer funding, night alternatives, monetization and classes remain deferred to Gate B+ planning. Gate A implements only its approved slice and still needs skill-check rules/tuning.
