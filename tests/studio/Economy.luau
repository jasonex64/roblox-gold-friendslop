--!strict
-- Execute in Studio Server during play; isolated service inventories never alter
-- the live ledger. Restore player attributes after the fixture completes.
local player = game:GetService("Players"):GetPlayers()[1]
assert(player, "ECON fixtures require a player")
local Shared = game:GetService("ReplicatedStorage").Shared
local config = require(Shared.Config)
local Batch = require(Shared.Pure.Batch)
local Dig = require(Shared.Pure.Dig)
local originalAttributes = player:GetAttributes()
local dig = Dig.new(config, Batch, function()
	return { kind = "Gold", baseValue = 12, sourceMultiplier = 1 }
end)
local sift = { outputs = {} }
local running = true
local crew = require(Shared.Pure.Crew).new(config)
crew.join(tostring(player.UserId))
crew.start(0)
local replies = {}
local service = require(game.ServerScriptService.Server.Economy).new(
	config,
	{
		crew = crew,
		now = function()
			return 0
		end,
		activity = function()
			crew.activity(tostring(player.UserId), 0)
		end,
		-- T-027 contribution credit; this fixture does not check credit.
		record = function() end,
		acceptsPlayer = function()
			return running
		end,
	},
	workspace.RiverCamp,
	{
		get = function()
			return dig
		end,
	},
	{
		get = function()
			return sift
		end,
	},
	{
		FireClient = function(_, _, result)
			table.insert(replies, result)
		end,
	}
)
local function id()
	return game.HttpService:GenerateGUID(false)
end
local function stand(pad)
	player.Character:PivotTo(CFrame.new(pad.Position + Vector3.new(0, 4, 0)))
	task.wait(0.4)
end
service.add(player)
local economy = service.get(player)
stand(workspace.RiverCamp.Camp)
local purchaseId = id()
assert(service.request(player, "buy", purchaseId) == "unaffordable")
assert(economy.ledger.wallet == 0 and dig.digSeconds == config.digSeconds)
local before = economy.ledger
assert(service.request(player, "buy", id(), 0) == "invalid_request")
assert(service.request(player, "sell", {}) == "invalid_request")
assert(service.request(player, "setCash", id()) == "invalid_request")
assert(service.request(player, "sell", id()) == "stand_at_buyer")
assert(economy.ledger == before)
for index, value in { 13, 14, 25 } do
	local findId = tostring(index)
	dig.state.batches[findId] = { id = findId, status = "completed", active = false }
	sift.outputs[findId] = { id = findId, value = value }
end
stand(workspace.RiverCamp.Buyer)
local saleId = id()
running = false
assert(service.request(player, "sell", saleId) == "wrong_phase")
assert(economy.ledger == before and next(sift.outputs) ~= nil)
running = true
assert(service.request(player, "sell", saleId) == "sold")
assert(economy.ledger.wallet == 52 and economy.ledger.haul == 52)
assert(next(sift.outputs) == nil and dig.state.batches["1"].status == "sold")
assert(service.request(player, "sell", saleId) == "duplicate_request")
assert(service.request(player, "sell", id()) == "nothing_to_sell")
assert(economy.ledger.wallet == 52)
assert(service.request(player, "buy", id()) == "stand_at_camp")
print("[ECON-1 fixture] rejects forged/out-of-range/closed requests; three finds sell for $52 once")
stand(workspace.RiverCamp.Camp)
running = false
assert(service.request(player, "buy", purchaseId) == "wrong_phase")
running = true
assert(service.request(player, "buy", purchaseId) == "purchased")
assert(economy.ledger.wallet == 2 and economy.ledger.haul == 52 and dig.digSeconds == 0.8)
before = economy.ledger
assert(service.request(player, "buy", purchaseId) == "duplicate_request")
assert(service.request(player, "buy", id()) == "already_owned")
assert(service.request(player, "buy", saleId) == "duplicate_request")
assert(economy.ledger == before)
print(
	"[ECON-2/3 fixture] $50 purchase deducts once, preserves $52 haul, rejects replay and duplicate ownership"
)
service.remove(player)
for key, value in originalAttributes do
	player:SetAttribute(key, value)
end
print("[ECON fixtures] all assertions passed; live attributes restored")
