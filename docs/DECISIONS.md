# Decisions

Every number, threshold, limit, timing, and rule an agent might otherwise guess lives here.
Humans add entries. Agents may propose one in a ticket Log or EXP conclusion; it isn't real until a human commits it here.
Never edit an entry's value in place — add a new entry that supersedes it.

| ID | Date | Decision / value | Source (who / EXP) | Supersedes |
|---|---|---|---|---|
| D-001 | 2026-10-19 | `main` is NOT branch-protected (free private repo can't enable it). Review is enforced by convention + `tools/check_docs.py` in CI, which flags undocumented pushes but cannot block them. Revisit before real game code lands. | jason | — |
