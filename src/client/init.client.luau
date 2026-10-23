--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ContextActionService = game:GetService("ContextActionService")
local UserInputService = game:GetService("UserInputService")
local Theme = require(script.Theme)
local Hud = require(ReplicatedStorage:WaitForChild("Shared").Pure.Hud)
local Config = require(ReplicatedStorage.Shared.Config)
local player = Players.LocalPlayer
local status = ReplicatedStorage:WaitForChild("RunStatus")
local actionRemote = ReplicatedStorage:WaitForChild("ActionRequest")
local siftRemote = ReplicatedStorage:WaitForChild("SiftRequest")
local economyRemote = ReplicatedStorage:WaitForChild("EconomyRequest")
local runRemote = ReplicatedStorage:WaitForChild("RunRequest")
local gui = Instance.new("ScreenGui")
gui.Name = "GoldHUD"
gui.ResetOnSpawn = false
gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
gui.DisplayOrder = 10
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = player:WaitForChild("PlayerGui")
local root = Instance.new("Frame")
root.Name = "Root"
root.Size = UDim2.fromScale(1, 1)
root.BackgroundTransparency = 1
root.Parent = gui
local function place(object, x, y, w, h)
	object.Position = UDim2.fromOffset(x, y)
	object.Size = UDim2.fromOffset(w, h)
end
local top = Instance.new("Frame")
top.Name = "Top"
top.BackgroundTransparency = 1
top.Parent = root
local function stat(name, color)
	local box = Theme.surface(top, name, color)
	Theme.gloss(box, color)
	local title = Theme.text(box, "Title", name, 14, true)
	title.Size = UDim2.new(1, -8, 0, 18)
	title.Position = UDim2.fromOffset(4, 3)
	local value = Theme.text(box, "Value", "...", 22, true)
	value.Size = UDim2.new(1, -8, 1, -22)
	value.Position = UDim2.fromOffset(4, 20)
	return box, value
end
local haulBox, haul = stat("Crew Haul", Theme.gold)
local cashBox, cash = stat("Run Cash", Theme.green)
local timerBox, timer = stat("Waiting", Theme.cyan)
local help = Theme.button(top, "Help", "?", Theme.purple)
local bucketBox, bucketCount = stat("Bucket", Theme.cyan)
local backpackBox, backpackCount = stat("Backpack", Theme.purple)
local feedback = require(script.Toast).new(root, Theme)
local dock = Theme.surface(root, "ActionDock", Theme.white)
local primary = Theme.button(dock, "Primary", "Get ready!", Theme.green)
local buy = Theme.button(dock, "Upgrade", "Shovel", Theme.gold)
local helpPanel = Theme.surface(root, "Guide", Theme.white)
helpPanel.Visible = true
helpPanel.ZIndex = 5
local helpTitle = Theme.text(helpPanel, "Title", "How to Strike Gold!", 27, true)
local helpCopy = Theme.text(
	helpPanel,
	"Steps",
	string.format(
		"1. BANK: tap Dig or press E. Stay put until the batch is ready.\n2. RIVER: tap Sift, then hit each gold/green zone (tap or Space). Cancel trashes active dirt.\n3. BUYER: sell finished finds for Run Cash and Crew Haul.\n4. CAMP: a $%d temporary shovel makes digs %.1fs. Resets after this shift.\n\nAT THE BELL: all unsold finds, raw dirt and incomplete sifts are discarded without payment. Only shop sales count. Replay resets cash, inventory, upgrades and opening finds. No permanent rewards saved.",
		Config.shovelUpgradePrice,
		Config.upgradedDigSeconds
	),
	17,
	false
)
local helpClose = Theme.button(helpPanel, "Close", "Let's Dig!", Theme.green)
helpClose.Activated:Connect(function()
	helpPanel.Visible = false
end)
help.Activated:Connect(function()
	helpPanel.Visible = not helpPanel.Visible
end)
local siftPanel = Theme.surface(root, "Sift", Theme.white)
siftPanel.Visible = false
siftPanel.ZIndex = 3
local siftTitle = Theme.text(siftPanel, "Title", "Sift for Gold!", 25, true)
local hitFeedback = require(script.HitFeedback).new(root, siftPanel, siftTitle, Theme)
local grade = Theme.text(siftPanel, "Grade", "Gold: PERFECT • Green: GOOD", 14, false)
local dial = Instance.new("Frame")
dial.Name = "Dial"
dial.BackgroundTransparency = 1
dial.Parent = siftPanel
local segments = {}
-- Rendering resolution/angles are presentation, not skill-check tuning.
for index = 1, 100 do
	local angle = (index - 0.5) / 100 * math.pi * 2
	local segment = Instance.new("Frame")
	segment.AnchorPoint = Vector2.new(0.5, 0.5)
	segment.Size = UDim2.new(0, 5, 0.1, 0)
	segment.Position = UDim2.fromScale(0.5 + math.sin(angle) * 0.43, 0.5 - math.cos(angle) * 0.43)
	segment.Rotation = angle * 180 / math.pi
	segment.BorderSizePixel = 0
	segment.Parent = dial
	segments[index] = segment
