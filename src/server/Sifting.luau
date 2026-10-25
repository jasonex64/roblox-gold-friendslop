--!strict
local HttpService = game:GetService("HttpService")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Sift = require(Shared.Pure.Sift)
local Batch = require(Shared.Pure.Batch)
local SkillCheck = require(Shared.Pure.SkillCheck)
local Timeline = require(Shared.Pure.Timeline)

local Sifting = {}
function Sifting.new(config, session, camp, digging, remote)
	local controllers = {}
	local random = Random.new()
	local self = {}
	local function allowed(player)
		if not session.acceptsPlayer(player) then
			return false, "wrong_phase"
		end
		local character = player.Character
		local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
		local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
		if
			not root
			or not humanoid
			or humanoid.Health <= 0
			or not character:FindFirstChild("Pan")
		then
			return false, "equip_pan"
		end
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = { character }
		local hit =
			workspace:Raycast(root.Position, -Vector3.yAxis * character:GetExtentsSize().Y, params)
		if humanoid.FloorMaterial == Enum.Material.Air or not hit or hit.Instance ~= camp.River then
			return false, "stand_at_river"
		end
		return true, "ready"
	end
	local function publish(player, result, find)
		local controller = self.get(player)
		local carried = 0
		for _, batch in digging.get(player).state.batches do
			if batch.status == "queued" then
				carried += 1
			end
		end
		local count = 0
		for _ in controller.outputs do
			count += 1
		end
		player:SetAttribute("CarriedBatches", carried)
		player:SetAttribute("CompletedFinds", count)
		player:SetAttribute("ReservedOutput", controller.reserved)
		local pending = controller.pending
		local view = nil
		if pending then
			local check = pending.checks[pending.index]
			view = {
				id = pending.id,
				index = pending.index,
				total = #pending.checks,
				startedAt = check.startedAt,
				duration = pending.duration,
				zoneStart = check.zoneStart,
				zoneWidth = check.zoneWidth,
				perfectWidth = check.perfectWidth,
				graded = check.graded,
			}
		end
		-- Only completed finds reveal loot; pending views contain timing geometry only.
		remote:FireClient(player, result, view, find)
	end
	function self.add(player)
		assert(not controllers[player], "Sifting: duplicate player")
		local controller = Sift.new(config, digging.get(player), Batch, SkillCheck, function()
			return random:NextNumber()
		end)
		-- Server-owned upgrade/rate inputs, changed by later purchase wiring.
		controller.upgrades = 0
		controller.rate = 1
		controller.sweepDuration = function(start, settings, rate)
			assert(session.run.startedAt, "Sifting: missing shift start")
			return Timeline.sweepSeconds(
				start - session.run.startedAt,
				settings.siftSweepSeconds,
				settings.rushSiftSweepSeconds,
				settings
			) / rate
		end
		controllers[player] = controller
		publish(player, "ready")
	end
	function self.get(player)
		assert(controllers[player], "Sifting: unknown player")
		return controllers[player]
	end
	function self.request(player, action, ...)
		local controller = self.get(player)
		local args = { ... }
		local count = select("#", ...)
		local valid = (action == "start" or action == "cancel") and count == 0
		if action == "press" then
			valid = count == 2
				and type(args[1]) == "string"
				and type(args[2]) == "number"
				and args[2] >= 1
				and args[2] <= config.siftChecks
				and args[2] % 1 == 0
		end
		if not valid then
			publish(player, "invalid_request")
			return "invalid_request"
		end
		local result, find
		if action == "cancel" then
			result = controller.cancel()
		else
			local canSift, reason = allowed(player)
			if not canSift then
				controller.cancel()
				result = reason
			elseif action == "start" then
				result = controller.start(
					session.now(),
					HttpService:GenerateGUID(false),
					controller.upgrades,
					controller.rate
				)
			else
				-- No client timestamp, grade, value, or batch identity is accepted.
				result, find = controller.press(session.now(), args[1], args[2])
			end
		end
		if
			result == "started"
			or result == "perfect"
			or result == "good"
			or result == "miss"
			or find
		then
			session.activity(player)
		end
		publish(player, if find then "completed" else result, find)
		return result
	end
	function self.step()
		for player, controller in controllers do
			local index = if controller.pending then controller.pending.index else nil
			local result, find = controller.step(session.now(), allowed(player))
			if
				result == "completed"
				or result == "cancelled"
				or (controller.pending and controller.pending.index ~= index)
			then
				publish(player, result, find)
			end
		end
	end
	function self.cancel(player)
		local result = self.get(player).cancel()
		publish(player, result)
	end
	function self.remove(player)
		self.get(player).cancel()
		controllers[player] = nil
	end
	return self
end
return Sifting
