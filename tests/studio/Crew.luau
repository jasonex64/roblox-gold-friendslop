--!strict
-- Connector-run server fixture: one real avatar and three simulated recipients.
-- This is server integration evidence, not a human four-client playtest.
local Players = game:GetService("Players")
local player = Players:GetPlayers()[1]
assert(player and #Players:GetPlayers() == 1, "CREW fixture needs one Studio player")
local server = game.ServerScriptService.Server
local config = require(game.ReplicatedStorage.Shared.Config)
local attributes, pivot = player:GetAttributes(), player.Character:GetPivot()
local now = 0
local session = require(server.Session).new(config, function()
	return now
end, "crew-fixture")
local camp = workspace.RiverCamp
local deliveries = {}
local remote = {
	FireClient = function(_, target, code, amount, total)
		table.insert(
			deliveries,
			{ id = tostring(target.UserId), code = code, amount = amount, total = total }
		)
	end,
}
local digging = require(server.Digging).new(config, session, camp)
local sifting = require(server.Sifting).new(config, session, camp, digging, remote)
local economy = require(server.Economy).new(config, session, camp, digging, sifting, remote)
local actors = { player }
for index = 1, 3 do
	local actor = { UserId = "fixture-" .. index, attributes = {} }
	function actor:SetAttribute(key, value)
		self.attributes[key] = value
	end
	table.insert(actors, actor)
end
for _, actor in actors do
	session.crew.join(tostring(actor.UserId))
	digging.add(actor)
	sifting.add(actor)
	economy.add(actor)
end
local status = Instance.new("Folder")
local shift = require(server.Shift).new(session, digging, sifting, economy, status, camp.CampSpawn)
session.advance(true)
now = config.readySeconds
session.advance(true)
shift.publish()
local function stand(pad)
	player.Character:PivotTo(CFrame.new(pad.Position + Vector3.new(0, 4, 0)))
	task.wait(0.4)
end
local function id()
	return game.HttpService:GenerateGUID(false)
end
local function find(key, value)
	digging.get(player).state.batches[key] = { id = key, status = "completed", active = false }
	sifting.get(player).outputs[key] = { id = key, value = value }
end
stand(camp.Buyer)
find("first", 200)
local request = id()
local result, share, total = economy.request(player, "sell", request)
assert(result == "sold" and share == 50 and total == 200)
for _, actor in actors do
	assert(economy.get(actor).ledger.wallet == 50)
end
assert(session.crew.haul == 200 and player:GetAttribute("CrewHaul") == 200)
assert(economy.request(player, "sell", request) == "duplicate_request")
assert(economy.request(player, "sell", id(), 999) == "invalid_request")
local notifications = 0
for _, message in deliveries do
	if message.code == "sold" or message.code == "crew_sale" then
		assert(message.amount == 50 and message.total == 200)
		notifications += 1
	end
end
assert(notifications == 4)
stand(camp.Camp)
assert(economy.request(player, "buy", id()) == "purchased")
assert(economy.get(player).ledger.wallet == 0 and session.crew.haul == 200)
print(
	"[CREW server] $200 sale -> four $50 wallets; four correct notifications; duplicate/forged requests rejected; purchase preserves haul"
)
now += config.afkSeconds
shift.publish()
assert(player:GetAttribute("CashShareStatus") == "warning")
now += config.afkWarningSeconds
shift.publish()
assert(player:GetAttribute("CashShareStatus") == "paused")
stand(camp.Buyer)
assert(economy.request(player, "sell", id()) == "nothing_to_sell")
assert(session.crew.eligibility(tostring(player.UserId), now) == "paused")
find("resume", 57)
result, share, total = economy.request(player, "sell", id())
assert(result == "sold" and share == 57 and total == 57)
for index = 2, #actors do
	assert(economy.get(actors[index]).ledger.wallet == 50)
end
assert(session.crew.eligibility(tostring(player.UserId), now) == "active")
session.activity(actors[2])
find("odd", 1)
economy.request(player, "sell", id())
local combined = economy.get(player).ledger.wallet + economy.get(actors[2]).ledger.wallet
assert(combined == 108 and session.crew.haul == 258)
print(
	"[CREW server] exact 60/70-second warning/pause; empty sale stays paused; real sale resumes seller before payout; odd dollar conserved"
)
session.crew.leave(tostring(actors[2].UserId))
session.crew.leave(tostring(player.UserId))
session.crew.join(tostring(player.UserId))
assert(not session.acceptsPlayer(player))
find("unsold", 19)
assert(economy.request(player, "sell", id()) == "wrong_phase")
assert(economy.request(player, "buy", id()) == "wrong_phase")
assert(sifting.request(player, "start") == "wrong_phase")
assert(digging.request(player, "start") ~= "started")
shift.publish()
assert(player:GetAttribute("CrewMember") == false)
now = session.run.endsAt
session.advance(true)
shift.step()
assert(shift.result.haul == 258 and next(sifting.get(player).outputs) == nil)
assert(shift.request(player, "replay", session.run.id) == "waiting_for_crew")
assert(shift.request(player, "replay", "stale") == "stale_run")
assert(shift.request(player, "replay", session.run.id, true) == "invalid_request")
session.crew.vote(tostring(actors[3].UserId))
shift.step()
assert(session.run.phase == "results")
session.crew.leave(tostring(actors[4].UserId))
local oldRun = session.run.id
shift.step()
assert(session.run.id ~= oldRun and session.run.phase == "waiting")
assert(session.crew.haul == 0 and economy.get(player).ledger.wallet == 0)
assert(player:GetAttribute("CrewMember") == true)
assert(next(economy.get(player).ledger.owned) == nil)
print(
	"[CREW server] late/reconnected player blocked on production/shop/replay; departed sales retain $258 haul; unsold $19 discarded; remaining vote+departure releases replay and resets cash"
)
for _, actor in actors do
	economy.remove(actor)
	sifting.remove(actor)
	digging.remove(actor)
end
status:Destroy()
for key in player:GetAttributes() do
	if attributes[key] == nil then
		player:SetAttribute(key, nil)
	end
end
for key, value in attributes do
	player:SetAttribute(key, value)
end
player.Character:PivotTo(pivot)
print("[CREW server] PASS; one real avatar + three simulated recipients; live state restored")
