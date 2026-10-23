--!strict
-- Execute in Studio Server during play. Isolated controllers use the shipped
-- duration and injected time; the separate live soak exercises wall-clock wiring.
local Players = game:GetService("Players")
local player = Players:GetPlayers()[1]
assert(player and #Players:GetPlayers() == 1, "END fixtures require Gate A solo player")
local server = game.ServerScriptService.Server
local config = require(game.ReplicatedStorage.Shared.Config)
local originalAttributes = player:GetAttributes()
local originalPivot = player.Character:GetPivot()
local now = 0
local session = require(server.Session).new(config, function()
	return now
end, "end-fixture")
session.crew.join(tostring(player.UserId))
local camp = workspace.RiverCamp
local remote = { FireClient = function() end }
local digging = require(server.Digging).new(config, session, camp)
local sifting = require(server.Sifting).new(config, session, camp, digging, remote)
local economy = require(server.Economy).new(config, session, camp, digging, sifting, remote)
digging.add(player)
sifting.add(player)
economy.add(player)
local status = Instance.new("Folder")
local shift = require(server.Shift).new(session, digging, sifting, economy, status, camp.CampSpawn)
local dig, sift, ledger = digging.get(player), sifting.get(player), economy.get(player)
local function find(id, value)
	dig.state.batches[id] = { id = id, status = "completed", active = false }
	sift.outputs[id] = { id = id, value = value }
end
session.advance(true)
now = config.readySeconds
session.advance(true)
assert(shift.request(player, "replay", session.run.id) == "wrong_phase")
find("prior", 60)
session.crew.sale(
	tostring(player.UserId),
	ledger,
	{ [tostring(player.UserId)] = ledger },
	"prior-sale",
	now
)
assert(ledger.buy("prior-buy") == "purchased")
find("complete", 19)
dig.state.batches.raw = { id = "raw", status = "queued" }
dig.state.batches.processing = { id = "processing", status = "processing", active = true }
sift.pending = { batchId = "processing" }
sift.reserved = 1
dig.sifting = true
dig.openingCount = config.openingBatches
now = session.run.endsAt
session.advance(true)
assert(not session.accepts())
shift.step()
local result = shift.result
assert(result.haul == 60 and ledger.ledger.haul == 60 and ledger.ledger.wallet == 10)
assert(dig.state.batches.complete == nil and dig.state.batches.prior.status == "sold")
assert(dig.state.batches.raw == nil and dig.state.batches.processing == nil)
assert(sift.pending == nil and sift.reserved == 0 and next(sift.outputs) == nil)
assert(player:GetAttribute("CarriedBatches") == 0 and player:GetAttribute("CompletedFinds") == 0)
assert(player:GetAttribute("ReservedOutput") == 0 and player:GetAttribute("CrewHaul") == 60)
assert(status:GetAttribute("ResultHaul") == 60 and status:GetAttribute("Phase") == "results")
shift.step()
assert(shift.result == result and ledger.ledger.haul == 60)
assert(economy.request(player, "sell", game.HttpService:GenerateGUID(false)) == "wrong_phase")
assert(sifting.request(player, "start") == "wrong_phase")
assert(digging.request(player, "start") ~= "started")
assert(shift.request(player, "replay", {}, 79) == "invalid_request")
assert(shift.request(player, "result", session.run.id) == "invalid_request")
assert(shift.request(player, "replay", "old") == "stale_run")
assert(shift.result == result)
print(
	"[END-1/2 fixture] cutoff discards unsold $19 without payment: haul=$60 cash=$10; raw/processing discarded; results match ledger; repeat/forged requests add nothing"
)
local oldId = session.run.id
assert(shift.request(player, "replay", oldId) == "replayed")
assert(shift.request(player, "replay", oldId) == "stale_run")
assert(session.run.id ~= oldId and session.run.phase == "waiting" and not session.accepts())
assert(session.run.startedAt == nil and session.run.endsAt == nil and shift.result == nil)
local fresh = digging.get(player)
local freshSift, freshEconomy = sifting.get(player), economy.get(player)
assert(fresh ~= dig and freshSift ~= sift and freshEconomy ~= ledger)
assert(next(fresh.state.batches) == nil and next(fresh.state.lastDigAt) == nil)
assert(fresh.openingCount == 0 and fresh.pending == nil and not fresh.sifting)
assert(fresh.digSeconds == config.digSeconds)
assert(next(freshSift.outputs) == nil and freshSift.reserved == 0 and freshSift.pending == nil)
assert(freshEconomy.ledger.wallet == 0 and freshEconomy.ledger.haul == 0)
assert(next(freshEconomy.ledger.owned) == nil and next(freshEconomy.ledger.requests) == nil)
assert(next(freshEconomy.ledger.finds) == nil)
assert(player:GetAttribute("OpeningCount") == 0 and player:GetAttribute("RunCash") == 0)
assert(player:GetAttribute("CrewHaul") == 0 and not player:GetAttribute("ShovelUpgraded"))
assert(player:GetAttribute("DigSeconds") == config.digSeconds)
assert(status:GetAttribute("ResultHaul") == nil and status:GetAttribute("RunId") == session.run.id)
session.advance(true)
now += config.readySeconds
session.advance(true)
assert(session.accepts() and session.run.endsAt - session.run.startedAt == config.shiftSeconds)
assert(fresh.start({
	id = "new-opening",
	source = "Bank",
	digger = tostring(player.UserId),
	now = now,
	distance = 0,
	multiplier = config.ordinaryMultiplier,
}, "running") == "started")
assert(fresh.step(now + config.digSeconds, 0, "running", "Bank") == "created")
assert(
	fresh.openingCount == 1
		and fresh.state.batches["new-opening"].outcome.baseValue == config.openingValue
)
now = session.run.endsAt
session.advance(true)
shift.step()
assert(shift.result.haul == 0 and next(fresh.state.batches) == nil)
assert(shift.request(player, "replay", oldId) == "stale_run")
assert(shift.request(player, "replay", session.run.id) == "replayed")
print(
	"[END-3 fixture] replay reconstructs all controllers, clears balances/ownership/IDs/inventory/counters, restores starter dig rate and guaranteed opening; second run settles at $0; stale first-run replay rejected"
)
economy.remove(player)
sifting.remove(player)
digging.remove(player)
status:Destroy()
for key, value in originalAttributes do
	player:SetAttribute(key, value)
end
player.Character:PivotTo(originalPivot)
print("[END fixtures] all assertions passed; live attributes and position restored")
