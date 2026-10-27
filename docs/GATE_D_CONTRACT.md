# Gate D foundation handoff

This is the T-037 implementation contract for independent preparation, based on
DESIGN §§6–7, 12 and 15. It does not accept Gate C or enable persistent rewards.
Yukicide requested parallel assignments after skipping the Gate C playtests.
T-034 stays incomplete; PR #52 contains that evidence. No new D-### tuning
approval is inferred. Existing decisions override conflicting DESIGN text,
especially D-023 shop-only haul and discard of unsold finds.

## First parallel pair

- **yukicide / T-038:** pure reward calculation and its Config inputs.
- **jason / T-039:** profile state, durable storage and settlement application.
- Each reviews the other's implementation. Both start only after T-037 is
  reviewed, marked done and merged. Assigned todo tickets are not claims;
  each human's agent follows the normal branch/commit/push claim flow.
- T-040 wires them together later. No foundation ticket edits live entrypoints,
  Session, Shift, existing economy/production modules or client screens.

## Shared data contract

Implement shared Luau types in T-039's new src/shared/ProgressionTypes.luau.
T-038 can implement from the field names below without importing that file;
pure modules have no require calls. Changes to these fields require updating
this document before the dependent integration work.

The server supplies an immutable final run snapshot:
runId (nonempty string), rulesVersion (nonempty string), crewSize (locked
admission size), crewHaul (whole nonnegative sold value), assisted (boolean),
and participants keyed by user ID. Each participant contains activeSeconds
(nonnegative server-measured duration) and discoveries (set of known find IDs
eligible for that participant at reveal). Never accept balances, activity,
find IDs or reward claims from the client.

T-038 returns one manifest per participant:
runId, userId, rulesVersion, crewSize, crewHaul, assisted, eligible (boolean),
claimTokens (nonnegative integer), completionDelta (zero or one), discoveries
(set), and recordCandidate (the crew score and its crew-size/assistance/version
bucket, only for eligible completion). Grant identity is the tuple
(runId, userId); rulesVersion describes the payload, never a second grant key.
Ineligible participants receive no tokens, completion increment or record;
their independently earned discoveries may still be committed.

Token formula and eligibility come from DESIGN §7 and are provisional until
human approval. Gameplay numbers live only in Config with PROVISIONAL DESIGN
citations. T-038 owns those additions and matching ValidateConfig changes.
No grants from remaining cash, unsold inventory or purchases. Do not change
the existing Pure/Settlement module's run-local semantics.

For this first slice, manifests do not award pets, eggs or class ownership.
Those require follow-up tickets before Gate D completion; do not claim the
entire permanent loop is implemented by these foundations.

## Storage and application

T-039 defines a versioned profile with tokens, completed-run count,
discoveries, records and applied-grant identities. Persist no Run Cash,
temporary tool/machine tiers or carried inventory as permanent progression.
Create defaults only after a successful read confirms no existing profile.
Invalid, unsupported or failed loads must be explicit failures, never a reset.

Expose storage-independent operations for loading a profile, durably storing
an immutable manifest, listing a user's pending manifests and applying one
manifest atomically. Define concrete signatures in T-039's Log and exported
types; T-040 is their sole initial gameplay caller. Return explicit
pending/saved/alreadyApplied/failure outcomes rather than success-shaped defaults.

Persist a recoverable manifest before announcing rewards as saved. A manifest
must remain discoverable for its recipient after process restart, including
if the process stops between storing it and indexing pending work. A duplicate
identity with conflicting content fails loudly. Apply the profile delta and
its deduplication marker atomically; acknowledge pending work only after that
write succeeds. Replays, reconnects and competing callers must not double grant.
Prevent stale profile snapshots from overwriting newer progress. Document
retention/growth limitations of grant markers; never prune away deduplication
safety merely to bound the record.

Use an injected store/clock for deterministic tests and a Roblox adapter behind
the same boundary. Consult current official Roblox documentation when
implementing the adapter. No production datastore writes or enabling Studio
API access under this planning task. Any retry/backoff policy must be explicit,
bounded and reconciled with AGENTS.md's no-retry-loops rule before implementation;
test failure reporting and explicit recovery without an implicit retry loop.

## Ownership and later integration

T-038: new Pure/RunRewards.luau, tests/unit/RunRewards.spec.luau,
Config reward section, ValidateConfig and its test only.
T-039: new Pure/Profile.luau, new server/Progression directory,
ProgressionTypes.luau and new profile/storage tests only.
Use separate tests discovered by the existing runner; coordinate first if a
shared runner or scripts/check edit is necessary. Neither track edits the
other's ticket, Config section, source or tests.

T-040 (yukicide, reviewed by jason) owns Session/Shift/server entrypoint wiring,
activity/reveal collection, results UI and persistent status messages after
both foundations complete review and merge. D-047 resolves the Gate C
disposition by owner waiver, not a passed test. T-040 remains unclaimed; the
owner explicitly said not to start it under this request.
It must not display a reward as saved while storage is pending or failed.
Synthetic/fake-store tests are technical evidence, never human playtest evidence.

## Later Gate D work

After foundation integration, plan class ownership/nodes and pet/egg progression
as separate tracks with agreed modifier and profile-mutation interfaces.
Resolve D-006 class rarity versus DESIGN's no-rarity default first.
Then add discovery/record browsing and a Gate D validation/exit ticket.
Do not reserve IDs or silently approve tuning for those later features here.

