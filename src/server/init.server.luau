--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local Config = require(ReplicatedStorage:WaitForChild("Shared").Config)
local validate = require(ReplicatedStorage.Shared.Pure.ValidateConfig)
local Session = require(script.Session)
validate(Config)
local spawn = require(script.Camp).build(Config)
local session = Session.new(Config, os.clock, HttpService:GenerateGUID(false))
local Digging = require(script.Digging)
local digging = Digging.new(Config, session, workspace.RiverCamp)
local siftRemote = Instance.new("RemoteEvent")
siftRemote.Name = "SiftRequest"
local sifting =
	require(script.Sifting).new(Config, session, workspace.RiverCamp, digging, siftRemote)
siftRemote.OnServerEvent:Connect(function(player, ...)
	sifting.request(player, ...)
end)
siftRemote.Parent = ReplicatedStorage
local remote = Instance.new("RemoteEvent")
remote.Name = "DigRequest"
remote.OnServerEvent:Connect(function(player, ...)
	local result = digging.request(player, ...)
	remote:FireClient(player, result)
end)
remote.Parent = ReplicatedStorage

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
	digging.add(player)
	sifting.add(player)
	player.RespawnLocation = spawn
	player:SetAttribute("DirtPerBatch", Config.dirtPerBatch)
	player:SetAttribute("BucketBatches", Config.bucketBatches)
	player:SetAttribute("OutputCapacity", Config.outputCapacity)
	player:SetAttribute("DigSeconds", Config.digSeconds)
	player:SetAttribute("SiftSeconds", Config.siftSeconds)
	local storage = Instance.new("Folder")
	storage.Name = tostring(player.UserId) .. "Gear"
	storage.Parent = game:GetService("ServerStorage")
	local tools = {}
	local connections = {}
	for _, name in Config.starterTools do
		local tool = Instance.new("Tool")
		tool.Name = name
		tool.RequiresHandle = false
		tool.CanBeDropped = false
		tool.ToolTip = "Starter " .. name
		tool.Parent = storage
		table.insert(tools, tool)
	end
	local function preserve()
		sifting.cancel(player)
		digging.cancel(player)
		for _, tool in tools do
			tool.Parent = storage
		end
	end
	local function loadout(character)
		local backpack = player:WaitForChild("Backpack")
		local humanoid = character:WaitForChild("Humanoid")
		table.insert(connections, humanoid.Died:Connect(preserve))
		for _, tool in tools do
			tool.Parent = backpack
		end
	end
	table.insert(connections, player.CharacterRemoving:Connect(preserve))
	table.insert(connections, player.CharacterAdded:Connect(loadout))
	table.insert(
		connections,
		Players.PlayerRemoving:Connect(function(leaving)
			if leaving == player then
				for _, connection in connections do
					connection:Disconnect()
				end
				for _, tool in tools do
					tool:Destroy()
				end
				storage:Destroy()
				sifting.remove(player)
				digging.remove(player)
			end
		end)
	)
	if player.Character then
		loadout(player.Character)
	end
end
-- Read-only server diagnostic snapshot. Future processing receives `digging`
-- directly from this bootstrap; copied bindable results are not writable state.
local inventory = Instance.new("BindableFunction")
inventory.Name = "GetDigState"
inventory.OnInvoke = function(player)
	local controller = digging.get(player)
	return { state = controller.state, openingCount = controller.openingCount }
end
inventory.Parent = script
local siftInventory = Instance.new("BindableFunction")
siftInventory.Name = "GetSiftState"
siftInventory.OnInvoke = function(player)
	local controller = sifting.get(player)
	return {
		pending = controller.pending,
		outputs = controller.outputs,
		reserved = controller.reserved,
	}
end
siftInventory.Parent = script
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
	digging.step()
	sifting.step()
	status:SetAttribute("Phase", session.run.phase)
	status:SetAttribute("StartedAt", session.run.startedAt)
	status:SetAttribute("EndsAt", session.run.endsAt)
	status:SetAttribute("AcceptingProduction", session.accepts())
end)
print("[server] boot ok")
