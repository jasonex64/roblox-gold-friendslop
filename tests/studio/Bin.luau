--!strict
-- Connector-run integration fixture, supports solo or real multiplayer clients.
-- Uses isolated controllers and injected time; restores live attributes/positions.
local players = game.Players:GetPlayers()
assert(#players > 0, "BIN fixture needs players")
local server = game.ServerScriptService.Server
local config = require(game.ReplicatedStorage.Shared.Config)
local camp = workspace.RiverCamp
local now = 0
local session = require(server.Session).new(config, function()
	return now
end, "bin-fixture")
local remote = { FireClient = function() end }
local digging = require(server.Digging).new(config, session, camp)
local sifting = require(server.Sifting).new(config, session, camp, digging, remote)
local economy = require(server.Economy).new(config, session, camp, digging, sifting, remote)
local bin = require(server.SharedBin).new(session, camp, digging)
local status = Instance.new("Folder")
local shift = require(server.Shift).new(session, digging, sifting, economy, status, camp.CampSpawn)
local originals = {}
for _, player in players do
	originals[player] = { attributes = player:GetAttributes(), pivot = player.Character:GetPivot() }
	session.crew.join(tostring(player.UserId))
	digging.add(player)
	sifting.add(player)
	economy.add(player)
end
session.advance(true)
now = config.readySeconds
session.advance(true)
assert(session.bin.capacity == config.binBatchesPerMember * #players)
local a, b = players[1], players[#players]
local function stand(player, pad)
	player.Character:PivotTo(CFrame.new(pad.Position + Vector3.new(0, 4, 0)))
	task.wait(0.5)
end
local function transfer(player, action)
	return bin.request(player, action, session.run.id, session.bin.revision, 1)
end
local function makeDirt(player, key)
	local d = digging.get(player)
	assert(d.start({
		id = key,
		source = "Bank",
		digger = tostring(player.UserId),
		distance = 0,
		now = now,
		multiplier = config.ordinaryMultiplier,
	}, "running") == "started")
	now += config.digSeconds
	assert(d.step(now, 0, "running", "Bank") == "created")
end
assert(bin.request(a, "deposit", {}, 0) == "invalid_request")
assert(bin.request(a, "deposit", session.run.id, 0 / 0) == "invalid_request")
assert(bin.request(a, "deposit", session.run.id, 0, "extra") == "invalid_request")
assert(bin.request(a, "withdraw", "old", 0, 1) == "stale_run")
stand(a, camp.Camp)
assert(transfer(a, "withdraw") == "stand_at_bin")
makeDirt(a, "shared")
local item = digging.get(a).state.batches.shared
stand(a, camp.DirtBin)
local rev = session.bin.revision
assert(transfer(a, "deposit") == "deposited")
assert(a:GetAttribute("CarriedBatches") == 0 and session.bin.batches.shared == item)
assert(bin.request(a, "deposit", session.run.id, rev, 1) == "bin_changed")
assert(transfer(a, "deposit") == "bucket_empty")
-- Separate avatars stand on opposite halves so physics cannot stack them.
a.Character:PivotTo(CFrame.new(camp.DirtBin.Position + Vector3.new(-5, 4, 0)))
stand(b, camp.DirtBin)
assert(transfer(b, "withdraw") == "withdrawn")
assert(b:GetAttribute("CarriedBatches") == 1)
assert(digging.get(b).state.batches.shared == item)
assert(transfer(b, "withdraw") == "bin_empty")
assert(sifting.get(b).start(now, "sift-shared", 0, 1) == "started")
local code, find = sifting.get(b).step(now + config.siftSeconds, true)
assert(code == "completed" and find.digger == tostring(a.UserId) and find.outcome == item.outcome)
stand(b, camp.Buyer)
assert(economy.request(b, "sell", game.HttpService:GenerateGUID(false)) == "sold")
assert(session.crew.haul == find.value)
local wallets = 0
for _, player in players do
	wallets += economy.get(player).ledger.wallet
end
assert(wallets == find.value)
print(
	string.format(
		"[BIN fixture] %d real player(s): deposit -> teammate withdraw -> sift -> shared sale; identity/outcome/provenance preserved; wallets sum to $%d",
		#players,
		wallets
	)
)
stand(a, camp.DirtBin)
for i = 1, session.bin.capacity do
	makeDirt(a, "fill-" .. i)
	assert(transfer(a, "deposit") == "deposited")
end
makeDirt(a, "overflow")
assert(transfer(a, "deposit") == "bin_full")
assert(digging.get(a).state.batches.overflow)
shift.publish()
assert(status:GetAttribute("BinCount") == session.bin.capacity)
assert(status:GetAttribute("BinCapacity") == session.bin.capacity)
-- The clock gate rejects transfers at cutoff before the heartbeat clears dirt.
now = session.run.endsAt
assert(transfer(a, "withdraw") == "wrong_phase")
session.advance(true)
shift.step()
assert(session.bin.count() == 0 and status:GetAttribute("BinCount") == 0)
assert(shift.result.haul == find.value and session.crew.haul == find.value)
local oldId = session.run.id
for _, player in players do
	shift.request(player, "replay", oldId)
end
assert(session.run.phase == "waiting" and session.bin.count() == 0 and session.bin.capacity == 0)
assert(bin.request(a, "withdraw", oldId, session.bin.revision, 1) == "stale_run")
for _, player in players do
	assert(economy.get(player).ledger.wallet == 0)
end
print(
	"[BIN fixture] malformed/out-of-range/repeated/full/empty/cutoff requests safe; bell discards shared dirt without payment; unanimous replay clears bin and cash"
)
for _, player in players do
	economy.remove(player)
	sifting.remove(player)
	digging.remove(player)
	for key, value in originals[player].attributes do
		player:SetAttribute(key, value)
	end
	player.Character:PivotTo(originals[player].pivot)
end
status:Destroy()
print("[BIN fixture] PASS; live attributes and positions restored")
