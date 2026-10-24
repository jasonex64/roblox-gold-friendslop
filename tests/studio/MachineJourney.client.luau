--!strict
-- Real solo gameplay/remotes/UI, no injected wallets, loot or clocks.
local player, rs = game.Players.LocalPlayer, game.ReplicatedStorage
local config, status = require(rs.Shared.Config), rs.RunStatus
local input = game:GetService("UserInputService"):CreateVirtualInput()
local function stand(pad)
	player.Character:PivotTo(CFrame.new(pad.Position + Vector3.new(0, 4, 0)))
	task.wait(0.5)
end
local function click(object)
	local point = object.AbsolutePosition
		+ object.AbsoluteSize / 2
		+ game:GetService("GuiService"):GetGuiInset()
	input:SendMousePosition(point)
	task.wait(0.1)
	input:SendMouseButton(point, Enum.UserInputType.MouseButton1, true, 0)
	input:SendMouseButton(point, Enum.UserInputType.MouseButton1, false, 0)
	task.wait(0.3)
end
local function keyE()
	input:SendKey(true, Enum.KeyCode.E, false)
	input:SendKey(false, Enum.KeyCode.E, false)
	task.wait(0.2)
end
local deadline = os.clock() + 240
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
local batches = 0
while player:GetAttribute("RunCash") < status:GetAttribute("SluicePrice") do
	assert(
		os.clock() < deadline and status:GetAttribute("Phase") == "running",
		"MACHINE journey did not earn price before deadline"
	)
	stand(workspace.RiverCamp.Bank)
	rs.ActionRequest:FireServer("dig")
	task.wait(config.digSeconds + 0.2)
	assert(player:GetAttribute("CarriedBatches") == 1)
	stand(workspace.RiverCamp.River)
	rs.ActionRequest:FireServer("sift")
	task.wait(0.2)
	local endAt = os.clock() + config.siftSeconds + 1
	while player:GetAttribute("CompletedFinds") == 0 do
		assert(os.clock() < endAt, "MACHINE journey sift failed")
		task.wait(0.1)
	end
	stand(workspace.RiverCamp.Buyer)
	rs.ActionRequest:FireServer("sell")
	task.wait(0.2)
	batches += 1
end
connection:Disconnect()
stand(workspace.RiverCamp.Sluice)
click(player.PlayerGui.GoldHUD.Root.ActionDock.SluiceStats)
local panel = player.PlayerGui.GoldHUD.Root.SluicePanel
assert(panel.Visible and panel.ContributeAll.Visible)
local cash, haul = player:GetAttribute("RunCash"), player:GetAttribute("CrewHaul")
click(panel.ContributeAll)
assert(status:GetAttribute("SluiceBuilt"))
assert(player:GetAttribute("RunCash") == cash - status:GetAttribute("SluicePrice"))
assert(player:GetAttribute("CrewHaul") == haul)
stand(workspace.RiverCamp.Bank)
rs.ActionRequest:FireServer("dig")
task.wait(config.digSeconds + 0.2)
assert(player:GetAttribute("CarriedBatches") == 1)
stand(workspace.RiverCamp.Sluice)
click(player.PlayerGui.GoldHUD.Root.ActionDock.SluiceStats)
click(panel.Close)
keyE()
assert(player:GetAttribute("CarriedBatches") == 0)
task.wait(config.sluiceProcessSeconds + 0.3)
assert(status:GetAttribute("SluiceOutput") == 1)
assert(player:GetAttribute("CompletedFinds") == 0)
click(player.PlayerGui.GoldHUD.Root.ActionDock.Primary)
assert(status:GetAttribute("SluiceOutput") == 0)
assert(player:GetAttribute("CompletedFinds") == 1)
stand(workspace.RiverCamp.Buyer)
assert(player:GetAttribute("HudAction") == "sell")
local before = player:GetAttribute("RunCash")
rs.ActionRequest:FireServer("sell")
task.wait(0.3)
assert(status:GetAttribute("SluiceOutput") == 0)
assert(player:GetAttribute("RunCash") > before)
print(
	string.format(
		"[MACHINE live UI] earned funding from %d real dig/sift/sales; All I Can built sluice without reducing haul; quick transfer queued bucket dirt; four-second output collected into Backpack then sold once",
		batches
	)
)
stand(workspace.RiverCamp.Sluice)
click(player.PlayerGui.GoldHUD.Root.ActionDock.SluiceStats)
return "MACHINE live UI PASS"
