--!strict
local Players = game:GetService("Players")
local SharedBin = {}
function SharedBin.new(session, camp, digging)
	local self = {}
	function self.request(player, action, runId, revision, quantity, ...)
		assert(player:IsA("Player") and player.Parent == Players, "SharedBin: invalid player")
		if
			select("#", ...) ~= 0
			or (action ~= "deposit" and action ~= "withdraw")
			or type(runId) ~= "string"
			or type(revision) ~= "number"
			or not (revision >= 0 and revision < math.huge and revision % 1 == 0)
			or (
				quantity ~= "all"
				and not (
					type(quantity) == "number"
					and quantity > 0
					and quantity < math.huge
					and quantity % 1 == 0
				)
			)
		then
			return "invalid_request"
		end
		if runId ~= session.run.id then
			return "stale_run"
		elseif not session.acceptsPlayer(player) then
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
			or hit.Instance ~= camp.DirtBin
		then
			return "stand_at_bin"
		end
		local dig = digging.get(player)
		local result = session.bin.transfer(
			tostring(player.UserId),
			dig,
			action,
			runId,
			revision,
			quantity,
			session.accepts()
		)
		local carried = 0
		for _, batch in dig.state.batches do
			if batch.status == "queued" or batch.status == "processing" then
				carried += 1
			end
		end
		player:SetAttribute("CarriedBatches", carried)
		return result
	end
	return self
end
return SharedBin
