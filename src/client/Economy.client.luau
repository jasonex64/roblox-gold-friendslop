--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local player = Players.LocalPlayer
local remote = ReplicatedStorage:WaitForChild("EconomyRequest")
local config = require(ReplicatedStorage:WaitForChild("Shared").Config)
local gui = Instance.new("ScreenGui")
gui.Name = "Economy"
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")
local panel = Instance.new("Frame")
panel.Size = UDim2.fromOffset(280, 205)
panel.Position = UDim2.new(0, 12, 1, -285)
panel.BackgroundColor3 = Color3.fromRGB(25, 35, 43)
panel.Parent = gui
local balance = Instance.new("TextLabel")
balance.Name = "Balance"
balance.Size = UDim2.new(1, -16, 0, 36)
balance.Position = UDim2.fromOffset(8, 4)
balance.BackgroundTransparency = 1
balance.TextColor3 = Color3.new(1, 1, 1)
balance.TextSize = 17
balance.Text = "Loading wallet..."
balance.Parent = panel
local function button(name, text, y)
	local control = Instance.new("TextButton")
	control.Name = name
	control.Size = UDim2.new(1, -16, 0, 42)
	control.Position = UDim2.fromOffset(8, y)
	control.Text = text
	control.TextSize = 15
	control.Parent = panel
	return control
end
local sell = button("Sell", "Sell all — stand at Buyer", 44)
local buy = button("Buy", string.format("Temporary shovel — $%d", config.shovelUpgradePrice), 92)
local detail = Instance.new("TextLabel")
detail.Size = UDim2.new(1, -16, 0, 30)
detail.Position = UDim2.fromOffset(8, 136)
detail.BackgroundTransparency = 1
detail.TextColor3 = Color3.fromRGB(235, 218, 163)
detail.TextSize = 13
detail.Text =
	string.format("%.1fs digs • buy at Camp\nResets after this shift", config.upgradedDigSeconds)
detail.Parent = panel
local feedback = Instance.new("TextLabel")
feedback.Name = "Feedback"
feedback.Size = UDim2.new(1, -16, 0, 30)
feedback.Position = UDim2.fromOffset(8, 170)
feedback.BackgroundTransparency = 1
feedback.TextColor3 = Color3.new(1, 1, 1)
feedback.TextSize = 14
feedback.Text = ""
feedback.Parent = panel
local function refresh()
	local cash, haul = player:GetAttribute("RunCash"), player:GetAttribute("CrewHaul")
	if cash == nil or haul == nil then
		balance.Text = "Loading wallet..."
		return
	end
	balance.Text = string.format("Cash $%d  •  Crew Haul $%d", cash, haul)
	buy.Text = if player:GetAttribute("ShovelUpgraded")
		then "Temporary shovel — owned"
		else string.format("Temporary shovel — $%d", config.shovelUpgradePrice)
end
for _, attribute in { "RunCash", "CrewHaul", "ShovelUpgraded" } do
	player:GetAttributeChangedSignal(attribute):Connect(refresh)
end
refresh()
sell.Activated:Connect(function()
	remote:FireServer("sell", HttpService:GenerateGUID(false))
end)
buy.Activated:Connect(function()
	remote:FireServer("buy", HttpService:GenerateGUID(false))
end)
remote.OnClientEvent:Connect(function(result, amount)
	feedback.Text = if result == "sold"
		then string.format("Sold finds for $%d", amount)
		elseif result == "purchased" then "Shovel upgraded for this shift!"
		elseif result == "unaffordable" then "Not enough Run Cash"
		else result:gsub("_", " ")
end)
