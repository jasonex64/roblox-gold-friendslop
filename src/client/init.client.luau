--!strict
-- Client entry point. Boot line is what the Studio MCP smoke check looks for.
local Players = game:GetService("Players")
local remote = game:GetService("ReplicatedStorage"):WaitForChild("DigRequest")
local player = Players.LocalPlayer
local watched = {}
local function watch(tool)
	if not tool:IsA("Tool") or tool.Name ~= "Shovel" or watched[tool] then
		return
	end
	watched[tool] = true
	tool.Activated:Connect(function()
		remote:FireServer("start")
	end)
	tool.Deactivated:Connect(function()
		remote:FireServer("cancel")
	end)
	tool.Unequipped:Connect(function()
		remote:FireServer("cancel")
	end)
end
local function characterAdded(character)
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

print("[client] boot ok", Players.LocalPlayer.Name)
