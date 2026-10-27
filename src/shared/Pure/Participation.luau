--!strict
-- Integrate the same active/warning interval used by Crew cash eligibility.
-- Called BEFORE activity/leave mutations, so delayed ticks cannot backfill AFK time.
local Participation = {}
function Participation.new(startedAt, endsAt, ids, config)
	local self = { last = startedAt, participants = {}, seen = {}, frozen = false }
	for _, id in ids do
		self.participants[id] = { activeSeconds = 0, discoveries = {} }
	end
	function self.sample(now, crew)
		assert(not self.frozen, "Participation: frozen")
		local at = math.min(now, endsAt)
		assert(at >= self.last, "Participation: backwards clock")
		for id, participant in self.participants do
			if crew.connected[id] and crew.admitted[id] then
				local active = crew.lastActive[id]
				assert(active, "Participation: missing last activity")
				local untilTime =
					math.min(at, active + config.afkSeconds + config.afkWarningSeconds)
				participant.activeSeconds += math.max(0, untilTime - self.last)
			end
		end
		self.last = at
	end
	function self.reveal(find, now, crew)
		assert(not self.frozen, "Participation: frozen")
		if now >= endsAt then
			return "after_bell"
		end
		assert(
			type(find.id) == "string" and type(find.kind) == "string",
			"Participation: invalid find"
		)
		if self.seen[find.id] then
			return "duplicate"
		end
		self.seen[find.id] = true
		for id, participant in self.participants do
			local eligibility = crew.eligibility(id, now)
			if eligibility == "active" or eligibility == "warning" then
				participant.discoveries[find.kind] = true
			end
		end
		return "revealed"
	end
	function self.finish(runId, rulesVersion, haul, now, crew)
		self.sample(now, crew)
		assert(now >= endsAt, "Participation: unfinished shift")
		self.frozen = true
		local snapshot = {
			runId = runId,
			rulesVersion = rulesVersion,
			crewHaul = haul,
			crewSize = 0,
			assisted = false,
			participants = {},
		}
		-- No paid loadouts exist in this integration slice.
		for id, participant in self.participants do
			local userId = tonumber(id)
			assert(userId and userId > 0, "Participation: invalid numeric UserId")
			snapshot.crewSize += 1
			snapshot.participants[userId] = table.freeze({
				activeSeconds = participant.activeSeconds,
				discoveries = table.freeze(table.clone(participant.discoveries)),
			})
		end
		table.freeze(snapshot.participants)
		return table.freeze(snapshot)
	end
	return self
end
return Participation
