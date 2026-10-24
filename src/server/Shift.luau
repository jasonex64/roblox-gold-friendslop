--!strict
local Players = game:GetService("Players")
local Shift = {}
function Shift.new(session, digging, sifting, economy, status, spawn)
	local self = { result = nil }
	function self.publish()
		status:SetAttribute("BinCount", session.bin.count())
		status:SetAttribute("BinCapacity", session.bin.capacity)
		status:SetAttribute("BinRevision", session.bin.revision)
		status:SetAttribute("RemainingSeconds", session.remaining())
		status:SetAttribute("RunId", session.run.id)
		status:SetAttribute("StartedAt", session.run.startedAt)
		status:SetAttribute("EndsAt", session.run.endsAt)
		status:SetAttribute("AcceptingProduction", session.accepts())
		status:SetAttribute("ResultHaul", if self.result then self.result.haul else nil)
		status:SetAttribute("CrewHaul", session.crew.haul)
		status:SetAttribute("CrewCount", #session.crew.members())
		local votes = 0
		for _, id in session.crew.members() do
			if session.crew.votes[id] then
				votes += 1
			end
		end
		status:SetAttribute("ReplayVotes", votes)
		for _, player in Players:GetPlayers() do
			local id = tostring(player.UserId)
			player:SetAttribute("CrewMember", session.crew.admitted[id] == true)
			player:SetAttribute("CashShareStatus", session.crew.eligibility(id, session.now()))
			player:SetAttribute("ReplayReady", session.crew.votes[id] == true)
			player:SetAttribute("CrewHaul", session.crew.haul)
		end
		status:SetAttribute("Phase", session.run.phase)
	end
	local function replay()
		session.reset()
		self.result = nil
		for _, member in Players:GetPlayers() do
			economy.remove(member)
			sifting.remove(member)
			digging.remove(member)
			digging.add(member)
			sifting.add(member)
			economy.add(member)
			local character = member.Character
			local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
			if humanoid and humanoid.Health > 0 then
				humanoid:UnequipTools()
				character:PivotTo(
					spawn.CFrame + Vector3.new(0, spawn.Size.Y + humanoid.HipHeight, 0)
				)
			end
		end
	end
	function self.step()
		if session.run.phase == "ended" then
			local entries = {}
			for _, player in Players:GetPlayers() do
				table.insert(entries, {
					dig = digging.get(player),
					sift = sifting.get(player),
					economy = economy.get(player),
				})
			end
			self.result = session.finish(entries)
			for _, player in Players:GetPlayers() do
				sifting.cancel(player)
				economy.refresh(player)
			end
		end
		-- Leaving cannot strand ready members or the next-shift queue at results.
		if session.run.phase == "results" and session.crew.replayReady() then
			replay()
		end
		self.publish()
	end
	function self.request(player, action, runId, ...)
		assert(player:IsA("Player") and player.Parent == Players, "Shift: invalid player")
		if select("#", ...) ~= 0 or action ~= "replay" or type(runId) ~= "string" then
			return "invalid_request"
		end
		if runId ~= session.run.id then
			return "stale_run"
		end
		if session.run.phase ~= "results" or not self.result then
			return "wrong_phase"
		end
		local result = session.crew.vote(tostring(player.UserId))
		if result == "replay_waiting" and session.crew.replayReady() then
			replay()
			result = "replayed"
		end
		self.publish()
		return result
	end
	return self
end
return Shift
