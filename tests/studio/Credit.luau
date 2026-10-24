--!strict
-- Run through Studio MCP in Server during Play. One real avatar, isolated controllers
-- and an injected shift clock; digging and sifting use the real handlers and timers.
local players = game.Players:GetPlayers()
assert(#players > 0, "CREDIT fixture needs a player")
local server, camp = game.ServerScriptService.Server, workspace.RiverCamp
local config = require(game.ReplicatedStorage.Shared.Config)
local now = 0
local session = require(server.Session).new(config, function()
	return now
end, "credit-fixture")
local remote = { FireClient = function() end }
local digging = require(server.Digging).new(config, session, camp)
local sifting = require(server.Sifting).new(config, session, camp, digging, remote)
local economy = require(server.Economy).new(config, session, camp, digging, sifting, remote)
local machinery = require(server.Machinery).new(session, camp, digging, economy, sifting)
local status = Instance.new("Folder")
local shift = require(server.Shift).new(session, digging, sifting, economy, status, camp.CampSpawn)
local a = players[1]
local saved = { attributes = a:GetAttributes(), pivot = a.Character:GetPivot() }
session.crew.join(tostring(a.UserId))
digging.add(a)
sifting.add(a)
economy.add(a)
session.advance(true)
now = config.readySeconds
session.advance(true)
local function guid()
	return game.HttpService:GenerateGUID(false)
end
local function stand(pad)
	a.Character:PivotTo(CFrame.new(pad.Position + Vector3.new(0, 4, 0)))
	task.wait(0.5)
end
local humanoid = a.Character:FindFirstChildOfClass("Humanoid")
assert(humanoid, "CREDIT: avatar needs a Humanoid")
local function equip(name)
	humanoid:UnequipTools()
	local tool = a.Backpack:FindFirstChild(name)
	assert(tool, "CREDIT: avatar needs a " .. name)
	humanoid:EquipTool(tool)
end
local function dig()
	equip("Shovel")
	stand(camp.Bank)
	local started = digging.request(a, "start")
	assert(started == "started", "CREDIT: dig did not start: " .. tostring(started))
	local deadline = os.clock() + config.digSeconds + 3
	repeat
		task.wait(0.1)
		digging.step()
	until digging.get(a).pending == nil or os.clock() > deadline
	assert(digging.get(a).pending == nil, "CREDIT: dig did not finish")
end
local function expect(got, want, label)
	assert(got == want, "CREDIT: " .. label .. " returned " .. tostring(got))
end
local function credit()
	local rows = session.creditRows()
	assert(#rows == 1 and rows[1].name == a.DisplayName, "CREDIT: expected one row for the avatar")
	return rows[1]
end

-- Dig and sift through the real handlers; misses still finish the sift.
dig()
assert(credit().dug == 1, "CREDIT: dig not recorded")
equip("Pan")
stand(camp.River)
local sifted = sifting.request(a, "start")
assert(sifted == "started", "CREDIT: sift did not start: " .. tostring(sifted))
local deadline = os.clock() + config.siftSeconds + 5
repeat
	task.wait(0.1)
	sifting.step()
until a:GetAttribute("CompletedFinds") == 1 or os.clock() > deadline
assert(credit().processed == 1, "CREDIT: sift not recorded")
humanoid:UnequipTools()

stand(camp.Buyer)
expect(economy.request(a, "sell", guid()), "sold", "sale")
local sold = session.crew.haul
-- All-miss sifts can be worth $0, and a $0 sale records no credit.
assert(credit().sold == sold, "CREDIT: sale value not recorded")
expect(economy.request(a, "sell", guid()), "nothing_to_sell", "empty sale")
assert(credit().sold == sold, "CREDIT: empty sale recorded credit")

local price = session.machine.settings.price
economy.get(a).ledger.wallet = price -- Isolated fixture funds, not a live player grant.
stand(camp.Sluice)
expect(machinery.request(a, "contribute", session.run.id, guid(), price), "sluice_built", "funding")
assert(credit().funded == price, "CREDIT: funding not recorded")
dig()
stand(camp.Sluice)
local moved, deposited = machinery.request(a, "transfer", session.run.id, guid())
expect(moved, "sluice_transferred", "transfer in")
assert(deposited == 1 and credit().loaded == 1 and credit().dug == 2, "CREDIT: load not recorded")
-- Collecting finished finds deposits no dirt, so it adds no sluice credit.
session.machine.step(now, true) -- feeds the queued dirt into a lane
now += config.sluiceProcessSeconds
assert(session.machine.step(now, true) == 1, "CREDIT: sluice did not finish the dirt")
local collected
moved, deposited, collected = machinery.request(a, "transfer", session.run.id, guid())
expect(moved, "sluice_transferred", "transfer out")
assert(
	deposited == 0 and collected == 1 and credit().loaded == 1,
	"CREDIT: collection counted as load"
)
local ok = pcall(function()
	session.record(a, "dug", 1, "fixture:dup")
	session.record(a, "dug", 1, "fixture:dup")
end)
assert(not ok, "CREDIT: duplicate event did not error")

now = session.run.endsAt
session.advance(true)
shift.step()
local rows = game.HttpService:JSONDecode(status:GetAttribute("ResultCredits"))
assert(#rows == 1 and rows[1].name == a.DisplayName, "CREDIT: results row missing")
assert(rows[1].sold == shift.result.haul, "CREDIT: sold total does not match Crew Haul")
print(
	string.format(
		"[CREDIT fixture] results row: dug %d, sifted %d, sluice %d, sold $%d (Crew Haul $%d), funded $%d",
		rows[1].dug,
		rows[1].processed,
		rows[1].loaded,
		rows[1].sold,
		shift.result.haul,
		rows[1].funded
	)
)
shift.request(a, "replay", session.run.id)
assert(session.run.phase == "waiting" and #session.creditRows() == 0, "CREDIT: replay kept credit")
assert(status:GetAttribute("ResultCredits") == nil, "CREDIT: replay kept results credits")
print("[CREDIT fixture] duplicate event errors; replay starts an empty credit record")

economy.remove(a)
sifting.remove(a)
digging.remove(a)
for key, value in saved.attributes do
	a:SetAttribute(key, value)
end
a.Character:PivotTo(saved.pivot)
status:Destroy()
print("[CREDIT fixture] PASS; isolated fixture restored avatar attributes/position")
