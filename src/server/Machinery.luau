--!strict
local Players = game:GetService("Players")
local Machinery = {}
function Machinery.new(session, camp, digging, economy)
	local self = {}
	function self.request(player, action, runId, requestId, payload, ...)
		assert(player:IsA("Player") and player.Parent == Players, "Machinery: invalid player")
		if
			select("#", ...) ~= 0
			or (action ~= "contribute" and action ~= "load")
			or type(runId) ~= "string"
			or type(requestId) ~= "string"
			or #requestId ~= 36
			or not string.match(requestId, "^%x+%-%x+%-%x+%-%x+%-%x+$")
		then
			return "invalid_request"
		end
		if action == "contribute" then
			if
				type(payload) ~= "number"
				or not (payload > 0 and payload <= 2 ^ 53 - 1 and payload % 1 == 0)
			then
				return "invalid_request"
			end
		elseif payload ~= "bucket" and payload ~= "bin" then
			return "invalid_request"
		end
		if runId ~= session.run.id then
			return "stale_run"
		end
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
		if
			humanoid.FloorMaterial == Enum.Material.Air
			or not hit
			or hit.Instance ~= camp.Sluice
		then
			return "stand_at_sluice"
		end
		local id, result, charged = tostring(player.UserId), nil, nil
		if action == "contribute" then
			result, charged = session.machine.contribute(
				id,
				player.DisplayName,
				economy.get(player),
				payload,
				requestId
			)
			player:SetAttribute("RunCash", economy.get(player).ledger.wallet)
		else
			result = session.machine.load(
				id,
				digging.get(player),
				session.bin,
				payload,
				requestId,
				session.now()
			)
			local count = 0
			for _, item in digging.get(player).state.batches do
				if item.status == "queued" or item.status == "processing" then
					count += 1
				end
			end
			player:SetAttribute("CarriedBatches", count)
		end
		if result == "contributed" or result == "sluice_built" or result == "sluice_loaded" then
			session.activity(player)
		end
		if result == "contributed" or result == "sluice_built" then
			session.record(player, "funded", charged, "fund:" .. id .. ":" .. requestId)
		elseif result == "sluice_loaded" then
			session.record(player, "loaded", 1, "load:" .. id .. ":" .. requestId)
		end
		return result, charged
	end
	function self.publish()
		local state = session.machine.state
		local built = state ~= nil and state.built
		camp.SluiceTrough.Transparency = if built then 0 else 0.75
		camp.Sluice.BillboardGui.TextLabel.Text = if built
			then "SLUICE • LOAD DIRT"
			else "SLUICE • CREW FUNDING"
	end
	return self
end
return Machinery
