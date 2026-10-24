--!strict
-- One or more real Studio avatars, isolated controllers and injected clock.
local players = game.Players:GetPlayers()
assert(#players > 0, "MACHINE fixture needs players")
local server, camp = game.ServerScriptService.Server, workspace.RiverCamp
local config = require(game.ReplicatedStorage.Shared.Config)
local now = 0
local session = require(server.Session).new(config, function()
	return now
end, "machine-fixture")
local remote = { FireClient = function() end }
local digging = require(server.Digging).new(config, session, camp)
local sifting = require(server.Sifting).new(config, session, camp, digging, remote)
local economy = require(server.Economy).new(config, session, camp, digging, sifting, remote)
local machinery = require(server.Machinery).new(session, camp, digging, economy)
local interaction =
	require(server.Interaction).new(config, session, camp, digging, sifting, economy)
local status = Instance.new("Folder")
local shift = require(server.Shift).new(session, digging, sifting, economy, status, camp.CampSpawn)
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
local a, b = players[1], players[#players]
local function guid()
	return game.HttpService:GenerateGUID(false)
end
local function stand(p, pad, x)
	p.Character:PivotTo(CFrame.new(pad.Position + Vector3.new(x, 4, 0)))
	task.wait(0.5)
end
local function request(p, action, payload)
	return machinery.request(p, action, session.run.id, guid(), payload)
end
local function dirt(p, key)
	local d = digging.get(p)
	assert(d.start({
		id = key,
		source = "Bank",
		digger = tostring(p.UserId),
		distance = 0,
		now = now,
		multiplier = config.ordinaryMultiplier,
	}, "running") == "started")
	now += config.digSeconds
	assert(d.step(now, 0, "running", "Bank") == "created")
	return d.state.batches[key]
end
for _, payload in { 0, -1, 0 / 0, math.huge, 1.5, "100", {} } do
	assert(request(a, "contribute", payload) == "invalid_request")
end
assert(machinery.request(a, "load", session.run.id, guid(), "bin", "extra") == "invalid_request")
assert(machinery.request(a, "load", "old", guid(), "bin") == "stale_run")
stand(a, camp.Camp, 0)
assert(request(a, "contribute", 1) == "stand_at_sluice")
stand(a, camp.Sluice, -5)
assert(request(a, "contribute", 1) == "insufficient_funds")
local price = session.machine.settings.price
economy.get(a).ledger.wallet = price + 50 -- Isolated transaction fixture, not a live player grant.
local rid = guid()
assert(machinery.request(a, "contribute", session.run.id, rid, price - 1) == "contributed")
assert(machinery.request(a, "contribute", session.run.id, rid, price - 1) == "duplicate_request")
assert(economy.get(a).ledger.wallet == 51 and session.crew.haul == 0)
if b ~= a then
	economy.get(b).ledger.wallet = 100
end
stand(b, camp.Sluice, 5)
local result, charged = request(b, "contribute", 100)
assert(result == "sluice_built" and charged == 1)
assert(request(a, "contribute", 1) == "already_built")
assert(session.machine.settings.lanes == #players)
assert(session.machine.settings.outputCapacity == config.sluiceOutputPerMember * #players)
shift.publish()
machinery.publish()
assert(status:GetAttribute("SluiceBuilt") and status:GetAttribute("SluiceFunded") == price)
assert(camp.SluiceTrough.Transparency == 0)
local original = dirt(a, "shared-bin")
assert(
	session.bin.transfer(
		tostring(a.UserId),
		digging.get(a),
		"deposit",
		session.run.id,
		session.bin.revision,
		"all",
		true
	) == "deposited"
)
assert(request(b, "load", "bin") == "sluice_loaded")
assert(
	session.bin.count() == 0 and session.machine.batches[original.id].outcome == original.outcome
)
local loadedAt = now
assert(session.machine.step(loadedAt + config.sluiceProcessSeconds - 0.01, true) == 0)
now = loadedAt + config.sluiceProcessSeconds
assert(session.machine.step(now, true) == 1)
assert(session.machine.outputs[original.id].value == config.openingValue)
assert(session.machine.outputs[original.id].digger == tostring(a.UserId))
-- Pure output exists without personal finds: the real interaction must expose Sell.
stand(b, camp.Buyer, 0)
interaction.publish(b)
assert(b:GetAttribute("HudAction") == "sell")
local walletBefore = 0
for _, p in players do
	walletBefore += economy.get(p).ledger.wallet
end
assert(economy.request(b, "sell", guid()) == "sold")
local walletAfter = 0
for _, p in players do
	walletAfter += economy.get(p).ledger.wallet
end
assert(
	walletAfter - walletBefore == config.openingValue and session.crew.haul == config.openingValue
)
assert(next(session.machine.outputs) == nil and next(session.machine.state.output) == nil)
assert(economy.request(b, "sell", guid()) == "nothing_to_sell")
stand(b, camp.Sluice, 5)
dirt(b, "cutoff")
assert(request(b, "load", "bucket") == "sluice_loaded")
now = session.run.endsAt
assert(request(b, "load", "bucket") == "wrong_phase")
session.advance(true)
assert(session.machine.step(now, session.accepts()) == 0)
shift.step()
assert(session.machine.state == nil and next(session.machine.outputs) == nil)
assert(shift.result.haul == config.openingValue)
local old = session.run.id
for _, p in players do
	shift.request(p, "replay", old)
end
assert(session.run.phase == "waiting" and session.machine.state == nil)
session.advance(true)
now += config.readySeconds
session.advance(true)
assert(session.machine.state.funded == 0 and not session.machine.state.built)
for _, p in players do
	assert(economy.get(p).ledger.wallet == 0)
end
print(
	string.format(
		"[MACHINE fixture] %d real avatar(s): capped final contribution built once; no haul spent; shared-bin provenance retained; four-second find sold through crew shares; empty sale adds nothing",
		#players
	)
)
print(
	"[MACHINE fixture] invalid/location/stale/cutoff requests rejected; bell destroys unfinished dirt without payment; replay clears wallets, funding, lanes and output"
)
for _, p in players do
	economy.remove(p)
	sifting.remove(p)
	digging.remove(p)
	for key, value in saved[p].attributes do
		p:SetAttribute(key, value)
	end
	p.Character:PivotTo(saved[p].pivot)
end
status:Destroy()
print("[MACHINE fixture] PASS; isolated fixture restored avatar attributes/positions")
