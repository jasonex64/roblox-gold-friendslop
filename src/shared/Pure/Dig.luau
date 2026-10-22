--!strict
-- Dependencies, time, identity, distance and random draws are supplied by server.
local Dig = {}
function Dig.new(config, Batch, draw)
	local self = {
		state = { phase = "waiting", batches = {}, lastDigAt = {} },
		openingCount = 0,
		pending = nil,
		sifting = false,
	}
	local limits = {
		digPhases = { running = true },
		-- Contact distance: zero only when the server verifies standing on a pad.
		maxDistance = 0,
		capacity = config.bucketBatches,
		digInterval = config.digSeconds,
	}
	function self.start(request, phase)
		if self.sifting then
			return "busy_sifting"
		end
		if self.pending then
			return "over_rate"
		end
		local state = table.clone(self.state)
		state.phase = phase
		-- Reserve time, not a batch or loot roll. The next completion is one full
		-- duration away; a consecutive dig may start immediately after completion.
		local completion = table.clone(request)
		completion.now += config.digSeconds
		local reason = Batch.canCreate(state, completion, limits)
		if reason then
			return reason
		end
		self.pending = { request = table.clone(request), due = completion.now }
		return "started"
	end
	function self.cancel()
		self.pending = nil
		return "cancelled"
	end
	function self.step(now, distance, phase, source)
		local pending = self.pending
		if not pending then
			return "idle"
		end
		if phase ~= "running" or source ~= pending.request.source or distance ~= 0 then
			self.cancel()
			return "cancelled"
		end
		if now < pending.due then
			return "digging"
		end
		local request = table.clone(pending.request)
		request.now = now
		request.distance = distance
		local state = table.clone(self.state)
		state.phase = phase
		local nextState, reason = Batch.create(state, request, limits, function()
			return draw(self.openingCount, request)
		end)
		self.pending = nil
		if reason then
			return reason
		end
		self.state = nextState
		self.openingCount += 1
		return "created"
	end
	return self
end
return Dig
