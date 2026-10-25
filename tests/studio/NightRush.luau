--!strict
-- EXP-002: isolated controllers and injected time, real solo/crew Studio avatars.
local players = game.Players:GetPlayers()
assert(#players > 0, "NIGHT fixture needs players")
local server, camp = game.ServerScriptService.Server, workspace.RiverCamp
local config = require(game.ReplicatedStorage.Shared.Config)
local now = 0
local session = require(server.Session).new(config, function()
	return now
end, "night-fixture")
local remote = { FireClient = function() end }
local digging = require(server.Digging).new(config, session, camp)
local sifting = require(server.Sifting).new(config, session, camp, digging, remote)
local economy = require(server.Economy).new(config, session, camp, digging, sifting, remote)
local interaction =
	require(server.Interaction).new(config, session, camp, digging, sifting, economy)
local status = Instance.new("Folder")
local shift = require(server.Shift).new(session, digging, sifting, economy, status, camp.CampSpawn)
local saved, rich = {}, camp[config.richSource]
local sign = rich.BillboardGui.TextLabel.Text
assert(math.abs((rich.Position - camp.Camp.Position).Magnitude - config.richBankDistance) < 0.01)
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
local function stand(p, pad, offset)
	p.Character:PivotTo(CFrame.new(pad.Position + Vector3.new(offset, 4, 0)))
	task.wait(0.5)
end
local function time(elapsed)
	now = started + elapsed
	shift.publish()
end
stand(a, rich, -5)
interaction.publish(a)
assert(a:GetAttribute("HudAction") == "none")
assert(interaction.request(a, "dig") == "rich_bank_closed")
time(config.nightStart - 0.001)
assert(interaction.request(a, "dig") == "rich_bank_closed")
time(config.nightStart)
assert(status:GetAttribute("ShiftPhase") == "night")
assert(status:GetAttribute("BankSeconds") == config.dawnStart - config.nightStart)
assert(interaction.request(a, "dig") == "started")
now = digging.get(a).pending.due
digging.step()
local item
for _, batch in digging.get(a).state.batches do
	item = batch
end
assert(item and item.outcome.sourceMultiplier == config.richMultiplier)
-- Pending new work at dawn is allowed to finish; only new digs are closed.
time(config.dawnStart - config.digSeconds / 2)
assert(interaction.request(a, "dig") == "started")
local due = digging.get(a).pending.due
time(config.dawnStart)
assert(status:GetAttribute("ShiftPhase") == "dawn")
assert(interaction.request(a, "dig") == "rich_bank_closed")
now = due
digging.step()
assert(a:GetAttribute("CarriedBatches") == 2)
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
assert(
	session.bin.transfer(
		tostring(b.UserId),
		digging.get(b),
		"withdraw",
		session.run.id,
		session.bin.revision,
		"all",
		true
	) == "withdrawn"
)
stand(b, camp.River, 5)
assert(interaction.request(b, "sift") == "started")
now = sifting.get(b).pending.endsAt
sifting.step()
local find
for _, value in sifting.get(b).outputs do
	find = value
end
assert(
	find
		and find.outcome.sourceMultiplier == config.richMultiplier
		and find.digger == tostring(a.UserId)
)
stand(b, camp.Buyer, 5)
assert(economy.request(b, "sell", game.HttpService:GenerateGUID(false)) == "sold")
local sum = 0
for _, p in players do
	sum += economy.get(p).ledger.wallet
end
assert(sum == find.value and session.crew.haul == find.value)
print(
	string.format(
		"[NIGHT fixture] %d actual avatars: rich gate opens at night/closes at dawn; in-flight dig and teammate-held rich dirt retain bonus; shop shares conserve $%d",
		#players,
		find.value
	)
)
-- The remaining rich batch crosses the rush during its first sweep.
stand(b, camp.River, 5)
time(config.rushStart - 1)
assert(interaction.request(b, "sift") == "started")
local pending = sifting.get(b).pending
assert(pending.duration == config.siftSweepSeconds)
time(config.rushStart)
sifting.step()
assert(pending.duration == config.siftSweepSeconds)
assert(status:GetAttribute("ShiftPhase") == "rush" and status:GetAttribute("RushSeconds") == 0)
now = pending.checks[2].startedAt
sifting.step()
assert(pending.index == 2 and pending.duration == config.rushSiftSweepSeconds)
now = pending.endsAt
sifting.step()
assert(sifting.get(b).pending == nil)
stand(a, camp.Bank, -5)
assert(interaction.request(a, "dig") == "started")
local requestAt = now
local dig = digging.get(a)
assert(math.abs(dig.pending.due - requestAt - config.digSeconds / (1 + config.rushSpeedup)) < 1e-6)
now = dig.pending.due
digging.step()
assert(a:GetAttribute("CarriedBatches") == 1)
print(
	"[NIGHT fixture] active sweep keeps normal speed across rush; next sweep uses approved short duration; rush dig uses Timeline.finishAt"
)
time(config.shiftSeconds)
assert(interaction.request(a, "dig") == "wrong_phase")
assert(economy.request(b, "sell", game.HttpService:GenerateGUID(false)) == "wrong_phase")
session.advance(true)
shift.step()
assert(shift.result.haul == find.value and next(sifting.get(b).outputs) == nil)
local old = session.run.id
for _, p in players do
	shift.request(p, "replay", old)
end
assert(session.run.phase == "waiting" and status:GetAttribute("ShiftPhase") == "day")
session.advance(true)
now += config.readySeconds
session.advance(true)
stand(a, rich, -5)
assert(interaction.request(a, "dig") == "rich_bank_closed")
assert(economy.get(a).ledger.wallet == 0)
print(
	"[NIGHT fixture] exact bell rejects production/sales; unsold output discarded without payment; replay resets day, bank gate and wallets"
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
	p.Character.Humanoid:UnequipTools()
	p.Character:PivotTo(saved[p].pivot)
end
rich.BillboardGui.TextLabel.Text = sign
status:Destroy()
print("[NIGHT fixture] PASS; isolated state, attributes, positions and bank sign restored")
