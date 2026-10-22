--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local player = game:GetService("Players").LocalPlayer
local status = ReplicatedStorage:WaitForChild("RunStatus")
local remote = ReplicatedStorage:WaitForChild("RunRequest")
local gui = Instance.new("ScreenGui")
gui.Name = "Results"
gui.ResetOnSpawn = false
gui.DisplayOrder = 10
gui.Parent = player:WaitForChild("PlayerGui")
local panel = Instance.new("Frame")
panel.Name = "Panel"
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.Position = UDim2.fromScale(0.5, 0.5)
panel.Size = UDim2.new(0.9, 0, 0, 380)
panel.BackgroundColor3 = Color3.fromRGB(25, 35, 43)
panel.Parent = gui
local limit = Instance.new("UISizeConstraint")
limit.MaxSize = Vector2.new(460, 380)
limit.Parent = panel
local function label(name, y, height, size)
	local item = Instance.new("TextLabel")
	item.Name = name
	item.Position = UDim2.fromOffset(16, y)
	item.Size = UDim2.new(1, -32, 0, height)
	item.BackgroundTransparency = 1
	item.TextColor3 = Color3.new(1, 1, 1)
	item.TextSize = size
	item.TextWrapped = true
	item.Parent = panel
	return item
end
label("Title", 12, 32, 24).Text = "Shift complete"
local haul = label("Haul", 48, 40, 24)
label("ResetRules", 92, 196, 17).Text =
	"Completed finds sold automatically. Unprocessed dirt discarded.\n\nReplay resets inventory, Run Cash, the temporary shovel, and opening counter.\n\nNo permanent rewards are saved."
local replay = Instance.new("TextButton")
replay.Name = "Replay"
replay.Position = UDim2.fromOffset(16, 304)
replay.Size = UDim2.new(1, -32, 0, 48)
replay.TextSize = 20
replay.Text = "Play again"
replay.Parent = panel
local feedback = label("Feedback", 354, 24, 14)
feedback.Text = ""
local function refresh()
	local amount = status:GetAttribute("ResultHaul")
	panel.Visible = status:GetAttribute("Phase") == "results" and amount ~= nil
	if amount ~= nil then
		haul.Text = string.format("Crew Haul: $%d", amount)
	end
	if not panel.Visible then
		feedback.Text = ""
	end
end
status.AttributeChanged:Connect(refresh)
refresh()
replay.Activated:Connect(function()
	remote:FireServer("replay", status:GetAttribute("RunId"))
end)
remote.OnClientEvent:Connect(function(result)
	feedback.Text = result:gsub("_", " ")
end)
