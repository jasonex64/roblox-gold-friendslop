# Project handoff

Updated October 22, 2026, America/Los_Angeles. This covers the development session spanning the evening of October 21 into October 22 and the earlier repository history.

## Where we stopped

The Gate A solo gameplay implementation is on `main`: dig, sift, sell, buy the temporary shovel, finish the shift, and replay. **PR #23 is merged**, verified against GitHub and main merge commit `ef448f3`. Earlier chat summaries calling it open are superseded. All PRs #1–#23 are merged; the documentation follow-up containing this handoff is separate.

The latest implementation passed all four AGENTS.md gates and **68 unit tests**. Gate A itself is not signed off: T-004 still has outstanding approvals and T-011 still requires its full validation and human continue/revise decision. Normal `numbers.py` passes with **34 provisional values**; that does not satisfy T-011's strict-number requirement.

## Work completed this session

- Built the playable camp and server-owned session on the pure Batch, SkillCheck, Ledger and Run modules.
- Wired bank-pad digging, retained batch identity/outcomes, river sifting, whole-dollar sales, the temporary shovel purchase, end-of-shift settlement and replay.
- Applied the approved bright simulator UI: chunky outlined lettering, glossy gold/lime/cyan/purple panels, contextual controls, help, results and server-driven HUD.
- Added keyboard, mouse and touch actions, automatic tool equip and clear rejection messages.
- Incorporated the owner's unaided playtest: smaller HUD panels at the screen edges, clearer “Press E to dig” wording, and Space handling that does not jump or cancel a sift.
- Separated consecutive starter target zones and made accepted hits immediately advance to the next check. The third accepted hit completes the sift immediately.
- Added lime Good and larger gold Perfect bounce/sparkle animations, including the final hit. These do not delay gameplay or change rewards.

## Final behavior to preserve

- One dig press completes a full configured dig while the player stays on the Bank; repeated clicking is unnecessary.
- Sifting has three checks. The needle takes two seconds per uninterrupted sweep. **There is no preview pause.** A 0.5-second preview was briefly added, then explicitly removed by the owner (D-022).
- Each accepted press immediately resets to the next target; the final press completes the find. Six seconds is the starter maximum when all checks time out, not a minimum wait.
- Starter zones are 5% perfect with 10% good on each side. Consecutive starter zones do not overlap. Extremely wide upgraded zones maximize possible separation when disjoint placement is impossible.
- Space grades the active check without jumping. Normal jumping works outside the minigame. Cancellation discards the active dirt batch.
- Perfect/good/miss value adjustments remain D-015/D-016. Currency rounds per find to whole dollars, nearest with halves up (D-017/D-018).
- Sales increase Run Cash and Crew Haul. Spending cash never lowers Crew Haul. The $50 temporary shovel changes subsequent digs to 0.8 seconds.
- D-023 correction (T-004): at the bell, all unsold finds and unfinished material are discarded without payment. Only prior shop sales count toward haul. Replay resets run cash, inventory, upgrades and opening finds. No permanent saved rewards are claimed.
- Good/Perfect celebrations are driven by server-confirmed grades; they leave the dial/buttons usable and clean up after rapid hits, cancellation, respawn and new runs.

