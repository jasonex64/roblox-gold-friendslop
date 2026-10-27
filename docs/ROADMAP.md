# Roadmap

Milestones are written by humans. A milestone is done when all its tickets are `done` and its review is merged with no blocking findings.

## M0 — Workflow + toolchain
Exit criteria: all three of us can clone, sync code into Studio, run tests, and run `tools/board.py` clean.
- T-001 Pick and set up the Studio <-> git sync and test runner

- T-003 Turn MVP design into M1 roadmap and tickets (draft planning; owner requested)
- T-012 Unblock async agent work in the workflow rules
- T-013 Split M1 so several agents can work in parallel

## M1 — Smallest playable manual shift (DRAFT: Gate A only)

Proposed outcome: enter the placeholder river camp, dig and carry dirt, manually sift and reveal a find, sell it, buy an approved existing tool upgrade, reach the bell, see the run result, and reset for another manual shift.

Source: docs/DESIGN.md sections 3, 5, 8, 13, 15 (Gate A), and applicable checks from sections 14-16. The original design is preserved unchanged. Its section 18 handoff is source material, not an instruction to implement all gates now.

This boundary is a proposal under T-003 Q10: Gate A is the document's first playable build, not its complete cooperative core-validation MVP (Gates A-C) or public-launch package (D-E). It does not yet prove the game's cooperative differentiator. The owner may revise this draft before implementation; the owners' answers now live verbatim in D-002..D-008; unanswered details remain open.

### Preconditions

- M0 done and reviewed (T-001, T-012, T-013).
- Implementation does not wait on T-004: missing numbers use DESIGN.md's proposal marked PROVISIONAL (D-011). T-004 must finish before M1 closes (`numbers.py --strict`).

### Included (numbers PROVISIONAL until T-004)

- Direct entry into the run place and placeholder river/camp/bank/buyer layout, as section 13 permits for validation.
- Starter loadout, manual dig/carry/sift/reveal, server-owned batch identity/outcomes, capacity handling, and mutually exclusive actions.
- Run-local sale ledger, cumulative Crew Haul, personal cash, and the owner-selected documented shovel/pan upgrade.
- Server-owned start/end, final sale of completed finds, specified disposal of unfinished material, honest results, and in-place reset.
- D-008 timing-based sifting, with success/miss/cancel rules and tuning still to be supplied; contextual inputs/HUD/guidance and the owner-approved Gate A device/first-time-player checks; report observations without claiming public-launch readiness.

### Dependency order and tickets

Pure-logic tickets (T-014..T-017) need only T-001, so up to four agents can work at once. Server wiring tickets consume them.

| Ticket | Outcome | Depends on |
|---|---|---|
| T-004 | Humans approve scope, skill-check rules, provisional numbers | T-003 |
| T-014 | Pure batch rules | T-001 |
| T-015 | Pure skill-check grading | T-001 |
| T-016 | Pure ledger (sell, buy, haul) | T-001 |
| T-017 | Pure run state machine | T-001 |
| T-005 | Run place and server session | T-001, T-017 |
| T-006 | Digging and carried batches | T-005, T-014 |
| T-007 | Sifting with skill check | T-006, T-015 |
| T-008 | Selling and the tool purchase | T-005, T-014, T-016 |
| T-009 | End of shift and replay | T-008, T-017 |
| T-010 | Controls and HUD | T-007, T-009 |
| T-011 | Gate A validation | T-004, T-010 |

### Exit criteria

- Every included ticket is done with independent evidence, `python tools/numbers.py --strict` exits 0, and the M1 review is merged with zero open blocking findings.
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

## ART — Art pass (after Gate A, optional tooling)
Starts only after T-011. Nothing in M0 or M1 depends on it.
- T-018 Add the Blender pipeline for the art pass

## M2 — Gate B cooperative prototype

Owner authorized Gate B planning and the shared-crew/shop-payout implementation on 2026-10-23.
Outcome: one crew runs a shared shift, divides shop proceeds into personal wallets,
passes dirt through a shared bin, and voluntarily funds one basic sluice.
Keep the accepted Gate A loop and D-023 shop-only payment; unsold items are discarded
at the bell. Earlier roadmap/design auto-sale text is superseded by D-023.

| Ticket | Outcome | Depends on |
|---|---|---|
| T-019 | Shared crew shift and shop-sale payouts | T-011 (merged and accepted by owner) |
| T-020 | Shared camp dirt bin | T-019 |
| T-023 | Pure sluice rules: fund, load, process, output | T-001 |
| T-021 | Crew-funded basic sluice | T-019, T-020, T-023 |
| T-022 | Gate B cooperative validation and continue/revise decision | T-019, T-020, T-021 |

Exit: human-observed solo/crew runs show whether cooperation helps; sale/contribution,
inventory, cutoff, leave and replay checks pass; tuning is approved and all gates pass.
Admission, money and replay prototype details belong to T-019's recorded decisions.
Existing Features cards provide context, not silent replacements for later human decisions.
Full lobby/teleports, hopper, more tiers, night/rush, permanent rewards, pets, classes,
monetization and art remain separate later work. T-018 is deferred and does not block M2.

## Later — shared-bin upgrades
- T-024 Upgrade shared camp dirt bin capacity (depends on T-020). Explicitly deferred by owner under D-034; not a Gate B exit requirement.



