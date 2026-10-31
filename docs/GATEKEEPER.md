# Gatekeeper pilot

## Scope and authority

This pilot adds Feature intake and coordination to the existing workflow after this workflow PR is reviewed and merged. Git remains authoritative for code, acceptance criteria, dependencies, human decisions, test evidence and independent review. Gatekeeper records accepted Features, coordination claims, small task lists and submission for human verification. Its tools do not build code, run CI, merge PRs or replace the repository's rules.

Start with one Feature and one approved `T-###` ticket. Other tickets remain on the existing Git workflow. Do not bulk-import the backlog or equate an empty ready queue with a finished project. A wider migration or replacement of branch locks requires a separate reviewed workflow change.

## Set up the first trial

1. Each participating agent must have a working Gatekeeper connection in its client. Keep credentials in private client configuration, never in the repo, Logs or PRs. The observed tools provide no identity-management operation: confirm the credential-to-agent identity with the server administrator before using multiple clients concurrently. Do not assume the same token creates separate agents.
2. Read `my_work` and `list_ready_features`. If the queue is empty, record that and continue only separately authorized unmapped Git work. If tools are unavailable, report the connection problem; do not create a second queue or invent an assignment.
3. Read the selected Feature with `get_feature`, including `last_outcome`, tasks, history, open decisions and notices. Compare it with current code, tickets, decisions and PRs. Ready in Gatekeeper does not establish that Git dependencies are done.
4. Under human-authorized planning, map the exact Feature key into the matching ticket's optional `gatekeeper_feature` frontmatter. Leave it empty or absent for unmapped tickets. Mapping changes go through the normal Git PR process. Search tickets for the key before adding a mapping; the first pilot requires exactly one ticket for that Feature. If the Feature spans several tickets, narrow the trial through human planning first.
5. Record the mapping rationale and any existing implementation/PR in the ticket Log. Confirm acceptance criteria agree. A new Feature requires an approved ticket before implementation; an existing ticket must not silently gain scope. `board.py` accepts optional frontmatter but does not validate Gatekeeper identities, mappings or live claims; these reconciliation checks are manual in this pilot.

## Session and ownership sequence

1. Refresh Git and run the board as usual. Read `my_work` before claiming anything. If it returns a claim, inspect its Feature and mapped ticket and establish whether this is your work before resuming. Otherwise choose an approved mapped Feature from the ready list. Prefer `claim_feature` with the exact mapped key; do not use `claim_next_feature` to accidentally reserve unmapped work.
2. Read the whole ticket and latest Log, Feature `last_outcome`, and notices returned by every call. Compare scope, dependencies, owner and remote branches. If a notice changes acceptance criteria, stop the affected part and reconcile the Git ticket through authorized planning. A notice or proposed answer is not a human-approved gameplay number.
3. Confirm Git eligibility and absence of a conflicting branch, then claim the Feature. Keep the `claim_token` private; recover it through `my_work` on a later session instead of storing it in Git. A successful Gatekeeper claim alone does not reserve Git files.
4. Inspect the returned branch before editing. It must agree with the ticket's `T-###-*` branch and existing ownership. For a fresh claim, create and push that compatible branch using the normal claim commit. If the returned branch is incompatible or belongs to another person, do not create a competing branch or overwrite it: log the mismatch and release the newly acquired claim with a reason. A human/server administrator must resolve the branch mapping. The inspected API exposes no explicit branch-renaming tool; do not assume `report_progress(branch=...)` authorizes an override.
5. Before coding, inspect existing tasks and use `add_tasks` only for missing Feature implementation steps. Include the ticket ID in task detail to make the mapping visible. Do not duplicate tasks on resume or add unrelated tooling/refactors. Required tests remain part of implementing and verifying those steps, even though separate test-scaffolding tasks are excluded by Gatekeeper.
6. Edit local files, sync through Rojo, and verify with the existing checks and Studio process. After each push, call `report_progress` with the established branch and a short result/next step. Read notices. Mark a task done only with evidence in the Git Log; dropping a task requires a reason and cannot waive an acceptance criterion without human-approved scope revision.

### Expiry, failure and release

The server documents one active claim per agent and expiry after 24 hours without a call. Do not schedule polling merely to keep a claim. At session resumption, check `my_work` again; never assume an old token is valid.

- **Expired or reassigned:** Git branches and commits still exist. Inspect `last_outcome`, current Feature ownership and Git branches. Reclaim only when the Feature is available and the Git ownership/handoff agrees; otherwise stop mapped implementation and coordinate the handoff. Expiry never grants permission to overwrite another branch.
- **Service outage:** preserve changes, append a Git Log entry and push. Record the unsent update and exact next step. Do not begin more mapped implementation until the service returns and ownership is rechecked. Unmapped authorized work can continue. Keep CI independent of Gatekeeper uptime.
- **Ambiguous mutation result:** re-read `my_work`/`get_feature` before retrying a claim, task creation or completion. Do not blindly duplicate a write after a timeout.
- **Cannot finish:** log and push the handoff first, then `release_feature` with a concise reason. State that the Git branch still exists and name it in the reason/Log. Release does not clear the Git lock or delete work. If genuinely blocked, set the ticket's existing `blocked`/`blocked_on` fields; never set it done merely because the claim ended.

