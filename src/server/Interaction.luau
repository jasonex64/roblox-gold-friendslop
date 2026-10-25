--!strict
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local Hud = require(game.ReplicatedStorage.Shared.Pure.Hud)
local Timeline = require(game.ReplicatedStorage.Shared.Pure.Timeline)
local nearSluice = require(script.Parent.NearSluice)
local Interaction = {}
function Interaction.new(config, session, camp, digging, sifting, economy)
	local self = {}
	local function station(player)
		local character = player.Character
		local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
		local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
		if not humanoid or not root or humanoid.Health <= 0 then
			return "Away", false
		end
		if nearSluice(player, camp.Sluice) then
			return "Sluice", true
		end
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = { character }
		local hit =
			workspace:Raycast(root.Position, -Vector3.yAxis * character:GetExtentsSize().Y, params)
		if humanoid.FloorMaterial ~= Enum.Material.Air and hit then
			local pad = hit.Instance
			if pad:IsDescendantOf(camp) then
				if pad:GetAttribute("DigSource") then
					if
						session.accepts()
						and Timeline.canDig(
							pad:GetAttribute("DigSource"),
							session.now() - session.run.startedAt,
							config
						)
					then
						return "ClosedBank", true
					end
					return "Bank", true
				elseif pad == camp.Camp or pad == camp.CampSpawn then
					return "Camp", true
				elseif
					pad == camp.River
					or pad == camp.Buyer
					or pad == camp.DirtBin
					or pad == camp.Sluice
				then
					return pad.Name, true
				end
			end
		end
		return "Away", true
	end
	function self.publish(player)
		local dig, sift, econ = digging.get(player), sifting.get(player), economy.get(player)
		local carried, outputs = 0, 0
		for _, batch in dig.state.batches do
			if batch.status == "queued" or batch.status == "processing" then
				carried += 1
			end
		end
		for _ in sift.outputs do
			outputs += 1
		end
		local place, alive = station(player)
		local action, hint = Hud.nextAction({
			phase = if session.crew.admitted[tostring(player.UserId)]
				then session.run.phase
				else "waiting",
			station = place,
			alive = alive,
			carried = carried,
			outputs = outputs,
			digging = dig.pending ~= nil,
			sifting = sift.pending ~= nil,
			cash = econ.ledger.wallet,
			upgraded = econ.ledger.owned["shovel-2"] == true,
			sluiceBuilt = session.machine.state ~= nil and session.machine.state.built,
		}, config)
		player:SetAttribute("HudAction", action)
		player:SetAttribute("HudHint", hint)
		player:SetAttribute("Station", place)
		player:SetAttribute("Digging", dig.pending ~= nil)
		player:SetAttribute("Sifting", sift.pending ~= nil)
	end
	local function equip(player, name)
		local character = player.Character
		local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
		if not humanoid or humanoid.Health <= 0 then
			return false
		end
		local tool = character:FindFirstChild(name)
		if not tool then
			local backpack = player:FindFirstChildOfClass("Backpack")
			tool = if backpack then backpack:FindFirstChild(name) else nil
		end
		if not tool or not tool:IsA("Tool") then
			return false
		end
		humanoid:EquipTool(tool)
		return true
	end
	function self.request(player, action, ...)
		assert(player:IsA("Player") and player.Parent == Players, "Interaction: invalid player")
		if
			select("#", ...) ~= 0
			or (
				action ~= "dig"
				and action ~= "sift"
				and action ~= "sell"
				and action ~= "buy"
				and action ~= "cancel"
			)
		then
			return "invalid_request"
		end
		if action == "cancel" then
			if sifting.get(player).pending then
				sifting.cancel(player)
			else
				digging.cancel(player)
			end
			return "cancelled"
		end
		if not session.acceptsPlayer(player) then
			return "wrong_phase"
		end
		if action == "dig" then
			if sifting.get(player).pending then
				return "busy_sifting"
			end
			if not equip(player, "Shovel") then
				return "unavailable"
			end
			return digging.request(player, "start")
		elseif action == "sift" then
			if digging.get(player).pending then
				return "busy_digging"
			end
			if not equip(player, "Pan") then
				return "unavailable"
			end
			return sifting.request(player, "start")
		end
		return economy.request(player, action, HttpService:GenerateGUID(false))
	end
	return self
end
return Interaction
