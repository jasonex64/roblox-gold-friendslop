--!strict
-- Studio MCP Server, Play: real handlers/avatar with isolated ledger and clock.
local player = game.Players:GetPlayers()[1]
assert(player and player.Character, "TIERS needs one live avatar")
local server, camp = game.ServerScriptService.Server, workspace.RiverCamp
local config = require(game.ReplicatedStorage.Shared.Config)
local now = 0
local session = require(server.Session).new(config, function()
	return now
end, "tool-tiers-fixture")
local remote = { FireClient = function() end }
local digging = require(server.Digging).new(config, session, camp)
local sifting = require(server.Sifting).new(config, session, camp, digging, remote)
local economy = require(server.Economy).new(config, session, camp, digging, sifting, remote)
local status = Instance.new("Folder")
local shift = require(server.Shift).new(session, digging, sifting, economy, status, camp.CampSpawn)
local saved = {
	attributes = player:GetAttributes(),
	pivot = player.Character:GetPivot(),
	sign = camp.RichBank.BillboardGui.TextLabel.Text,
}
local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
assert(humanoid, "TIERS needs Humanoid")
local function guid()
	return game.HttpService:GenerateGUID(false)
end
local function stand(pad)
	player.Character:PivotTo(CFrame.new(pad.Position + Vector3.new(0, 4, 0)))
	task.wait(0.5)
end
local function equip(name)
	humanoid:UnequipTools()
	local tool = player.Backpack:FindFirstChild(name)
	assert(tool, "TIERS missing tool " .. name)
	humanoid:EquipTool(tool)
end
session.crew.join(tostring(player.UserId))
digging.add(player)
sifting.add(player)
economy.add(player)
session.advance(true)
now = config.readySeconds
session.advance(true)
local function expect(got, want)
	assert(got == want, "TIERS expected " .. tostring(want) .. ", got " .. tostring(got))
end
local ok, failure = xpcall(function()
	stand(camp.Camp)
	local econ = economy.get(player)
	local budget = config.shovelUpgradePrice
		+ config.shovelTierThreePrice
		+ config.panTierTwoPrice
		+ config.panTierThreePrice
	econ.ledger.wallet = budget -- Isolated fixture only; live journey earns its money.
	local haul = session.crew.haul
	for _, item in { "shovel-3", "pan-3" } do
		expect(economy.request(player, "buy", guid(), item), "missing_prerequisite")
	end
	for _, item in { {}, false, "pan-4", 123 } do
		expect(economy.request(player, "buy", guid(), item), "invalid_request")
	end
	expect(economy.request(player, "buy", guid(), "pan-2", "extra"), "invalid_request")
	expect(economy.request(player, "sell", guid(), "pan-2"), "invalid_request")
	expect(econ.ledger.wallet, budget)
	for _, item in { "shovel-2", "shovel-3", "pan-2", "pan-3" } do
		stand(camp.Camp)
		local id = guid()
		expect(economy.request(player, "buy", id, item), "purchased")
		local cash = econ.ledger.wallet
		expect(economy.request(player, "buy", id, item), "duplicate_request")
		expect(economy.request(player, "buy", guid(), item), "already_owned")
		expect(econ.ledger.wallet, cash)
		expect(session.crew.haul, haul)
		if string.sub(item, 1, 6) == "shovel" then
			local seconds = if item == "shovel-2"
				then config.upgradedDigSeconds
				else config.shovelTierThreeSeconds
			expect(player:GetAttribute("DigSeconds"), seconds)
			equip("Shovel")
			stand(camp.Bank)
			expect(digging.request(player, "start"), "started")
			expect(digging.get(player).pending.due, now + seconds)
			now += seconds
			digging.step()
			expect(digging.get(player).pending, nil)
		else
			local upgrades = if item == "pan-2" then 1 else 2
			equip("Pan")
			stand(camp.River)
			expect(sifting.request(player, "start"), "started")
			local check = sifting.get(player).pending.checks[1]
			expect(
				check.perfectWidth,
				config.siftPerfectWidth * (1 + upgrades * config.siftUpgradeWidth)
			)
			expect(
				check.zoneWidth,
				(config.siftPerfectWidth + 2 * config.siftGoodWidth)
					* (1 + upgrades * config.siftUpgradeWidth)
			)
			sifting.cancel(player)
		end
	end
	expect(econ.ledger.wallet, 0)
	stand(camp.Bank)
	expect(economy.request(player, "buy", guid(), "pan-2"), "stand_at_camp")
	now = session.run.endsAt
	session.advance(true)
	shift.step()
	expect(economy.request(player, "buy", guid(), "pan-2"), "wrong_phase")
	expect(shift.request(player, "replay", session.run.id), "replayed")
	expect(next(economy.get(player).ledger.owned), nil)
	expect(economy.get(player).ledger.wallet, 0)
	expect(digging.get(player).digSeconds, config.digSeconds)
	expect(sifting.get(player).upgrades, 0)
	for _, attribute in { "ShovelUpgraded", "ShovelTierThree", "PanUpgraded", "PanTierThree" } do
		expect(player:GetAttribute(attribute), false)
	end
	print(
		"[TIERS fixture] ordered purchases and malformed/duplicate/out-of-order/location/cutoff rejection PASS; personal wallet spent, Crew Haul unchanged"
	)
	print(
		"[TIERS fixture] real dig deadlines 0.8/0.625s; real pan check widths 1.25x/1.5x; replay resets both tools, ownership and wallet PASS"
	)
end, debug.traceback)
humanoid:UnequipTools()
for key in player:GetAttributes() do
	if saved.attributes[key] == nil then
		player:SetAttribute(key, nil)
	end
end
for key, value in saved.attributes do
	player:SetAttribute(key, value)
end
player.Character:PivotTo(saved.pivot)
camp.RichBank.BillboardGui.TextLabel.Text = saved.sign
status:Destroy()
assert(ok, failure)
print("[TIERS fixture] PASS; isolated state and avatar restored")
