--!strict
-- EXP-001: real Studio avatars, isolated controllers, injected cash/finds/clock.
-- Deferred handler calls exercise contention, not network latency or human play.
local players = game.Players:GetPlayers()
local config = require(game.ReplicatedStorage.Shared.Config)
assert(#players >= 2 and #players <= config.crewCapacity, "GATE B fixture needs 2 to cap clients")
local server, camp = game.ServerScriptService.Server, workspace.RiverCamp
local now = 0
local session = require(server.Session).new(config, function()
	return now
end, "gate-b-contention")
local remote = { FireClient = function() end }
local digging = require(server.Digging).new(config, session, camp)
local sifting = require(server.Sifting).new(config, session, camp, digging, remote)
local economy = require(server.Economy).new(config, session, camp, digging, sifting, remote)
local machinery = require(server.Machinery).new(session, camp, digging, economy, sifting)
local saved = {}
for _, p in players do
	saved[p] = { attributes = p:GetAttributes(), pivot = p.Character:GetPivot() }
	session.crew.join(tostring(p.UserId))
	digging.add(p)
	sifting.add(p)
	economy.add(p)
end
session.advance(true)
now = config.readySeconds
session.advance(true)
local function guid()
	return game.HttpService:GenerateGUID(false)
end
local function standAll(pad)
	for i, p in players do
		local x = (i - (#players + 1) / 2) * 4 -- Test-only avatar spacing.
		p.Character:PivotTo(CFrame.new(pad.Position + Vector3.new(x, 4, 0)))
	end
	task.wait(0.5)
end
local function race(fn)
	local done, failures = 0, {}
	for i, p in players do
		task.defer(function()
			local ok, message = xpcall(function()
				fn(p, i)
			end, debug.traceback)
			if not ok then
				table.insert(failures, tostring(message))
			end
			done += 1
		end)
	end
	local deadline = os.clock() + 5 -- Test harness timeout, not gameplay tuning.
	while done < #players and os.clock() < deadline do
		task.wait()
	end
	assert(done == #players, "GATE B contention timed out")
	assert(#failures == 0, table.concat(failures, "\n"))
end
local function wallets()
	local total = 0
	for _, p in players do
		total += economy.get(p).ledger.wallet
	end
	return total
end
standAll(camp.Buyer)
local requestIds = {}
for i, p in players do
	local id = "gate-b-find-" .. i
	digging.get(p).state.batches[id] = { id = id, status = "completed", active = false }
	sifting.get(p).outputs[id] = { id = id, value = config.openingValue }
	requestIds[p] = guid()
end
race(function(p)
	assert(economy.request(p, "sell", requestIds[p]) == "sold")
end)
local haul = config.openingValue * #players
assert(wallets() == haul and session.crew.haul == haul)
race(function(p)
	assert(economy.request(p, "sell", requestIds[p]) == "duplicate_request")
	assert(economy.request(p, "sell", guid()) == "nothing_to_sell")
	assert(next(sifting.get(p).outputs) == nil)
end)
assert(wallets() == haul and session.crew.haul == haul)
print(
	"[GATE B contention] sellers commit once; repeated/empty sales preserve wallet sum and Crew Haul"
)
standAll(camp.Sluice)
local price = session.machine.settings.price
for _, p in players do
	economy.get(p).ledger.wallet = price -- Isolated fixture grant only.
	requestIds[p] = guid()
end
local before, builds = wallets(), 0
race(function(p)
	local result = machinery.request(p, "contribute", session.run.id, requestIds[p], price)
	assert(result == "sluice_built" or result == "already_built", result)
	if result == "sluice_built" then
		builds += 1
	end
end)
assert(builds == 1 and session.machine.state.funded == price)
assert(wallets() == before - price and session.crew.haul == haul)
race(function(p)
	local result = machinery.request(p, "contribute", session.run.id, requestIds[p], price)
	assert(result == "duplicate_request" or result == "already_built", result)
end)
assert(wallets() == before - price and session.machine.state.funded == price)
print(
	"[GATE B contention] competing full-price contributions build once; exactly one price charged; retries preserve cash and haul"
)
now = session.run.endsAt -- Before advance/heartbeat: the exact clock gate must win.
race(function(p)
	assert(machinery.request(p, "transfer", session.run.id, guid(), nil) == "wrong_phase")
	assert(machinery.request(p, "contribute", session.run.id, guid(), price) == "wrong_phase")
	assert(economy.request(p, "sell", guid()) == "wrong_phase")
end)
assert(wallets() == before - price and session.crew.haul == haul)
print(
	"[GATE B contention] exact cutoff rejects sale/contribution/transfer before heartbeat without cash or haul mutation"
)
for _, p in players do
	economy.remove(p)
	sifting.remove(p)
	digging.remove(p)
	for key in p:GetAttributes() do
		if saved[p].attributes[key] == nil then
			p:SetAttribute(key, nil)
		end
	end
	for key, value in saved[p].attributes do
		p:SetAttribute(key, value)
	end
	p.Character:PivotTo(saved[p].pivot)
end
print(
	string.format(
		"[GATE B contention] PASS; %d actual Studio clients, isolated state; restored attributes/positions",
		#players
	)
)
