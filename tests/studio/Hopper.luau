--!strict
-- T-033: one or more real Studio avatars, isolated controllers and injected clock.
local players = game.Players:GetPlayers()
assert(#players > 0, "HOPPER fixture needs players")
local server, camp = game.ServerScriptService.Server, workspace.RiverCamp
local config = require(game.ReplicatedStorage.Shared.Config)
local now = 0
local session = require(server.Session).new(config, function()
	return now
end, "hopper-fixture")
local remote = { FireClient = function() end }
local digging = require(server.Digging).new(config, session, camp)
local sifting = require(server.Sifting).new(config, session, camp, digging, remote)
local economy = require(server.Economy).new(config, session, camp, digging, sifting, remote)
local machinery = require(server.Machinery).new(session, camp, digging, economy, sifting)
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
local a = players[1]
local machine, bin = session.machine, session.bin
local function request(action, payload)
	return machinery.request(
		a,
		action,
		session.run.id,
		game.HttpService:GenerateGUID(false),
		payload
	)
end
local function dirt(key)
	local d = digging.get(a)
	assert(d.start({
		id = key,
		source = "Bank",
		digger = tostring(a.UserId),
		distance = 0,
		now = now,
		multiplier = config.ordinaryMultiplier,
	}, "running") == "started")
	now += config.digSeconds
	assert(d.step(now, 0, "running", "Bank") == "created")
end
for _, payload in { 0, -1, 0 / 0, math.huge, 1.5, "100", {} } do
	assert(request("hopper", payload) == "invalid_request")
end
a.Character:PivotTo(CFrame.new(camp.Sluice.Position + Vector3.new(-5, 4, 0)))
task.wait(0.5)
local hopperPrice = machine.settings.hopperPrice
assert(hopperPrice == config.sluiceHopperPricePerMember * #players)
-- Isolated transaction fixture, not a live player grant.
economy.get(a).ledger.wallet = machine.settings.price + hopperPrice
assert(request("hopper", 1) == "not_built")
assert(request("contribute", machine.settings.price) == "sluice_built")
-- Dirt deposited to the shared bin stays there until the hopper is built.
for i = 1, config.bucketBatches do
	dirt(string.format("bin-%d", i))
end
assert(
	bin.transfer(
		tostring(a.UserId),
		digging.get(a),
		"deposit",
		session.run.id,
		bin.revision,
		"all",
		true
	) == "deposited"
)
local outcomes = {}
for id, item in bin.batches do
	outcomes[id] = item.outcome
end
machine.step(now, true)
assert(bin.count() == config.bucketBatches and machine.dirtCount() == 0)
assert(request("hopper", hopperPrice - 1) == "hopper_contributed")
local result, charged = request("hopper", hopperPrice)
assert(result == "hopper_built" and charged == 1, result)
assert(request("hopper", 1) == "hopper_already_built")
assert(session.crew.haul == 0)
shift.publish()
assert(status:GetAttribute("SluiceHopper") == true)
assert(status:GetAttribute("SluiceHopperFunded") == hopperPrice)
assert(status:GetAttribute("SluiceHopperPrice") == hopperPrice)
print(
	string.format(
		"[HOPPER fixture] %d real avatar(s): hopper rejected before build; capped final contribution built it once for $%d; duplicates rejected; no haul spent; bin dirt waited until built",
		#players,
		hopperPrice
	)
)
-- The hopper fills every free lane from the bin, then pauses while lanes are full.
local lanes = machine.settings.lanes
local revision = bin.revision
machine.step(now, true)
assert(machine.dirtCount() == lanes and bin.count() == config.bucketBatches - lanes)
assert(bin.revision == revision + 1)
machine.step(now + 1, true)
assert(machine.dirtCount() == lanes and bin.revision == revision + 1)
local moved = 0
while bin.count() > 0 or machine.dirtCount() > 0 do
	now += config.sluiceProcessSeconds
	machine.step(now, true)
	moved += 1
	assert(moved < 100, "HOPPER fixture: bin never drained")
end
local finds = 0
for id, find in machine.outputs do
	assert(
		find.outcome == outcomes[id] and not bin.batches[id],
		"HOPPER fixture: changed dirt " .. id
	)
	finds += 1
end
assert(finds == config.bucketBatches)
print(
	string.format(
		"[HOPPER fixture] fed %d bin dirt through %d lane(s) with no player action; paused while lanes were full; outcomes unchanged, none duplicated",
		finds,
		lanes
	)
)
now = session.run.endsAt
assert(request("hopper", 1) == "wrong_phase")
session.advance(true)
shift.step()
assert(machine.state == nil)
local old = session.run.id
for _, p in players do
	shift.request(p, "replay", old)
end
session.advance(true)
now += config.readySeconds
session.advance(true)
shift.publish()
assert(not machine.state.hopper and machine.state.hopperFunded == 0)
assert(
	status:GetAttribute("SluiceHopper") == false and status:GetAttribute("SluiceHopperFunded") == 0
)
print(
	"[HOPPER fixture] bell rejects funding and clears the sluice; replay resets the hopper to unfunded"
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
status:Destroy()
-- Crew pass: real avatars plus synthetic members up to the cap, so every lane is fed.
local crewSession = require(server.Session).new(config, function()
	return now
end, "hopper-crew")
local ids = {}
for _, p in players do
	table.insert(ids, tostring(p.UserId))
end
for i = #ids + 1, config.crewCapacity do
	table.insert(ids, "synthetic-" .. i)
end
for _, id in ids do
	crewSession.crew.join(id)
end
crewSession.advance(true)
now += config.readySeconds
crewSession.advance(true)
local crewMachine, crewBin = crewSession.machine, crewSession.bin
assert(crewMachine.settings.hopperPrice == config.sluiceHopperPricePerMember * #ids)
local wallets = {}
for _, id in ids do
	wallets[id] = { ledger = { wallet = 10_000, requests = {} } }
	crewMachine.contribute(id, id, wallets[id], crewMachine.settings.price / #ids, "build")
end
assert(crewMachine.state.built)
-- Either order with tier two: tier two first here.
crewMachine.upgrade(ids[1], ids[1], wallets[ids[1]], crewMachine.settings.tierTwoPrice, "tier")
local hopperShare = crewMachine.settings.hopperPrice / #ids
for i, id in ids do
	local result = crewMachine.hopper(id, id, wallets[id], hopperShare + 1, "hopper")
	assert(result == (if i == #ids then "hopper_built" else "hopper_contributed"), result)
end
local spent = 0
for _, id in ids do
	spent += 10_000 - wallets[id].ledger.wallet
end
local total = crewMachine.settings.price
	+ crewMachine.settings.tierTwoPrice
	+ crewMachine.settings.hopperPrice
assert(spent == total and crewSession.crew.haul == 0)
local digger = {
	state = { batches = {} },
	pending = nil,
	sifting = false,
}
for i = 1, crewBin.capacity do
	local id = string.format("crew-%02d", i)
	digger.state.batches[id] = table.freeze({
		id = id,
		source = "Bank",
		digger = ids[1],
		status = "queued",
		active = false,
		outcome = table.freeze({ kind = "Gold Flakes", baseValue = 5, sourceMultiplier = 1 }),
	})
end
assert(
	crewBin.transfer(ids[1], digger, "deposit", crewSession.run.id, crewBin.revision, "all", true)
		== "deposited"
)
crewMachine.step(now, true)
assert(crewMachine.dirtCount() == #ids and crewBin.count() == crewBin.capacity - #ids)
for _, lane in crewMachine.state.lanes do
	assert(lane.readyAt == now + config.sluiceTierTwoSeconds)
end
print(
	string.format(
		"[HOPPER crew] %d real + %d synthetic members: hopper $%d split %d ways after tier two; one step fed all %d lanes at %gs; %d dirt left waiting in the bin",
		#players,
		#ids - #players,
		crewMachine.settings.hopperPrice,
		#ids,
		#ids,
		config.sluiceTierTwoSeconds,
		crewBin.count()
	)
)
print("[HOPPER fixture] PASS; isolated fixture restored avatar attributes/positions")