See [DECISIONS.md](DECISIONS.md) for D-013–D-022 and [T-010's Log](tickets/T-010.md) for the detailed feedback, fixes and evidence. Historical log entries retain superseded behavior; the statements above describe the final implementation.

## Verification and limits

- Repository gates: `python tools/check_docs.py`, `python tools/board.py`, `python tools/numbers.py`, and `lune run scripts/check` passed. The Luau gate includes formatting, lint, 68 tests, runner failure self-test and Rojo build.
- Studio exercised real keyboard/mouse/touch actions, invalid requests, full inventory, sale/purchase effects, immediate skill-check transitions and zero-jump behavior.
- Desktop, iPhone 17 Pro and Galaxy A06 landscape layouts were checked for replicated HUD values, text fit, safe areas and minimum 44px buttons. Later animation verification was on desktop.
- A full 600-second solo shift and actual replay were verified under T-009. T-010's small-phone results check was a layout preview, not another full-shift run. T-011 must validate the final integrated build.
- The owner reported that guidance was clear and identified crowding, ambiguous prompts and jumping; those issues were addressed. This is not a broader cohort/device sign-off.
- Existing Studio warnings mention asset `203785492` having a type mismatch. Do not mistake those for a new animation failure; investigate as appropriate during final validation.
- Studio was left running the latest build at the default desktop viewport. Recheck Studio and Rojo state next session rather than assuming the connection survived.

## Resume next session

1. Read AGENTS.md, update `main`, run the board and read the relevant ticket's latest Log. Sync sources through Rojo; edit source files, not Studio script bodies.
2. Reconcile merged PR evidence with stale board labels. T-005–T-010, T-012/T-013 and T-014–T-017 still say `review` despite their PRs being merged. This handoff does not impersonate an independent reviewer or change those statuses.
3. Address [T-004](tickets/T-004.md): record remaining human approvals and approve/replace provisional Config values. Prior decisions already resolve some of its questions; compare them before asking again. Do not invent approvals.
4. Then perform [T-011](tickets/T-011.md): fresh full-loop run, regression checks, approved human testers/devices, strict numbers gate, and an owner continue/revise decision.
5. [T-018](tickets/T-018.md), the Blender/art pipeline, is only planned and depends on Gate A validation. Cooperation, classes, pets, permanent progression and paid-product systems remain later work.

The owner authorized proceeding after merge confirmations, but ended this session for the day. This handoff does not start another implementation ticket or schedule background work.

## Previous pull requests

Every PR below was verified merged on GitHub. The descriptions summarize what each PR contributed when merged; subsequent behavior changes are captured above.

| PR | Ticket | Contribution |
| --- | --- | --- |
| [#1](https://github.com/jasonex64/roblox-gold-friendslop/pull/1) | T-002 | Added AGENTS.md/CLAUDE.md, documentation checks, commit/log enforcement and CI workflow rules. |
| [#2](https://github.com/jasonex64/roblox-gold-friendslop/pull/2) | T-002 | Recorded independent verification and closed the documentation-check ticket. |
| [#3](https://github.com/jasonex64/roblox-gold-friendslop/pull/3) | T-002 | Recorded workflow friction around ticket closeout and NEXT_REVISION updates. |
| [#4](https://github.com/jasonex64/roblox-gold-friendslop/pull/4) | T-003 | Planned Gate A, preserved the supplied design, transcribed owner decisions and created scoped roadmap tickets. |
| [#5](https://github.com/jasonex64/roblox-gold-friendslop/pull/5) | T-001 | Established Rojo sync, Lune tests, StyLua/Selene/build gates, pinned tools, CI and Studio MCP setup instructions. |
| [#6](https://github.com/jasonex64/roblox-gold-friendslop/pull/6) | T-012 | Added pushed-branch claims, remote board visibility, cited/provisional-number checks and simpler closeout rules. |
| [#7](https://github.com/jasonex64/roblox-gold-friendslop/pull/7) | T-013 | Split M1 into independent pure-logic and wiring tickets; added ticket-length enforcement. |
| [#8](https://github.com/jasonex64/roblox-gold-friendslop/pull/8) | T-001 | Recorded fresh-clone setup, independent Studio smoke verification and toolchain closeout. |
| [#9](https://github.com/jasonex64/roblox-gold-friendslop/pull/9) | T-012 | Recorded the review finding that alternate numeric literal forms bypassed citation checks. |
| [#10](https://github.com/jasonex64/roblox-gold-friendslop/pull/10) | T-013 | Recorded missing dependency paths from HUD/validation to digging and sifting. |
| [#11](https://github.com/jasonex64/roblox-gold-friendslop/pull/11) | T-012 | Fixed numeric literal coverage and added regression fixtures for the bypasses. |
| [#12](https://github.com/jasonex64/roblox-gold-friendslop/pull/12) | T-013 | Fixed HUD dependencies so all required implementation work precedes Gate A validation. |
| [#13](https://github.com/jasonex64/roblox-gold-friendslop/pull/13) | T-018 | Added the future Blender pipeline ticket and ART milestone; no Blender tooling implemented. |
| [#14](https://github.com/jasonex64/roblox-gold-friendslop/pull/14) | T-014 | Added pure batch creation/lifecycle rules, immutable outcomes and capacity/rate checks. Later sifting rules discard cancelled active dirt. |
| [#15](https://github.com/jasonex64/roblox-gold-friendslop/pull/15) | T-015 | Added authoritative timestamp grading, target placement, boundary validation and single-use checks. |
| [#16](https://github.com/jasonex64/roblox-gold-friendslop/pull/16) | T-016 | Added atomic, duplicate-safe sales/purchases and separate wallet/haul accounting. |
| [#17](https://github.com/jasonex64/roblox-gold-friendslop/pull/17) | T-017 | Added readiness/countdown/run timing, cutoff enforcement, settlement order and fresh replay IDs. |
| [#18](https://github.com/jasonex64/roblox-gold-friendslop/pull/18) | T-005 | Built the placeholder camp, starter tools, server session and production gate. |
| [#19](https://github.com/jasonex64/roblox-gold-friendslop/pull/19) | T-006 | Wired server-owned bank-pad digging, batch/source/outcome retention and avatar-reset preservation. |
| [#20](https://github.com/jasonex64/roblox-gold-friendslop/pull/20) | T-007 | Wired three-check sifting, perfect/good/miss values, output reservations, cancellation and anti-forgery checks. |
| [#21](https://github.com/jasonex64/roblox-gold-friendslop/pull/21) | T-008 | Added whole-dollar sales and the temporary $50 shovel with 0.8-second digs. |
| [#22](https://github.com/jasonex64/roblox-gold-friendslop/pull/22) | T-009 | Added exactly-once cutoff settlement, results and replay reset; verified a full ten-minute solo shift. |
| [#23](https://github.com/jasonex64/roblox-gold-friendslop/pull/23) | T-010 | Added the themed contextual HUD, desktop/touch controls, guidance, immediate separated skill checks, jump suppression and success animations. |
