--!strict
-- Zero-dependency Luau test runner (Lune).
-- Usage: lune run tests/run <suite>   (runs tests/<suite>/*.spec.luau)
-- Sorted order, so output is reproducible. Exit 1 if any test fails.
local fs = require("@lune/fs")
local process = require("@lune/process")

local suite = process.args[1]
assert(suite and string.match(suite, "^[%w_-]+$"), "usage: lune run tests/run <suite>")
local dir = "tests/" .. suite
assert(fs.isDir(dir), "no such suite directory: " .. dir)

local t = {}
function t.equal(actual: any, expected: any)
	if actual ~= expected then
		error(string.format("expected %s, got %s", tostring(expected), tostring(actual)), 2)
	end
end
function t.errors(fn: () -> ())
	if pcall(fn) then
		error("expected function to error", 2)
	end
end

local files = {}
for _, name in fs.readDir(dir) do
	if string.match(name, "%.spec%.luau$") then
		table.insert(files, name)
	end
end
table.sort(files)

local passed, failed = 0, 0
for _, file in files do
	local cases = (require :: any)("./" .. suite .. "/" .. string.gsub(file, "%.luau$", ""))
	local names = {}
	for caseName in cases do
		table.insert(names, caseName)
	end
	table.sort(names)
	for _, caseName in names do
		local ok, err = pcall(cases[caseName], t)
		if ok then
			passed += 1
			print("PASS  " .. file .. " :: " .. caseName)
		else
			failed += 1
			print("FAIL  " .. file .. " :: " .. caseName .. "\n      " .. tostring(err))
		end
	end
end

print(string.format("%s: %d passed, %d failed", suite, passed, failed))
process.exit(if failed > 0 then 1 else 0)
