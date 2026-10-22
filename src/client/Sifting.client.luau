--!strict
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ContextActionService = game:GetService("ContextActionService")
local player = Players.LocalPlayer
local remote = game:GetService("ReplicatedStorage"):WaitForChild("SiftRequest")
local gui = Instance.new("ScreenGui")
gui.Name = "Sifting"
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")
local panel = Instance.new("Frame")
panel.Size = UDim2.fromOffset(300, 360)
panel.Position = UDim2.new(0.5, -150, 0.5, -180)
panel.BackgroundColor3 = Color3.fromRGB(25, 35, 43)
panel.Visible = false
panel.Parent = gui
local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 42)
title.BackgroundTransparency = 1
title.TextColor3 = Color3.new(1, 1, 1)
title.TextSize = 18
title.Text = "Equip Pan at the river"
title.Parent = panel
local dial = Instance.new("Frame")
dial.Size = UDim2.fromOffset(220, 220)
dial.Position = UDim2.fromOffset(40, 46)
dial.BackgroundTransparency = 1
dial.Parent = panel
local segments = {}
-- These are drawing resolution, pixels and angles, not gameplay tuning.
for index = 1, 100 do
	local angle = (index - 0.5) / 100 * math.pi * 2
	local segment = Instance.new("Frame")
	segment.AnchorPoint = Vector2.new(0.5, 0.5)
	segment.Size = UDim2.fromOffset(5, 16)
	segment.Position = UDim2.fromOffset(110 + math.sin(angle) * 98, 110 - math.cos(angle) * 98)
	segment.Rotation = angle * 180 / math.pi
	segment.BorderSizePixel = 0
	segment.Parent = dial
	segments[index] = segment
end
local pointer = Instance.new("Frame")
pointer.Size = UDim2.fromScale(1, 1)
pointer.BackgroundTransparency = 1
pointer.Parent = dial
local needle = Instance.new("Frame")
needle.AnchorPoint = Vector2.new(0.5, 1)
needle.Position = UDim2.fromScale(0.5, 0.5)
needle.Size = UDim2.fromOffset(3, 90)
needle.BackgroundColor3 = Color3.new(1, 1, 1)
needle.BorderSizePixel = 0
needle.Parent = pointer
local legend = Instance.new("TextLabel")
legend.Size = UDim2.new(1, 0, 0, 24)
legend.Position = UDim2.fromOffset(0, 270)
legend.BackgroundTransparency = 1
legend.TextColor3 = Color3.new(1, 1, 1)
legend.TextSize = 12
legend.Text = "GOLD: PERFECT  •  GREEN: GOOD"
legend.Parent = panel
local function button(text, x, width)
	local control = Instance.new("TextButton")
	control.Size = UDim2.fromOffset(width, 42)
	control.Position = UDim2.fromOffset(x, 305)
	control.Text = text
	control.TextSize = 16
	control.Parent = panel
	return control
end
local hit = button("SIFT / SPACE", 10, 150)
local cancel = button("CANCEL", 170, 120)
local reveal = Instance.new("TextLabel")
reveal.Name = "FindReveal"
reveal.Size = UDim2.fromOffset(280, 180)
reveal.Position = UDim2.new(0.5, -140, 0.5, -110)
reveal.BackgroundColor3 = Color3.fromRGB(34, 67, 52)
reveal.TextColor3 = Color3.fromRGB(255, 222, 117)
reveal.TextScaled = true
reveal.Visible = false
reveal.Parent = gui
local sound = Instance.new("Sound")
sound.Name = "FindSound"
sound.SoundId = "rbxasset://sounds/electronicpingshort.wav"
sound.Parent = gui
local current = nil
local equipped = false
local sent = false
local function activate()
	if current then
		if not current.graded and not sent then
			sent = true
			remote:FireServer("press", current.id, current.index)
		end
	elseif equipped then
		remote:FireServer("start")
	end
end
hit.Activated:Connect(activate)
cancel.Activated:Connect(function()
	remote:FireServer("cancel")
end)
remote.OnClientEvent:Connect(function(result, view, find)
	local changed = not current or not view or current.id ~= view.id or current.index ~= view.index
	current = view
	if changed then
		sent = false
	end
	panel.Visible = equipped or current ~= nil
	title.Text = result:gsub("_", " ")
	if view then
		reveal.Visible = false
		title.Text = string.format("Check %d / %d — %s", view.index, view.total, title.Text)
		local goodWidth = (view.zoneWidth - view.perfectWidth) / 2
		for index, segment in segments do
			local position = (index - 0.5) / #segments
			local good = position >= view.zoneStart and position <= view.zoneStart + view.zoneWidth
			local perfect = position >= view.zoneStart + goodWidth
				and position <= view.zoneStart + goodWidth + view.perfectWidth
			segment.BackgroundColor3 = if perfect
				then Color3.fromRGB(255, 210, 76)
				elseif good then Color3.fromRGB(78, 204, 137)
				else Color3.fromRGB(73, 81, 89)
		end
	end
	if result == "completed" then
		assert(find, "Sifting: completion missing find")
		reveal.Text = string.format(
			"%s\nValue $%.0f\n%.0f%%",
			find.kind,
			find.value,
			find.skillMultiplier * 100
		)
		reveal.Visible = true
		sound:Play()
	end
end)
RunService.RenderStepped:Connect(function()
	if current then
		local progress =
			math.clamp((workspace:GetServerTimeNow() - current.startedAt) / current.duration, 0, 1)
		pointer.Rotation = progress * 360
	end
end)
local watched = {}
local function watch(tool)
	if not tool:IsA("Tool") or tool.Name ~= "Pan" or watched[tool] then
		return
	end
	watched[tool] = true
	tool.Activated:Connect(activate)
	local function equip()
		equipped = true
		panel.Visible = true
		ContextActionService:BindAction("SiftHit", function(_, state)
			if state == Enum.UserInputState.Begin then
				activate()
			end
			return Enum.ContextActionResult.Sink
		end, false, Enum.KeyCode.Space)
	end
	tool.Equipped:Connect(equip)
	tool.Unequipped:Connect(function()
		equipped = false
		panel.Visible = false
		ContextActionService:UnbindAction("SiftHit")
		remote:FireServer("cancel")
	end)
	if tool.Parent == player.Character then
		equip()
	end
end
local function characterAdded(character)
	current = nil
	equipped = false
	panel.Visible = false
	ContextActionService:UnbindAction("SiftHit")
	local backpack = player:WaitForChild("Backpack")
	backpack.ChildAdded:Connect(watch)
	character.ChildAdded:Connect(watch)
	for _, tool in backpack:GetChildren() do
		watch(tool)
	end
	for _, tool in character:GetChildren() do
		watch(tool)
	end
end
player.CharacterAdded:Connect(characterAdded)
if player.Character then
	characterAdded(player.Character)
end