## Review and reconciliation

| Gatekeeper event | Git action |
|---|---|
| Claimed, implementing | Ticket `doing`, compatible pushed branch, acceptance criteria unchanged |
| Tasks done or justified drops; `complete_feature` with PR link | All criteria evidenced, four gates pass, ticket `review`, different human reviewer |
| Human Send back | Read `last_outcome` and current brief, record findings, reconcile/reacquire claim, revise the ticket branch through normal review |
| Independent review and merge | Reviewer closes Git ticket under D-012; human can then Verify the Feature |
| Verify occurs before Git review/merge | Record the mismatch; Git is still awaiting review. Do not mark it done automatically |
| PR merges while Feature awaits verification | Keep the merged evidence and surface pending human verification; do not impersonate the human |

`complete_feature` is submission, not approval. Include the PR URL and a concise summary of results and remaining limits. All tasks must be done or dropped, but that alone does not prove the ticket's acceptance criteria. The full test/Studio evidence belongs in the Git Log because Gatekeeper progress notes are short.

For a Feature already implemented, compare its current criteria with existing code and review evidence. Do not rebuild it or retroactively mark stale tickets done. With an authorized mapping and valid claim, settle its tasks using that evidence and submit the existing PR/commit link only when the criteria are actually met; human verification still follows. Missing independent Git review must be resolved before treating it as complete.

## Ideas and decisions

Use `suggest_idea`, `reply_to_idea` or `propose_answer` only when the human has authorized sending that proposal through the team's bot. Otherwise record it in the ticket Log or `docs/NEXT_REVISION.md` for the human. Accepted proposals still need reconciliation with Git acceptance criteria and decisions before implementation. Transcribe an explicit human decision with its source; never treat the bot's draft as approval.

The server's advice to carry on with a best guess is limited by repository rules: use only already approved scope and permitted DESIGN-sourced provisional values. If a necessary value is missing, block that part and log the question. Do not claim a Feature with unresolved decisions or bypass milestone dependencies.

## Trial evidence and exit

### Assigned handoff: yukicide and jason

Assigned by yukicide under T-044 on October 30, 2026. Assignments reserve responsibilities, not branches or Gatekeeper claims.

| Order | Owner | Task and deliverable | Next actor |
|---|---|---|---|
| Now | jason | Independently review the T-044 planning PR; if it passes, record review/closeout and merge. | jason starts T-045 |
| Preparation — T-045 | jason | Review/close out T-043 based on evidence; verify his connection and distinct agent identity with the administrator; agree one ready Feature, its approved implementation ticket and expected branch with yukicide. Record a non-secret handoff. | yukicide reviews T-045 |
| During preparation | yukicide | Verify his own client can read my_work and the ready queue; supply non-secret results to Jason and help select the Feature. Do not claim it before preparation and the mapping are approved. | jason records both clients' evidence |
| Live implementation | yukicide | Once T-043/T-045 are done, claim the approved mapped implementation ticket and Feature, check the returned branch, post steps, implement, verify, push/report and submit the PR. Use that ticket's branch and Log. | jason independently reviews implementation |
| Review | jason | Check implementation evidence and gates; merge only when review passes, then human Verify. If it fails, Send back with findings; yukicide reconciles and fixes under the runbook. | yukicide collates trial results |
| Trial closeout — T-046 | yukicide | After implementation, claim this separate docs-only ticket and link claim/resume/progress/PR/review evidence plus a human continue/revise decision. | jason reviews T-046 |

T-045 is reviewed by yukicide; T-046 and yukicide's implementation are reviewed by jason. If a selected implementation ticket has a different established owner, choose a different ready Feature or obtain an explicit reassignment before claiming it. T-045/T-046 remain unmapped coordination/validation tickets: only the approved implementation ticket gets `gatekeeper_feature`. Empty queue or unresolved identity/branch compatibility is a logged blocker, not permission to seed or claim unrelated work. These assignments do not change T-042 or other existing gameplay assignments.

T-043 records the read-only readiness rehearsal. A real end-to-end trial remains pending until there is an approved mapped Feature and the connection/identity checks above pass. Then record claim/resume, compatible branch, one pushed progress update, task evidence, PR submission and independent review/Verify or Send back in that ticket's Log. Record observable failures rather than assuming server enforcement.

After that first trial, humans decide whether to expand the pilot. Before adopting Gatekeeper as the sole assignment authority, separately review how to replace D-010, board claims and existing ticket enforcement. To stop the pilot, preserve Logs/PRs and reconcile or release active Gatekeeper claims; unmapped Git work already has its normal path. Do not remove a mapping while a claim is still unresolved.
