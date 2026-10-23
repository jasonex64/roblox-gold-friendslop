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

For the latest development summary, PR history and resume checklist, read [the project handoff](docs/HANDOFF.md).

1. `git checkout main && git pull`
2. `rojo serve`, open Studio, Rojo plugin -> Connect.
3. Tell your agent: **"Follow AGENTS.md. Pick the next ready ticket."**
4. Review someone else's open PR.

## Studio smoke check (for T-001 sign-off)

With `rojo serve` connected, ask your agent to use the Studio MCP to start a playtest and read the console.
Expected lines: `[server] boot ok` and `[client] boot ok <your name>`.

## Optional Blender art pipeline (T-018)

Gameplay development does not require Blender. For art, install Blender 3+,
Python 3.10+, Git LFS and `uv`. The generator was verified with Blender 3.3.0.
Follow the [upstream add-on installation guide](https://www.mcp-for-blender.com/docs/installation):
run `uvx mcp-for-blender install-addon`, enable **Interface: MCP for Blender** in
Blender Preferences, and check the viewport's **N → MCP for Blender** panel.
Use the same Blender instance throughout the work.

Configure the MCP server environment before starting it (use the full path to
`uvx` if your client cannot find it):

```json
{
  "command": "uvx",
  "args": ["mcp-for-blender"],
  "env": {
    "BLENDER_HOST": "127.0.0.1",
    "BLENDER_PORT": "9876",
    "BLENDER_MCP_SAFE_MODE": "1",
    "DISABLE_TELEMETRY": "true"
  }
}
```

Keep the add-on socket on loopback only; do not expose or forward its port.
Turn off the add-on's telemetry consent too. Check `get_addon_status` reports
a working, compatible connection and telemetry off before agent modeling.
See the [configuration reference](https://www.mcp-for-blender.com/docs/reference/configuration).
These are setup requirements, not a claim that another person's machine is configured.

The modeling-only `tools/blender/gold_pan.py` can run in Blender's Text Editor
or be sent as source to `execute_blender_code`. It replaces only its own tagged
collection. Keep safe mode on. The file-writing exporter runs separately as a
local Blender command; do not send it through MCP or disable safe mode to run it.

From the repo root, using your installed Blender executable:

```powershell
git lfs install --local
git lfs pull
blender --background --factory-startup --python tools/blender/export_pan.py
Get-FileHash assets/meshes/gold_pan.obj,assets/meshes/gold_pan.mtl
# Run the export and hashes again: both hashes must match.
git lfs ls-files
```

On this PC, replace `blender` with `& 'O:\Blender\blender.exe'`.
The exporter validates watertight edges, outward volume and the triangle budget,
and prints `[BLEND-1/2]` with counts/hash. Commit the generator, OBJ and MTL together.
OBJ uses Y-up coordinates and has no unit metadata; preserve its proportions in import.

Human handoff: in the **existing Studio place**, stop Play, use the
[3D Importer](https://create.roblox.com/docs/studio/importer) to select
`assets/meshes/gold_pan.obj` (keep the MTL beside it), review scale/orientation,
then upload under the experience's intended creator. Give the agent the resulting
**mesh asset ID**, creator and permission confirmation. The agent records that
ID with a human decision citation in Config, wires the prop through source/Rojo,
then verifies it during Play. No placeholder or invented asset ID is used.

Second-person setup check: another human follows this section on their machine,
reports Blender/add-on versions and safe-mode/telemetry/loopback settings, runs
the exporter twice, and supplies both hashes and the `[BLEND-1/2]` output for
T-018's Log. Until that check and the uploaded-prop playtest are recorded,
T-018 remains unfinished.

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
