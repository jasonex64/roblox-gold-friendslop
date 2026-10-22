--!strict
-- The Luau gate. Same command locally and in CI: `lune run scripts/check`
-- Steps: format, lint, unit tests, runner self-test, build. Stops at the first failure.
local fs = require("@lune/fs")
local process = require("@lune/process")

local function run(name: string, cmd: string, args: { string }): process.ExecResult
	print(string.format("==> %s: %s %s", name, cmd, table.concat(args, " ")))
	return process.exec(cmd, args, { stdio = "inherit" })
end

local function must(name: string, cmd: string, args: { string })
	local r = run(name, cmd, args)
	if not r.ok then
		print(string.format("FAILED at '%s' (exit %d)", name, r.code))
		process.exit(1)
	end
end

must("format", "stylua", { "--check", "src", "tests", "scripts" })
must("lint", "selene", { "src" })
must("unit tests", "lune", { "run", "tests/run", "unit" })

-- The runner must fail loudly: the selftest suite has 1 passing and 1 failing test.
local selfTest = process.exec("lune", { "run", "tests/run", "selftest" })
if
	selfTest.code ~= 1 or not string.find(selfTest.stdout, "selftest: 1 passed, 1 failed", 1, true)
then
	print("FAILED at 'runner selftest': expected exit 1 with 1 passed, 1 failed, got:")
	print(selfTest.stdout)
	process.exit(1)
end
print("==> runner selftest: failing test exits non-zero (ok)")

if not fs.isDir("build") then
	fs.writeDir("build")
end
must("build", "rojo", { "build", "default.project.json", "--output", "build/game.rbxl" })
print("ALL CHECKS PASSED")