end
local pointer = Instance.new("Frame")
pointer.Name = "Pointer"
pointer.Size = UDim2.fromScale(1, 1)
pointer.BackgroundTransparency = 1
pointer.Parent = dial
local needle = Instance.new("Frame")
needle.AnchorPoint = Vector2.new(0.5, 1)
needle.Position = UDim2.fromScale(0.5, 0.5)
needle.Size = UDim2.new(0, 4, 0.43, 0)
needle.BackgroundColor3 = Color3.fromRGB(248, 64, 101)
needle.BorderSizePixel = 0
Theme.border(needle, 1)
needle.Parent = pointer
local hit = Theme.button(siftPanel, "Hit", "HIT! / Space", Theme.green)
local cancel = Theme.button(siftPanel, "Cancel", "Cancel / Q", Theme.purple)
local results = Theme.surface(root, "Results", Theme.white)
results.Visible = false
results.ZIndex = 4
local resultTitle = Theme.text(results, "Title", "Shift Complete!", 30, true)
local resultTile = Theme.surface(results, "HaulTile", Theme.gold)
Theme.gloss(resultTile, Theme.gold)
local resultHaul = Theme.text(resultTile, "Haul", "Crew Haul", 37, true)
resultHaul.Size = UDim2.new(1, -16, 1, -8)
resultHaul.Position = UDim2.fromOffset(8, 4)
local resultCopy = Theme.text(
	results,
	"ResetRules",
	"Only shop sales counted. Unsold items discarded without payment.\nReplay resets cash, inventory, upgrades and opening finds.\nNo permanent rewards saved.",
	16,
	false
)
local replay = Theme.button(results, "Replay", "Play Again!", Theme.green)
replay.Activated:Connect(function()
	runRemote:FireServer("replay", status:GetAttribute("RunId"))
end)
local current = nil
local sent = false
local lastRunId = nil
local function layout()
	local w, h = root.AbsoluteSize.X, root.AbsoluteSize.Y
	local compact = h < 480
	local topWidth = w - 24
	place(top, 12, 8, topWidth, 48)
	local cell = math.min(130, (topWidth - 68) / 3)
	local statHeight = 48
	place(haulBox, 0, 0, cell, statHeight)
	place(cashBox, cell + 8, 0, cell, statHeight)
	place(timerBox, topWidth - cell - 52, 0, cell, statHeight)
	place(help, topWidth - 44, 2, 44, 44)
	place(bucketBox, 0, 56, cell, statHeight)
	place(backpackBox, cell + 8, 56, cell, statHeight)
	feedback.layout(w, cell)
	local dw = math.min(w - 32, 360)
	local bottom = if UserInputService.TouchEnabled then 88 else 16
	place(dock, w - dw - 12, h - bottom - 64, dw, 64)
	place(primary, 10, 10, dw - 20, 44)
	place(buy, dw - 125, 10, 115, 44)
	local sw = math.min(w - 32, 360)
	local sh = 202
	place(siftPanel, w - sw - 12, math.max(6, h - sh - (if compact then 6 else 24)), sw, sh)
	place(siftTitle, 8, 6, sw - 16, 30)
	do
		place(dial, 12, 44, 132, 132)
		place(grade, 152, 38, sw - 164, 48)
		place(hit, 156, 92, sw - 170, 44)
		place(cancel, 156, 148, sw - 170, 44)
	end
	local mw = math.min(w - 28, 510)
	local mh = math.min(h - 22, 370)
	place(helpPanel, (w - mw) / 2, (h - mh) / 2, mw, mh)
	place(helpTitle, 12, 6, mw - 24, 38)
	place(helpCopy, 16, 48, mw - 32, mh - 114)
	place(helpClose, 18, mh - 57, mw - 36, 44)
	local rh = math.min(h - 22, 330)
	place(results, (w - mw) / 2, (h - rh) / 2, mw, rh)
	place(resultTitle, 10, 6, mw - 20, 38)
	place(resultTile, 18, 50, mw - 36, 75)
	place(resultCopy, 18, 136, mw - 36, rh - 203)
	place(replay, 18, rh - 56, mw - 36, 44)
