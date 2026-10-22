# Next revision

Small or non-blocking things. Append-only. Record here BEFORE acting on any of them.
Triaged into tickets at milestone planning; until then nobody works on them.

| Date | From (human / agent / review) | Ticket or file | Item | Triaged to |
|---|---|---|---|---|
| 2026-10-19 | jason / yukicide review of T-002 | WORKFLOW.md §2, §5; tools/check_docs.py | Closing a ticket (`status: done`) needs a whole extra PR, because direct pushes to main are only allowed for create/claim. Proposal: allow ticket-file-only status changes (claim and done) on main, checked by check_docs.py. | T-012 (D-012) |
| 2026-10-19 | jason / claude-opus-5.5 | WORKFLOW.md, docs/NEXT_REVISION.md | Appending a row here also needs a ticket Log entry + PR, since check_docs.py requires one for any non-ticket file. Same fix as above could cover NEXT_REVISION.md appends. | T-012 (D-012) |
