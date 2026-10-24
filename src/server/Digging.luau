--!strict
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Batch = require(Shared.Pure.Batch)
local Dig = require(Shared.Pure.Dig)
local Loot = require(Shared.Pure.Loot)

local Digging = {}
function Digging.new(config, session, camp)
	local controllers = {}
	local random = Random.new()
	local self = {}
	function self.add(player)
		assert(not controllers[player], "Digging: duplicate player")
		controllers[player] = Dig.new(config, Batch, function(count, request)
			local outcome = Loot.draw(config, count, function()
				return random:NextNumber()
			end)
			outcome.sourceMultiplier = request.multiplier
			return outcome
		end)
		player:SetAttribute("CarriedBatches", 0)
		player:SetAttribute("OpeningCount", 0)
	end
	local function context(player)
		local character = player.Character
		local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
		local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
		if
			not root
			or not humanoid
			or humanoid.Health <= 0
			or not character:FindFirstChild("Shovel")
		then
			return nil, "unavailable"
		end
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = { character }
		local hit =
			workspace:Raycast(root.Position, -Vector3.yAxis * character:GetExtentsSize().Y, params)
		local pad = if hit then hit.Instance else nil
		if
			humanoid.FloorMaterial == Enum.Material.Air
			or not pad
			or not pad:IsDescendantOf(camp)
			or not pad:GetAttribute("DigSource")
		then
			return nil, if session.acceptsPlayer(player) then "running" else "closed"
		end
		return pad, if session.acceptsPlayer(player) then "running" else "closed"
	end
	function self.request(player, action, ...)
		assert(
			player:IsA("Player") and player.Parent == Players and controllers[player],
			"Digging: invalid player"
		)
		if select("#", ...) ~= 0 or (action ~= "start" and action ~= "cancel") then
			return "invalid_request"
		end
		local controller = controllers[player]
		if action == "cancel" then
			return controller.cancel()
		end
		local pad, phase = context(player)
		if not pad then
			return if phase == "running" then "out_of_range" else "wrong_phase"
		end
		local source = pad:GetAttribute("DigSource")
		local multiplier = pad:GetAttribute("DirtMultiplier")
		assert(type(source) == "string" and source ~= "", "Digging: pad DigSource required")
		assert(
			type(multiplier) == "number" and multiplier > 0 and multiplier < math.huge,
			"Digging: pad DirtMultiplier invalid"
		)
		return controller.start({
			id = HttpService:GenerateGUID(false),
			source = source,
			multiplier = multiplier,
			digger = tostring(player.UserId),
			distance = 0,
			now = os.clock(),
		}, phase)
	end
	function self.step()
		for player, controller in controllers do
			local pad, phase = context(player)
			local source = if pad then pad:GetAttribute("DigSource") else nil
			local result = controller.step(os.clock(), if pad then 0 else math.huge, phase, source)
			if result == "created" then
				session.activity(player)
				local count = 0
				for _, batch in controller.state.batches do
					if batch.status == "queued" or batch.status == "processing" then
						count += 1
					end
				end
				player:SetAttribute("CarriedBatches", count)
				player:SetAttribute("OpeningCount", controller.openingCount)
			end
		end
	end
	function self.cancel(player)
		assert(controllers[player], "Digging: unknown player")
		return controllers[player].cancel()
	end
	function self.remove(player)
		controllers[player] = nil
	end
	-- Server-only state for sifting integration; never replicate outcomes to clients.
	function self.get(player)
		assert(controllers[player], "Digging: unknown player")
		return controllers[player]
	end
	return self
end
return Digging