end
root:GetPropertyChangedSignal("AbsoluteSize"):Connect(layout)
layout()
local function feedbackCode(code, amount)
	if code == "sold" then
		assert(type(amount) == "number", "HUD: sale amount missing")
		feedback.show(string.format("Sold finds for $%d!", amount), true)
	else
		feedback.show(Hud.message(code), code == "purchased")
	end
end
local function activate()
	if helpPanel.Visible then
		helpPanel.Visible = false
	end
	if current then
		if not current.graded and not sent then
			sent = true
			siftRemote:FireServer("press", current.id, current.index)
		end
	else
		local action = player:GetAttribute("HudAction")
		if action and action ~= "none" and action ~= "hit" then
			actionRemote:FireServer(action)
		end
	end
end
primary.Activated:Connect(activate)
hit.Activated:Connect(activate)
cancel.Activated:Connect(function()
	actionRemote:FireServer("cancel")
end)
buy.Activated:Connect(function()
	actionRemote:FireServer("buy")
end)
local actions = {
	dig = "dig",
	sift = "sift",
	sell = "sell all",
	buy = "buy shovel",
	cancel = "cancel dig",
	hit = "hit the zone",
	none = "",
}
local function refresh()
	hit.Caption.Text = if UserInputService.TouchEnabled then "Tap to hit!" else "Press Space to hit"
	cancel.Caption.Text = if UserInputService.TouchEnabled then "Cancel" else "Press Q to cancel"
	local phase = status:GetAttribute("Phase")
	local seconds = status:GetAttribute("RemainingSeconds")
	if phase and seconds ~= nil then
		timerBox.Title.Text = phase:gsub("^%l", string.upper)
		timer.Text = string.format("%02d:%02d", math.floor(seconds / 60), seconds % 60)
	end
	local money, total = player:GetAttribute("RunCash"), player:GetAttribute("CrewHaul")
	if money ~= nil and total ~= nil then
		cash.Text = string.format("$%d", money)
		haul.Text = string.format("$%d", total)
	end
	local carried, finds =
		player:GetAttribute("CarriedBatches"), player:GetAttribute("CompletedFinds")
	if carried ~= nil and finds ~= nil then
		bucketCount.Text = string.format(
			"%d/%d dirt",
			carried * Config.dirtPerBatch,
			Config.bucketBatches * Config.dirtPerBatch
		)
		backpackCount.Text = string.format("%d/%d items", finds, Config.outputCapacity)
	end
	local action = player:GetAttribute("HudAction")
	if action then
		assert(actions[action], "HUD: unknown action " .. action)
		primary.Caption.Text = (if UserInputService.TouchEnabled then "Tap to " else "Press E to ")
			.. actions[action]
	end
	primary.Visible = action ~= nil and action ~= "none" and action ~= "buy"

	buy.Visible = player:GetAttribute("Station") == "Camp" and phase == "running"
	buy.Caption.Text = if player:GetAttribute("ShovelUpgraded")
		then "Shovel Owned"
		else string.format("Shovel $%d", Config.shovelUpgradePrice)
	primary.Size = UDim2.new(1, if buy.Visible then -145 else -20, 0, 44)
	buy.Position = if primary.Visible then UDim2.new(1, -125, 0, 10) else UDim2.fromOffset(10, 10)
	buy.Size = if primary.Visible then UDim2.fromOffset(115, 44) else UDim2.new(1, -20, 0, 44)
	dock.Visible = current == nil and phase == "running" and (primary.Visible or buy.Visible)
	siftPanel.Visible = current ~= nil and phase == "running"
	local result = status:GetAttribute("ResultHaul")
	results.Visible = phase == "results" and result ~= nil
	if results.Visible then
		helpPanel.Visible = false
		resultHaul.Text = string.format("Crew Haul\n$%d", result)
	end
	local id = status:GetAttribute("RunId")
	if id and id ~= lastRunId then
		hitFeedback.clear()
		lastRunId = id
		current = nil
		sent = false
		feedback.clear()
	end
