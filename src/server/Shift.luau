--!strict
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local Shift = {}
function Shift.new(session, digging, sifting, economy, status, spawn, rewards)
	local self = { result = nil }
	function self.publish()
		local phase, bankSeconds, rushSeconds = session.timeline()
		status:SetAttribute("ShiftPhase", phase)
		status:SetAttribute("BankSeconds", bankSeconds)
		status:SetAttribute("RushSeconds", rushSeconds)
		local bank = spawn.Parent:FindFirstChild("RichBank")
		assert(bank, "Shift: rich bank missing")
		bank.BillboardGui.TextLabel.Text = if phase == "night"
			then "RICH BANK • OPEN"
			else "RICH BANK • CLOSED"
		local machine = session.machine
		local state, settings = machine.state, machine.settings
		local busy, outputs = 0, 0
		if state then
			for _ in state.lanes do
				busy += 1
			end
			for _ in state.output do
				outputs += 1
			end
		end
		local names = {}
		for id in machine.contributors do
			table.insert(names, id)
		end
		table.sort(names)
		local contributions = {}
		for _, id in names do
			local entry = machine.contributors[id]
			table.insert(contributions, string.format("%s: $%d", entry.name, entry.amount))
		end
		status:SetAttribute("SluiceContributors", table.concat(contributions, " • "))
		status:SetAttribute("SluiceBuilt", state ~= nil and state.built)
		status:SetAttribute("SluiceFunded", if state then state.funded else 0)
		status:SetAttribute("SluicePrice", if settings then settings.price else 0)
		status:SetAttribute("SluiceLanes", if settings then settings.lanes else 0)
		status:SetAttribute("SluiceTierTwo", state ~= nil and state.tierTwo)
		status:SetAttribute("SluiceTierTwoFunded", if state then state.tierTwoFunded else 0)
		status:SetAttribute("SluiceTierTwoPrice", if settings then settings.tierTwoPrice else 0)
		status:SetAttribute("SluiceHopper", state ~= nil and state.hopper)
		status:SetAttribute("SluiceHopperFunded", if state then state.hopperFunded else 0)
		status:SetAttribute("SluiceHopperPrice", if settings then settings.hopperPrice else 0)
		status:SetAttribute("SluiceBusy", busy)
		status:SetAttribute("SluiceDirt", machine.dirtCount())
		status:SetAttribute("SluiceQueued", #machine.queue)
		status:SetAttribute("SluiceOutput", outputs)
		status:SetAttribute("SluiceOutputCapacity", if settings then settings.outputCapacity else 0)
		status:SetAttribute("BinCount", session.bin.count())
		status:SetAttribute("BinCapacity", session.bin.capacity)
		status:SetAttribute("BinRevision", session.bin.revision)
		status:SetAttribute("RemainingSeconds", session.remaining())
		status:SetAttribute("RunId", session.run.id)
		status:SetAttribute("StartedAt", session.run.startedAt)
		status:SetAttribute("EndsAt", session.run.endsAt)
		status:SetAttribute("AcceptingProduction", session.accepts())
		status:SetAttribute("ResultHaul", if self.result then self.result.haul else nil)
		status:SetAttribute(
			"ResultCredits",
			if self.result then HttpService:JSONEncode(session.creditRows()) else nil
		)
		status:SetAttribute("CrewHaul", session.crew.haul)
		status:SetAttribute("CrewCount", #session.crew.members())
		local votes = 0
		for _, id in session.crew.members() do
			if session.crew.votes[id] then
				votes += 1
			end
		end
		status:SetAttribute("ReplayVotes", votes)
		status:SetAttribute("RewardsDurable", rewards.durable(session.run.id))
		for _, player in Players:GetPlayers() do
			local id = tostring(player.UserId)
			player:SetAttribute("CrewMember", session.crew.admitted[id] == true)
			player:SetAttribute("CashShareStatus", session.crew.eligibility(id, session.now()))
			player:SetAttribute("ReplayReady", session.crew.votes[id] == true)
			player:SetAttribute("CrewHaul", session.crew.haul)
			local reward = rewards.result(session.run.id, player.UserId)
			-- One attribute prevents a saved status pairing with another run's amount.
			player:SetAttribute(
				"RewardSummary",
				if reward
					then HttpService:JSONEncode({
						runId = session.run.id,
						status = reward.status,
						tokens = reward.manifest.claimTokens,
					})
					else nil
			)
		end
		status:SetAttribute("Phase", session.run.phase)
	end
	local function replay()
		assert(rewards.durable(session.run.id), "Shift: manifests must be durable before replay")
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
			rewards.finish(session.rewardSnapshot)
			for _, player in Players:GetPlayers() do
				sifting.cancel(player)
				economy.refresh(player)
			end
		end
		-- Leaving cannot strand ready members or the next-shift queue at results.
		if
			session.run.phase == "results"
			and rewards.durable(session.run.id)
			and session.crew.replayReady()
		then
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
		if
			result == "replay_waiting"
			and rewards.durable(session.run.id)
			and session.crew.replayReady()
		then
			replay()
			result = "replayed"
		end
		self.publish()
		return result
	end
	return self
end
return Shift
