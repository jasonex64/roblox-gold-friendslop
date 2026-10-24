--!strict
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local PureEconomy = require(Shared.Pure.Economy)
local Batch = require(Shared.Pure.Batch)
local Ledger = require(Shared.Pure.Ledger)

local Economy = {}
function Economy.new(config, session, camp, digging, sifting, remote)
	local controllers = {}
	local self = {}
	function self.get(player)
		assert(controllers[player], "Economy: unknown player")
		return controllers[player]
	end
	local function publish(player, result, amount, total)
		local ledger = self.get(player).ledger
		player:SetAttribute("RunCash", ledger.wallet)
		player:SetAttribute("CrewHaul", session.crew.haul)
		player:SetAttribute("ShovelUpgraded", ledger.owned["shovel-2"] == true)
		player:SetAttribute("DigSeconds", digging.get(player).digSeconds)
		local count = 0
		for _ in sifting.get(player).outputs do
			count += 1
		end
		player:SetAttribute("CompletedFinds", count)
		remote:FireClient(player, result, amount, total)
	end
	function self.add(player)
		assert(not controllers[player], "Economy: duplicate player")
		controllers[player] =
			PureEconomy.new(config, digging.get(player), sifting.get(player), Batch, Ledger)
		publish(player, "ready", 0)
	end
	function self.refresh(player)
		publish(player, "settled", 0)
	end
	local function context(player, action)
		if not session.acceptsPlayer(player) then
			return "wrong_phase"
		end
		local character = player.Character
		local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
		local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
		if not root or not humanoid or humanoid.Health <= 0 then
			return "unavailable"
		end
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = { character }
		local hit =
			workspace:Raycast(root.Position, -Vector3.yAxis * character:GetExtentsSize().Y, params)
		local pad = if hit then hit.Instance else nil
		local valid = if action == "sell"
			then pad == camp.Buyer
			else pad == camp.Camp or pad == camp.CampSpawn
		if humanoid.FloorMaterial == Enum.Material.Air or not valid then
			return if action == "sell" then "stand_at_buyer" else "stand_at_camp"
		end
		return nil
	end
	function self.request(player, action, requestId, ...)
		local controller = self.get(player)
		-- Request IDs are GUIDs, not prices, inventory IDs or desired balances.
		if
			select("#", ...) ~= 0
			or (action ~= "sell" and action ~= "buy")
			or type(requestId) ~= "string"
			or #requestId ~= 36
			or not string.match(requestId, "^%x+%-%x+%-%x+%-%x+%-%x+$")
		then
			publish(player, "invalid_request", 0)
			return "invalid_request"
		end
		local reason = context(player, action)
		if reason then
			publish(player, reason, 0)
			return reason
		end
		local result, amount
		if action == "sell" then
			local byId = {}
			for member, entry in controllers do
				byId[tostring(member.UserId)] = entry
			end
			local total, payouts
			result, amount, total, payouts = session.crew.sale(
				tostring(player.UserId),
				controller,
				byId,
				requestId,
				session.now(),
				session.machine
			)
			if result == "sold" and total > 0 then
				session.record(player, "sold", total, "sale:" .. player.UserId .. ":" .. requestId)
			end
			for member in controllers do
				member:SetAttribute("CrewHaul", session.crew.haul)
				local share = payouts[tostring(member.UserId)]
				if member ~= player and share ~= nil and result == "sold" then
					publish(member, "crew_sale", share, total)
				end
			end
			publish(player, result, amount, total)
			return result, amount, total
		else
			result = controller.buy(requestId)
			amount = 0
			if result == "purchased" then
				session.activity(player)
			end
		end
		publish(player, result, amount)
		return result, amount
	end
	function self.remove(player)
		assert(controllers[player], "Economy: unknown player")
		controllers[player] = nil
	end
	return self
end
return Economy
