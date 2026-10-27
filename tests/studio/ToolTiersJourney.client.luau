--!strict
-- Studio MCP Client during a fresh solo Play. Real remotes, earned cash, no grants.
local player, rs = game.Players.LocalPlayer, game.ReplicatedStorage
local config, status = require(rs.Shared.Config), rs.RunStatus
local hud = player.PlayerGui.GoldHUD.Root
hud.Guide.Visible = false
local function stand(pad)
	player.Character:PivotTo(CFrame.new(pad.Position + Vector3.new(0, 4, 0)))
	task.wait(0.5)
end
local function waitFor(predicate, seconds, label)
	local deadline = os.clock() + seconds
	while not predicate() do
		assert(os.clock() < deadline, "TIERS journey timed out: " .. label)
		task.wait(0.05)
	end
end
local scheduled = {}
local connection = rs.SiftRequest.OnClientEvent:Connect(function(_, view)
	if view and not view.graded then
		local key = view.id .. ":" .. view.index
		if not scheduled[key] then
			scheduled[key] = true
			local delay = view.startedAt
				+ (view.zoneStart + view.zoneWidth / 2) * view.duration
				- workspace:GetServerTimeNow()
			task.delay(math.max(0, delay), function()
				rs.SiftRequest:FireServer("press", view.id, view.index)
			end)
		end
	end
end)
local ok, failure = xpcall(function()
	local purchases = {
		{ "shovel-2", config.shovelUpgradePrice, "ShovelUpgraded", "Upgrade" },
		{ "pan-2", config.panTierTwoPrice, "PanUpgraded", "PanUpgrade" },
		{ "shovel-3", config.shovelTierThreePrice, "ShovelTierThree", "Upgrade" },
		{ "pan-3", config.panTierThreePrice, "PanTierThree", "PanUpgrade" },
	}
	for _, purchase in purchases do
		local item, price, attribute, buttonName = table.unpack(purchase)
		assert(not player:GetAttribute(attribute), "TIERS journey needs fresh ownership")
		local deadline = os.clock() + 200
		while player:GetAttribute("RunCash") < price do
			assert(
				status:GetAttribute("Phase") == "running" and os.clock() < deadline,
				"TIERS journey did not earn price"
			)
			stand(workspace.RiverCamp.Bank)
			rs.ActionRequest:FireServer("dig")
			waitFor(function()
				return player:GetAttribute("CarriedBatches") == 1
			end, config.digSeconds + 3, "dig")
			stand(workspace.RiverCamp.River)
			rs.ActionRequest:FireServer("sift")
			waitFor(function()
				return player:GetAttribute("CompletedFinds") == 1
			end, config.siftSeconds + 3, "sift")
			stand(workspace.RiverCamp.Buyer)
			rs.ActionRequest:FireServer("sell")
			waitFor(function()
				return player:GetAttribute("CompletedFinds") == 0
			end, 3, "sale")
		end
		stand(workspace.RiverCamp.Camp)
		local button = hud.ActionDock[buttonName]
		assert(
			button.Visible and string.find(button.Caption.Text, tostring(price), 1, true),
			"TIERS missing shop offer"
		)
		local cash, haul = player:GetAttribute("RunCash"), player:GetAttribute("CrewHaul")
		local id = game.HttpService:GenerateGUID(false)
		rs.EconomyRequest:FireServer("buy", id, item)
		waitFor(function()
			return player:GetAttribute(attribute) == true
		end, 3, "purchase " .. item)
		assert(player:GetAttribute("RunCash") == cash - price, "TIERS wrong price")
		assert(player:GetAttribute("CrewHaul") == haul, "TIERS spent haul")
		rs.EconomyRequest:FireServer("buy", id, item)
		task.wait(0.2)
		assert(player:GetAttribute("RunCash") == cash - price, "TIERS duplicate charge")
		print(
			"[TIERS live] earned and bought "
				.. item
				.. "; exact personal charge, unchanged Crew Haul, duplicate rejected"
		)
	end
	assert(hud.ActionDock.Upgrade.Caption.Text == "Shovel max tier")
	assert(hud.ActionDock.PanUpgrade.Caption.Text == "Pan max tier")
	assert(player:GetAttribute("DigSeconds") == config.shovelTierThreeSeconds)
	print(
		"[TIERS live] PASS; four tiers earned through real dig/sift/sales and purchased through live EconomyRequest; both shop buttons show max tier"
	)
end, debug.traceback)
connection:Disconnect()
assert(ok, failure)
