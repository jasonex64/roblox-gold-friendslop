--!strict
-- EXP-004 connector verification in Edit mode only. No live datastore or Play.
local server = game.ServerScriptService.Server
local shared = game.ReplicatedStorage.Shared
local clones = {}
local function fresh(module)
	local copy = module:Clone()
	table.insert(clones, copy)
	return require(copy)
end
local Session = fresh(server.Session)
local Shift = fresh(server.Shift)
local Flow = fresh(server.RewardFlow)
local Progression = fresh(server.Progression)
local Profile = fresh(shared.Pure.Profile)
local Rewards = fresh(shared.Pure.RunRewards)
local Config = require(shared.Config)
local http = game:GetService("HttpService")
local data = {}
local failWrites = true
local store = {}
local function copy(value)
	return if value then http:JSONDecode(http:JSONEncode(value)) else nil
end
function store.read(key)
	return true, copy(data[key])
end
function store.update(key, transform)
	if failWrites then
		return false, "fixture write failure"
	end
	local value = transform(copy(data[key]))
	if value then
		data[key] = copy(value)
	end
	return true, copy(value)
end
local tasks = {}
local service = Progression.new(store, Profile)
local rewards = Flow.new(service, Rewards.build, Config, function(fn)
	table.insert(tasks, fn)
end, function() end)
local now = 0
local session = Session.new(Config, function()
	return now
end, "t040-fixture")
session.crew.join("42")
session.crew.join("7")
session.advance(true)
now = 3
session.advance(true)
for time = 63, 483, 60 do
	now = time
	session.crew.activity("42", now)
end
session.reveal({ id = "find-1", kind = "Ruby" })
now = 493
session.crew.leave("42")
session.crew.haul = 12000
local status = Instance.new("Folder")
local label = { Text = "" }
local spawn = {
	Parent = {
		FindFirstChild = function()
			return { BillboardGui = { TextLabel = label } }
		end,
	},
}
local empty = {
	get = function()
		error("unexpected real player in Edit fixture")
	end,
}
local shift = Shift.new(session, empty, empty, empty, status, spawn, rewards)
now = 603
session.advance(false)
shift.step()
assert(session.run.phase == "results")
assert(session.rewardSnapshot.participants[42].activeSeconds == 490)
assert(session.rewardSnapshot.crewSize == 2)
assert(rewards.result("t040-fixture", 42).status == "pending")
assert(status:GetAttribute("RewardsDurable") == false)
while #tasks > 0 do
	table.remove(tasks, 1)()
end
session.crew.vote("7")
shift.step()
assert(session.run.phase == "results", "failed store must block replay")
failWrites = false
rewards.retry("t040-fixture")
while #tasks > 0 do
	table.remove(tasks, 1)()
end
assert(rewards.durable("t040-fixture"))
assert(service.load(42).profile.tokens == 32)
assert(service.load(42).profile.completedRuns == 1)
assert(service.load(42).profile.discoveries.Ruby == true)
assert(service.load(7).profile.tokens == 0)
shift.step()
assert(session.run.phase == "waiting")
assert(session.crew.haul == 0)
assert(session.rewardSnapshot == nil)
assert(session.run.id == "t040-fixture/replay")
assert(service.load(42).profile.tokens == 32)
status:Destroy()
for _, module in clones do
	module:Destroy()
end
return "[T040 Edit fixture] PASS: retained departed participant 490s; failed store blocks replay; recovery grants 32 once; replay resets temporary state and preserves saved tokens. Fake store only."
