# Gold Rush (roblox-gold-friendslop)

Three humans, each running an agent (Claude Code or Codex), working async on one Roblox game.
Agents follow `AGENTS.md`. The full process is `WORKFLOW.md`. The board is `python tools/board.py`.

```
GitHub main (truth) --git pull--> your folder --rojo serve--> your Roblox Studio
                                       ^                            |
                          agent edits files in src/      Studio MCP: agent playtests,
                                       |                 reads console, screenshots
                  python tools/check_docs.py + lune run scripts/check  (same in CI)
```

## One-time setup (each person)

1. Install **Roblox Studio**, **Git**, **Python 3**, and get push access to this repo.
2. Install **Rokit**: https://github.com/rojo-rbx/rokit#installation
3. In the repo folder: `rokit install` (installs the pinned rojo, lune, stylua, selene from `rokit.toml`).
4. `rojo plugin install` (adds the Rojo plugin to Studio).
5. Install your agent:
   - Claude: Claude Code (`claude`). It reads `CLAUDE.md`, which imports `AGENTS.md`.
   - ChatGPT: Codex CLI or app (`codex`), not the ChatGPT web chat. It reads `AGENTS.md`.
   - The agent must be able to `git pull` and `git push` on its own. Check this first.
6. Connect the agent to Studio (Roblox's built-in MCP server, no extra plugin):
   - Studio: Assistant -> `...` -> Manage MCP Servers -> turn on **Enable Studio as MCP server** -> **Quick connect** your client.
   - Or by hand. Command on macOS: `/Applications/RobloxStudio.app/Contents/MacOS/StudioMCP`. Windows: `cmd.exe /c %LOCALAPPDATA%\Roblox\mcp.bat`
     - `claude mcp add Roblox_Studio -- <command>`
     - `codex mcp add Roblox_Studio -- <command>`
   - A green dot in Manage MCP Servers means connected. Studio must be open for the tools to work.
7. Verify both gates pass:
   - `lune run scripts/check` ends with `ALL CHECKS PASSED`
   - `python tools/board.py` exits 0

## Every session

1. `git checkout main && git pull`
2. `rojo serve`, open Studio, Rojo plugin -> Connect.
3. Tell your agent: **"Follow AGENTS.md. Pick the next ready ticket."**
4. Review someone else's open PR.

## Studio smoke check (for T-001 sign-off)

With `rojo serve` connected, ask your agent to use the Studio MCP to start a playtest and read the console.
Expected lines: `[server] boot ok` and `[client] boot ok <your name>`.

## Layout

| Path | What |
|---|---|
| `src/server`, `src/client`, `src/shared` | Luau, synced into Studio by Rojo (`default.project.json`) |
| `src/shared/Pure` | game logic with no Roblox APIs, tested by Lune |
| `tests/unit` | `*.spec.luau` unit tests, run by `lune run tests/run unit` |
| `tests/selftest` | proves the runner fails loudly (one pass, one fail on purpose) |
| `assets/` | `.rbxm` content built in Studio, mapped in `default.project.json` |
| `docs/` | roadmap, design, decisions, tickets |
| `tools/` | Python workflow checks |
