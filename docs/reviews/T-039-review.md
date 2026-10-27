# T-039 independent review — 2026-10-26

Reviewed main 876bc53 for yukicide. PR #56 is already merged; its T-039 source
and tests match reviewed main. This is a review finding, not a closeout.

## Blocking: conflicting reward manifests can silently compare equal

Pure/Profile.fingerprint stores only a 32-bit FNV-1a fingerprint, and
Profile.store compares it as proof that two payloads are identical. Two actual
RunRewards outputs for the same run-review/user 42, solo, rulesVersion gate-c,
480 active seconds, Gold Flakes discovery, and haul 17950 versus 61116 both hash
to 6c42859e. Both validate. While pending, the second returns alreadyPending;
after application it returns alreadyApplied. The differing record is silently
ignored instead of raising the conflict required by criterion 3 and the contract.
The progression wrapper maps these into successful pending/alreadyApplied results.

This does not duplicate a grant; it hides conflicting content and can lose the
intended record correction without exposing the underlying settlement bug.
Use unambiguous canonical payload comparison for pending and applied grants,
or another representation that does not treat a 32-bit hash as exact equality.
Canonical encoding must also delimit/escape arbitrary string fields safely.
Retain idempotency and document storage growth/migration implications. Add this
collision as a regression test both before and after application.

Reproduction: save the following as build/t039-review.luau and run
`lune run build/t039-review`. It uses no Studio or real datastore.

```luau
local Profile = require('../src/shared/Pure/Profile')
local Rewards = require('../src/shared/Pure/RunRewards')
local Config = require('../src/shared/Config')
local function manifest(haul)
    return Rewards.build({runId='run-review',rulesVersion='gate-c',crewSize=1,crewHaul=haul,assisted=false,participants={[42]={activeSeconds=480,discoveries={['Gold Flakes']=true}}}},Config)[42]
end
local a,b=manifest(17950),manifest(61116)
Profile.checkManifest(a)
Profile.checkManifest(b)
print('fingerprints',Profile.fingerprint(a),Profile.fingerprint(b))
local pending=Profile.store(Profile.new(42),a)
print('pending conflicting payload',select(2,Profile.store(pending,b)))
local applied=Profile.apply(pending,a.runId)
print('applied conflicting payload',select(2,Profile.store(applied,b)))
print('stored record',applied.records['1|unassisted|gate-c'],'conflicting requested record',b.recordCandidate.crewHaul)
assert(select(2,Profile.store(applied,b))=='conflict','T039 REVIEW: conflicting reward silently accepted')
```

Observed:

```text
fingerprints 6c42859e 6c42859e
pending conflicting payload alreadyPending
applied conflicting payload alreadyApplied
stored record 17950 conflicting requested record 61116
T039 REVIEW: conflicting reward silently accepted
```

## Other acceptance checks

Versioned Profile/Manifest types and ProgressionTypes export match the current
numeric-userId and crewHaul contract. Decode fails explicitly for invalid or
unsupported stored profiles. The injected adapter exposes read/update, reports
pcall failures, and writes pending manifests and applied deltas inside one
recipient profile key. Pending recovery does not require a separate index.
Update transforms use current state rather than caller snapshots; existing tests
cover interleaved writers, missing profiles, failed writes, lost acknowledgement,
restart and RunRewards compatibility. The documented live evidence is limited to
an unpublished-place adapter failure and in-memory runtime checks; no live saved
progress is claimed. Marker growth is documented, but the fingerprint equality
assumption fails the explicit conflicting-payload requirement.

The earlier log/header claim that a failed store means nothing is pending, or an
unacknowledged apply leaves pending work, is too strong: the existing lost-ack
tests correctly demonstrate that either write may already have committed. Clarify
that the outcome is unknown until read/recovery; this is a documentation issue
in addition to the blocking equality defect.

Checked adapter transform semantics against the official
[GlobalDataStore documentation](https://create.roblox.com/docs/reference/engine/classes/GlobalDataStore).

All four existing gates pass: check_docs, online board, numbers (four provisional
reward values), scripts/check (145 passed, zero failed, ALL CHECKS PASSED).
The additional focused regression fails as shown above. T-039 stays review with
criterion 3 unticked; T-040 stays todo/waiting on T-039 and is not started.
