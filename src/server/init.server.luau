--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local Config = require(ReplicatedStorage:WaitForChild("Shared").Config)
local validate = require(ReplicatedStorage.Shared.Pure.ValidateConfig)
local Session = require(script.Session)
validate(Config)
local spawn = require(script.Camp).build()
local session = Session.new(Config, os.clock, HttpService:GenerateGUID(false))

local status = Instance.new("Folder")
status.Name = "RunStatus"
status:SetAttribute("RunId", session.run.id)
status:SetAttribute("RulesVersion", Config.rulesVersion)
status.Parent = ReplicatedStorage

-- Server-only gate for production handlers added by subsequent tickets.
local gate = Instance.new("BindableFunction")
gate.Name = "ProductionAllowed"
gate.OnInvoke = function(player)
	assert(
		typeof(player) == "Instance" and player:IsA("Player") and player.Parent == Players,
		"ProductionAllowed: invalid player"
	)
	return session.accepts()
end
gate.Parent = script

local function equip(player)
	player.RespawnLocation = spawn
	player:SetAttribute("DirtPerBatch", Config.dirtPerBatch)
	player:SetAttribute("BucketBatches", Config.bucketBatches)
	player:SetAttribute("OutputCapacity", Config.outputCapacity)
	player:SetAttribute("DigSeconds", Config.digSeconds)
	player:SetAttribute("SiftSeconds", Config.siftSeconds)
	local function loadout()
		local backpack = player:WaitForChild("Backpack")
		for _, name in Config.starterTools do
			if
				not backpack:FindFirstChild(name)
				and not (player.Character and player.Character:FindFirstChild(name))
			then
				local tool = Instance.new("Tool")
				tool.Name = name
				tool.RequiresHandle = false
				tool.CanBeDropped = false
				tool.ToolTip = "Starter " .. name .. " (prototype)"
				tool.Parent = backpack
			end
		end
	end
	player.CharacterAdded:Connect(loadout)
	if player.Character then
		loadout()
	end
end
Players.PlayerAdded:Connect(equip)
for _, player in Players:GetPlayers() do
	equip(player)
end

RunService.Heartbeat:Connect(function()
	local players = Players:GetPlayers()
	local ready = #players > 0
	for _, player in players do
		if not player.Character or not player.Character:FindFirstChild("HumanoidRootPart") then
			ready = false
		end
	end
	session.advance(ready)
	status:SetAttribute("Phase", session.run.phase)
	status:SetAttribute("StartedAt", session.run.startedAt)
	status:SetAttribute("EndsAt", session.run.endsAt)
	status:SetAttribute("AcceptingProduction", session.accepts())
end)
print("[server] boot ok")
