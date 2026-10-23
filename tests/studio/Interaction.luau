--!strict
-- Run in Studio Server. Isolated controllers; restore live attributes/position.
local player = game.Players:GetPlayers()[1]
assert(player, "UX fixture requires a player")
local server = game.ServerScriptService.Server
local config = require(game.ReplicatedStorage.Shared.Config)
local attributes, pivot = player:GetAttributes(), player.Character:GetPivot()
local now = 0
local session = require(server.Session).new(config, function()
	return now
end, "ux-fixture")
session.crew.join(tostring(player.UserId))
local camp = workspace.RiverCamp
local remote = { FireClient = function() end }
local digging = require(server.Digging).new(config, session, camp)
local sifting = require(server.Sifting).new(config, session, camp, digging, remote)
local economy = require(server.Economy).new(config, session, camp, digging, sifting, remote)
digging.add(player)
sifting.add(player)
economy.add(player)
local ui = require(server.Interaction).new(config, session, camp, digging, sifting, economy)
local function stand(pad)
	player.Character:PivotTo(CFrame.new(pad.Position + Vector3.new(0, 4, 0)))
	task.wait(0.4)
end
local function check(action, expected)
	local actual = ui.request(player, action)
	assert(
		actual == expected,
		"UX " .. action .. ": expected " .. expected .. ", got " .. tostring(actual)
	)
end
check("dig", "wrong_phase")
assert(ui.request(player, {}, 10) == "invalid_request")
assert(ui.request(player, "sell", 100000) == "invalid_request")
session.advance(true)
now = config.readySeconds
session.advance(true)
stand(camp.Camp)
check("buy", "unaffordable")
check("sell", "stand_at_buyer")
check("dig", "out_of_range")
stand(camp.River)
check("sift", "no_dirt")
local dig, sift, econ = digging.get(player), sifting.get(player), economy.get(player)
for index = 1, config.outputCapacity do
	local id = "complete-" .. index
	dig.state.batches[id] = { id = id, status = "completed", active = false }
	sift.outputs[id] = { id = id, value = config.openingValue }
end
check("sift", "full_output")
ui.publish(player)
assert(
	player:GetAttribute("HudAction") == "none"
		and string.find(player:GetAttribute("HudHint"), "Find bag full", 1, true)
)
stand(camp.Buyer)
ui.publish(player)
assert(player:GetAttribute("HudAction") == "sell")
check("sell", "sold")
check("sell", "nothing_to_sell")
local total = config.outputCapacity * config.openingValue
assert(econ.ledger.haul == total and econ.ledger.wallet == total)
stand(camp.Camp)
ui.publish(player)
assert(player:GetAttribute("HudAction") == "buy")
check("buy", "purchased")
check("buy", "already_owned")
assert(econ.ledger.wallet == total - config.shovelUpgradePrice and econ.ledger.haul == total)
stand(camp.Bank)
check("dig", "started")
ui.publish(player)
assert(player:GetAttribute("Digging") and player:GetAttribute("HudAction") == "cancel")
check("sift", "busy_digging")
check("cancel", "cancelled")
assert(dig.pending == nil)
for index = 1, config.bucketBatches do
	dig.state.batches["raw-" .. index] =
		{ id = "raw-" .. index, status = "queued", digger = tostring(player.UserId) }
end
check("dig", "full_capacity")
ui.publish(player)
assert(string.find(player:GetAttribute("HudHint"), "Bucket full", 1, true))
now = session.run.endsAt
session.advance(true)
check("sell", "wrong_phase")
check("buy", "wrong_phase")
check("sift", "wrong_phase")
ui.publish(player)
assert(player:GetAttribute("HudAction") == "none")
economy.remove(player)
sifting.remove(player)
digging.remove(player)
for key, value in attributes do
	player:SetAttribute(key, value)
end
player.Character:PivotTo(pivot)
print(
	"[UX-1/2 fixture] forged/closed/wrong-location/empty/full/poor/already-owned requests reject; single sale/purchase correct; busy/cancel and server guidance correct; live attributes restored"
)
