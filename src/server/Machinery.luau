--!strict
local Players = game:GetService("Players")
local near = require(script.Parent.NearSluice)
local Machinery = {}
function Machinery.new(session, camp, digging, economy, sifting)
	local self = {}
	function self.request(player, action, runId, requestId, payload, ...)
		assert(player:IsA("Player") and player.Parent == Players, "Machinery: invalid player")
		if
			select("#", ...) ~= 0
			or (action ~= "contribute" and action ~= "upgrade" and action ~= "transfer")
			or type(runId) ~= "string"
			or type(requestId) ~= "string"
			or #requestId ~= 36
			or not string.match(requestId, "^%x+%-%x+%-%x+%-%x+%-%x+$")
		then
			return "invalid_request"
		end
		if action == "contribute" or action == "upgrade" then
			if
				type(payload) ~= "number"
				or not (payload > 0 and payload <= 2 ^ 53 - 1 and payload % 1 == 0)
			then
				return "invalid_request"
			end
		elseif payload ~= nil then
			return "invalid_request"
		end
		if runId ~= session.run.id then
			return "stale_run"
		end
		if not session.acceptsPlayer(player) then
			return "wrong_phase"
		end
		if not near(player, camp.Sluice) then
			return "stand_at_sluice"
		end
		local id, result, charged, collected = tostring(player.UserId), nil, nil, nil
		if action == "contribute" or action == "upgrade" then
			result, charged = session.machine[action](
				id,
				player.DisplayName,
				economy.get(player),
				payload,
				requestId
			)
			player:SetAttribute("RunCash", economy.get(player).ledger.wallet)
		else
			result, charged, collected =
				session.machine.transfer(id, digging.get(player), sifting.get(player), requestId)
			local count = 0
			for _, item in digging.get(player).state.batches do
				if item.status == "queued" or item.status == "processing" then
					count += 1
				end
			end
			player:SetAttribute("CarriedBatches", count)
			local finds = 0
			for _ in sifting.get(player).outputs do
				finds += 1
			end
			player:SetAttribute("CompletedFinds", finds)
		end
		if
			result == "contributed"
			or result == "sluice_built"
			or result == "upgrade_contributed"
			or result == "tier_two_built"
			or result == "sluice_transferred"
		then
			session.activity(player)
		end
		if
			result == "contributed"
			or result == "sluice_built"
			or result == "upgrade_contributed"
			or result == "tier_two_built"
		then
			session.record(player, "funded", charged, "fund:" .. id .. ":" .. requestId)
		elseif result == "sluice_transferred" and charged > 0 then
			-- For a transfer, charged is the number of dirt deposited into the sluice.
			session.record(player, "loaded", charged, "load:" .. id .. ":" .. requestId)
		end
		return result, charged, collected
	end
	function self.publish()
		local state = session.machine.state
		local built = state ~= nil and state.built
		camp.SluiceTrough.Transparency = if built then 0 else 0.75
		camp.Sluice.BillboardGui.TextLabel.Text = if built
			then "SLUICE • QUICK TRANSFER"
			else "SLUICE • CREW FUNDING"
	end
	return self
end
return Machinery
