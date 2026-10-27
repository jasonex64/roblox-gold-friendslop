--!strict
-- T-032: one or more real Studio avatars, isolated controllers and injected clock.
local players = game.Players:GetPlayers()
assert(#players > 0, "TIER2 fixture needs players")
local server, camp = game.ServerScriptService.Server, workspace.RiverCamp
local config = require(game.ReplicatedStorage.Shared.Config)
local now = 0
local session = require(server.Session).new(config, function()
	return now
end, "tier-two-fixture")
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
local started = session.run.startedAt
local a, b = players[1], players[#players]
local function guid()
	return game.HttpService:GenerateGUID(false)
end
local function stand(p, x)
	p.Character:PivotTo(CFrame.new(camp.Sluice.Position + Vector3.new(x, 4, 0)))
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
end
local function laneOf(id)
	for _, lane in session.machine.state.lanes do
		if lane.batch == id then
			return lane
		end
	end
	error("TIER2 fixture: batch not in a lane " .. id)
end
for _, payload in { 0, -1, 0 / 0, math.huge, 1.5, "100", {} } do
	assert(request(a, "upgrade", payload) == "invalid_request")
end
stand(a, -5)
stand(b, 5)
-- Isolated transaction fixture, not a live player grant.
local price = session.machine.settings.price
local tierPrice = session.machine.settings.tierTwoPrice
assert(tierPrice == config.sluiceTierTwoPricePerMember * #players)
economy.get(a).ledger.wallet = price + tierPrice
assert(request(a, "upgrade", 1) == "not_built")
assert(request(a, "contribute", price) == "sluice_built")
-- A lane loaded before tier two keeps the tier-one finish time.
dirt(a, "before")
assert(request(a, "transfer", nil) == "sluice_transferred")
session.machine.step(now, true)
local beforeAt = now
assert(laneOf("before").readyAt == beforeAt + config.sluiceProcessSeconds)
local rid = guid()
assert(machinery.request(a, "upgrade", session.run.id, rid, tierPrice - 1) == "upgrade_contributed")
assert(machinery.request(a, "upgrade", session.run.id, rid, tierPrice - 1) == "duplicate_request")
if b ~= a then
	economy.get(b).ledger.wallet = 100
end
local result, charged = request(b, "upgrade", 100)
assert(result == "tier_two_built" and charged == 1)
assert(request(a, "upgrade", 1) == "already_upgraded")
assert(session.crew.haul == 0)
assert(laneOf("before").readyAt == beforeAt + config.sluiceProcessSeconds)
shift.publish()
assert(status:GetAttribute("SluiceTierTwo") == true)
assert(status:GetAttribute("SluiceTierTwoFunded") == tierPrice)
assert(status:GetAttribute("SluiceTierTwoPrice") == tierPrice)
print(
	string.format(
		"[TIER2 fixture] %d real avatar(s): tier two rejected before build; capped final contribution built it once for $%d; duplicates rejected; no haul spent",
		#players,
		tierPrice
	)
)
now = beforeAt + config.sluiceProcessSeconds
assert(session.machine.step(now, true) == 1)
dirt(a, "after")
assert(request(a, "transfer", nil) == "sluice_transferred")
session.machine.step(now, true)
assert(laneOf("after").readyAt == now + config.sluiceTierTwoSeconds)
now += config.sluiceTierTwoSeconds
assert(session.machine.step(now, true) == 1)
-- A lane loaded one second before 9:00 runs one second normally, the rest 25% faster.
now = started + config.rushStart - 1 - config.digSeconds
dirt(a, "rush")
assert(request(a, "transfer", nil) == "sluice_transferred")
session.machine.step(now, true)
local rushAt = laneOf("rush").readyAt - started
local expected = config.rushStart + (config.sluiceTierTwoSeconds - 1) / (1 + config.rushSpeedup)
assert(math.abs(rushAt - expected) < 1e-9, "rush lane finish " .. rushAt)
print(
	string.format(
		"[TIER2 fixture] running lane kept %gs; next lane %gs; lane loaded at 8:59 finishes at %.2fs (rush applies only after 9:00)",
		config.sluiceProcessSeconds,
		config.sluiceTierTwoSeconds,
		rushAt
	)
)
now = session.run.endsAt
assert(request(a, "upgrade", 1) == "wrong_phase")
session.advance(true)
shift.step()
assert(session.machine.state == nil)
local old = session.run.id
for _, p in players do
	shift.request(p, "replay", old)
end
session.advance(true)
now += config.readySeconds
session.advance(true)
shift.publish()
assert(not session.machine.state.tierTwo and session.machine.state.tierTwoFunded == 0)
assert(status:GetAttribute("SluiceTierTwo") == false)
assert(status:GetAttribute("SluiceTierTwoFunded") == 0)
print(
	"[TIER2 fixture] bell rejects funding and clears the sluice; replay resets tier two to unfunded"
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
-- Crew pass: real avatars plus synthetic members up to the cap, so lanes run side by side.
local crewSession = require(server.Session).new(config, function()
	return now
end, "tier-two-crew")
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
local machine = crewSession.machine
assert(machine.settings.lanes == #ids)
assert(machine.settings.tierTwoPrice == config.sluiceTierTwoPricePerMember * #ids)
local wallets = {}
for _, id in ids do
	wallets[id] = { ledger = { wallet = machine.settings.price, requests = {} } }
end
local share = machine.settings.price / #ids
for _, id in ids do
	machine.contribute(id, id, wallets[id], share, "build")
end
assert(machine.state.built)
local function queue(id)
	machine.batches[id] = table.freeze({
		id = id,
		source = "Bank",
		digger = ids[1],
		status = "queued",
		active = false,
		outcome = table.freeze({ kind = "Gold Flakes", baseValue = 5, sourceMultiplier = 1 }),
	})
	table.insert(machine.queue, id)
end
queue("crew-before")
machine.step(now, true)
local loadedAt = now
local tierShare = machine.settings.tierTwoPrice / #ids
for i, id in ids do
	local result = machine.upgrade(id, id, wallets[id], tierShare + 1, "tier")
	assert(result == (if i == #ids then "tier_two_built" else "upgrade_contributed"), result)
end
local spent = 0
for _, id in ids do
	spent += machine.settings.price - wallets[id].ledger.wallet
end
assert(
	spent == machine.settings.price + machine.settings.tierTwoPrice and crewSession.crew.haul == 0
)
now += 1
queue("crew-after")
machine.step(now, true)
local before, after
for _, lane in machine.state.lanes do
	if lane.batch == "crew-before" then
		before = lane
	elseif lane.batch == "crew-after" then
		after = lane
	end
end
assert(before.readyAt == loadedAt + config.sluiceProcessSeconds)
assert(after.readyAt == now + config.sluiceTierTwoSeconds)
print(
	string.format(
		"[TIER2 crew] %d real + %d synthetic members: price $%d split %d ways, capped at exactly the price; old lane %gs and new lane %gs run side by side; no haul spent",
		#players,
		#ids - #players,
		machine.settings.tierTwoPrice,
		#ids,
		config.sluiceProcessSeconds,
		config.sluiceTierTwoSeconds
	)
)
print("[TIER2 fixture] PASS; isolated fixture restored avatar attributes/positions")