## M3 — Gate C complete shift

Planned by T-029 on 2026-10-24. DESIGN §15 Gate C: hopper, remaining shovel and pan tiers,
night bank, final surge and replay results. Gate C answers "does the ten-minute structure
produce useful decisions and a desire to retry?" Wiring waits on the T-022 Gate B
continue/revise decision; T-025 and T-026 are pure prep that is already merged.

| Ticket | Outcome | Depends on | Server/client files |
|---|---|---|---|
| T-025 | Pure shift timeline (done) | T-001 | new pure module only |
| T-026 | Pure contribution credit (done) | T-001 | new pure module only |
| T-027 | Results-screen contributions (PR #35) | T-021, T-026 | Session, Digging, Sifting, Economy, Machinery, Shift, client results |
| T-030 | Night bank and final rush | T-022, T-025 | Camp, Digging, Sifting, Shift, Interaction, client HUD, Config |
| T-031 | Remaining shovel and pan tiers | T-022, T-030 | Economy, Digging, Sifting, client shop, Config |
| T-032 | Sluice tier two and lane rush speed | T-022, T-025 | Machine, Machinery, SluicePanel, Config |
| T-033 | Hopper attachment | T-022, T-032 | Machine, Bin, Machinery, SharedBin, SluicePanel, Config |
| T-034 | Gate C human validation and decision | T-030..T-033 (and T-027 merged) | docs and tests only |

Parallel split: one person takes the clock track (T-030, then T-031), the other the machine
track (T-032, then T-033). The tracks share only Config and the client HUD file, so keep
those edits small and merge often. T-030 owns manual rush speed; T-032 owns rush speed for
sluice lanes. Design decisions D-039..D-044 (2026-10-24) settle the rich bank distance, rush
sifting, shovel and pan tiers, sluice tier two and the hopper, so the tickets need no new numbers.

Exit: humans play full shifts, an approved EXP records when crews buy tools and machines
and use the night bank and rush, and a recorded continue/revise decision closes the gate.
Gate D (classes, pets, discovery book, saved rewards) stays out of M3.

## M4 — Gate D foundations (parallel preparation)

T-037 plans the next assignments at yukicide's request after skipping Gate C
playtests. This does not mark T-034 passed or close Gate C. The detailed handoff
is [GATE_D_CONTRACT.md](GATE_D_CONTRACT.md); no gameplay tuning is newly approved.

| Ticket | Owner / reviewer | Outcome | Depends on | Exclusive source scope |
|---|---|---|---|---|
| T-037 | yukicide / jason | Parallel plan and contract | T-031, T-032, T-033 | Docs/tickets only |
| T-038 | yukicide / jason | Pure reward manifests | T-037 | New RunRewards, reward Config section, ValidateConfig |
| T-039 | jason / yukicide | Profile and durable reward storage | T-037 | New Profile, ProgressionTypes and server/Progression |
| T-040 | yukicide / jason | Shift integration and saved/pending results | T-038, T-039 | Session/Shift, server entrypoint, activity/reveal hooks, client results |

After T-037 is reviewed and merged, T-038 and T-039 can be claimed concurrently.
Neither edits live gameplay wiring or the other's files. Cross-review the two
foundation PRs, then integrate through T-040. D-047 records the owner's decision
to proceed with Gate C playtests skipped and waives T-034 as a dependency.
Skipped tests remain unvalidated. T-040 is unclaimed and must not start under
the current request.

This is the first Gate D slice, not the complete milestone. Classes/nodes and
pets/eggs follow as separate planned tracks, then discovery/record browsing and
Gate D validation. Class rarity conflicts (D-006 versus DESIGN), remaining
numeric approvals and validation scope must be settled in those later tickets.

### Next parallel pair after PR #59 (T-041)

| Owner | Ticket | Deliverable | Prerequisite | Exclusive source scope |
|---|---|---|---|---|
| yukicide | T-040 | Earned rewards survive replay/reload; results show saved/pending/failed truthfully | T-039 reviewed and done; normal claim | Session/Shift, server entrypoint, activity/reveal hooks and client results |
| jason | T-042 | Pure class/pet rate modifier calculations | T-041 reviewed and merged; normal claim | New Pure/Modifiers and its test; dedicated modifier Config section and ValidateConfig/test |

First, jason should review the merged PR #59 collision fix and record findings;
its merge did not itself close T-039. Preserve independent review evidence and
the different-human reviewer rule when closing the original storage ticket.
T-040 remains waiting on T-039 until that closeout reaches main. This assignment
does not claim or start either implementation in this planning turn.

The two tracks do not import or wire each other's changes. T-040 uses existing
RunRewards/Progression interfaces and must coordinate any needed Profile or
storage-interface fixes before editing them. T-042 accepts numeric bonuses and
eligibility supplied by a future server caller; it does not create classes or
pets, change profile schemas, or touch Digging/Sifting/Machinery/client files.
T-040 does not edit modifier Config/ValidateConfig. Any required shared-file
change must be coordinated before work, not resolved by overwriting a teammate.

After these tracks, plan class ownership/nodes and pet/egg progression with a
shared profile-mutation contract. D-006's rarity question stays deferred to that
planning; this pure rate module makes no acquisition or rarity decisions.