end
player.AttributeChanged:Connect(refresh)
status.AttributeChanged:Connect(refresh)
UserInputService:GetPropertyChangedSignal("TouchEnabled"):Connect(refresh)
refresh()
actionRemote.OnClientEvent:Connect(feedbackCode)
economyRemote.OnClientEvent:Connect(feedbackCode)
runRemote.OnClientEvent:Connect(feedbackCode)
ReplicatedStorage:WaitForChild("DigRequest").OnClientEvent:Connect(feedbackCode)
siftRemote.OnClientEvent:Connect(function(code, view, find)
	local hitGrade = if code == "completed" and find then find.results[#find.results] else code
	if hitGrade == "good" or hitGrade == "perfect" then
		hitFeedback.play(hitGrade)
	elseif code == "cancelled" or code == "miss" or code == "expired" or code == "ready" then
		hitFeedback.clear()
	end
	if not current or not view or current.id ~= view.id or current.index ~= view.index then
		sent = false
		pointer.Rotation = 0
	end
	current = view
	feedbackCode(code)
	if view then
		siftTitle.Text = string.format("Sift! Check %d / %d", view.index, view.total)
		grade.Text = if view.graded then Hud.message(code) else "GOLD: perfect\nGREEN: good"
		local side = (view.zoneWidth - view.perfectWidth) / 2
		for index, segment in segments do
			local position = (index - 0.5) / #segments
			local good = position >= view.zoneStart and position <= view.zoneStart + view.zoneWidth
			local perfect = position >= view.zoneStart + side
				and position <= view.zoneStart + side + view.perfectWidth
			segment.BackgroundColor3 = if perfect
				then Theme.gold
				elseif good then Theme.green
				else Color3.fromRGB(207, 220, 229)
		end
	end
	if code == "completed" then
		assert(find, "HUD: completion missing find")
		feedback.show(string.format("%s! Worth $%d", find.kind, find.value), true)
	end
	refresh()
end)
RunService.RenderStepped:Connect(function()
	if current then
		pointer.Rotation = math.clamp(
			(workspace:GetServerTimeNow() - current.startedAt) / current.duration,
			0,
			1
		) * 360
	end
end)
ContextActionService:BindAction("CampAction", function(_, state)
	if state == Enum.UserInputState.Begin then
		activate()
	end
	return Enum.ContextActionResult.Sink
end, false, Enum.KeyCode.E)
-- Beat the default character jump binding regardless of script startup order.
ContextActionService:BindActionAtPriority("SiftHit", function(_, state)
	if not current then
		return Enum.ContextActionResult.Pass
	end
	if state == Enum.UserInputState.Begin then
		activate()
	end
	return Enum.ContextActionResult.Sink
end, false, Enum.ContextActionPriority.High.Value, Enum.KeyCode.Space)
ContextActionService:BindAction("CancelAction", function(_, state)
	if state == Enum.UserInputState.Begin then
		actionRemote:FireServer("cancel")
	end
	return Enum.ContextActionResult.Sink
end, false, Enum.KeyCode.Q)
local watched = {}
local function watch(tool)
	if not tool:IsA("Tool") or watched[tool] then
		return
	end
	if tool.Name ~= "Shovel" and tool.Name ~= "Pan" then
		return
	end
	watched[tool] = true
	tool.Activated:Connect(function()
		if tool.Name == "Pan" and current then
			activate()
		else
			actionRemote:FireServer(if tool.Name == "Pan" then "sift" else "dig")
		end
	end)
end
local function characterAdded(character)
	hitFeedback.clear()
	current = nil
	sent = false
	local backpack = player:WaitForChild("Backpack")
	backpack.ChildAdded:Connect(watch)
	character.ChildAdded:Connect(watch)
	for _, tool in backpack:GetChildren() do
		watch(tool)
	end
	for _, tool in character:GetChildren() do
		watch(tool)
	end
	refresh()
end
player.CharacterAdded:Connect(characterAdded)
if player.Character then
	characterAdded(player.Character)
end
print("[client] boot ok", player.Name)
