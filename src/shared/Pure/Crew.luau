--!strict
-- Pure roster and sale coordinator. IDs, clocks and controllers come from the server.
local Crew = {}
local MAX_INTEGER = 2 ^ 53 - 1
local function money(value)
	assert(
		type(value) == "number" and value >= 0 and value % 1 == 0 and value <= MAX_INTEGER,
		"Crew: money must be a nonnegative safe integer"
	)
end
function Crew.new(config)
	local self = {
		order = {},
		connected = {},
		admitted = {},
		votes = {},
		lastActive = {},
		locked = false,
		haul = 0,
		cursor = 1,
	}
	function self.admit()
		assert(not self.locked, "Crew: roster is locked")
		self.admitted = {}
		local count = 0
		for _, id in self.order do
			if self.connected[id] and count < config.crewCapacity then
				self.admitted[id] = true
				count += 1
			end
		end
	end
	function self.join(id)
		assert(
			type(id) == "string" and id ~= "" and not self.connected[id],
			"Crew: invalid/duplicate join"
		)
		-- A reconnect goes to the end of the next-shift queue, never into a locked run.
		for i = #self.order, 1, -1 do
			if self.order[i] == id then
				table.remove(self.order, i)
			end
		end
		table.insert(self.order, id)
		self.connected[id] = true
		if not self.locked then
			self.admit()
		end
	end
	function self.leave(id)
		assert(self.connected[id], "Crew: unknown leave")
		self.connected[id] = nil
		self.admitted[id] = nil
		self.votes[id] = nil
		self.lastActive[id] = nil
		if not self.locked then
			self.admit()
		end
	end
	function self.members()
		local ids = {}
		for _, id in self.order do
			if self.connected[id] and self.admitted[id] then
				table.insert(ids, id)
			end
		end
		return ids
	end
	function self.start(now)
		assert(not self.locked and #self.members() > 0, "Crew: cannot start")
		self.locked = true
		for _, id in self.members() do
			self.lastActive[id] = now
		end
	end
	function self.activity(id, now)
		assert(
			self.locked and self.connected[id] and self.admitted[id],
			"Crew: activity outside roster"
		)
		assert(now >= self.lastActive[id], "Crew: backwards activity clock")
		self.lastActive[id] = now
	end
	function self.eligibility(id, now)
		if not self.connected[id] or not self.admitted[id] then
			return "waiting"
		end
		if not self.locked then
			return "ready"
		end
		local elapsed = now - self.lastActive[id]
		assert(elapsed >= 0, "Crew: backwards eligibility clock")
		if elapsed >= config.afkSeconds + config.afkWarningSeconds then
			return "paused"
		end
		if elapsed >= config.afkSeconds then
			return "warning"
		end
		return "active"
	end
	function self.sale(id, controller, controllers, requestId, now, machine)
		if not self.locked or not self.connected[id] or not self.admitted[id] then
			return "waiting_for_crew", 0, 0, {}
		end
		assert(now >= self.lastActive[id], "Crew: backwards sale clock")
		local prepared, reason = controller.prepareSale(requestId, machine)
		if not prepared then
			return reason, 0, 0, {}
		end
		local amount = prepared.amount
		money(amount)
		assert(amount <= MAX_INTEGER - self.haul, "Crew: haul overflow")
		local recipients = {}
		-- A real sale resumes the seller before taking the eligibility snapshot.
		for _, member in self.members() do
			if
				(member == id and prepared.result == "sold")
				or self.eligibility(member, now) ~= "paused"
			then
				table.insert(recipients, member)
			end
		end
		local payouts, ledgers = {}, {}
		local nextCursor = self.cursor
		if #recipients > 0 then
			local share = math.floor(amount / #recipients)
			local remainder = amount % #recipients
			local start = (self.cursor - 1) % #recipients + 1
			for i, member in recipients do
				local offset = (i - start) % #recipients
				local value = share + (if offset < remainder then 1 else 0)
				local recipient = controllers[member]
				assert(recipient, "Crew: recipient controller missing")
				money(recipient.ledger.wallet)
				assert(value <= MAX_INTEGER - recipient.ledger.wallet, "Crew: wallet overflow")
				local ledger =
					table.clone(if member == id then prepared.ledger else recipient.ledger)
				ledger.wallet = recipient.ledger.wallet + value
				ledgers[member] = ledger
				payouts[member] = value
			end
			if amount > 0 then
				nextCursor = (start - 1 + remainder) % #recipients + 1
			end
		end
		-- No yielding or fallible validation after this point.
		if ledgers[id] then
			prepared.ledger = ledgers[id]
		else
			prepared.ledger.wallet = controller.ledger.wallet
		end
		controller.commitSale(prepared)
		for member, ledger in ledgers do
			controllers[member].ledger = ledger
		end
		self.haul += amount
		self.cursor = nextCursor
		if prepared.result == "sold" then
			self.activity(id, now)
		end
		return prepared.result, (if payouts[id] then payouts[id] else 0), amount, payouts
	end
	function self.vote(id)
		if not self.connected[id] or not self.admitted[id] then
			return "waiting_for_crew"
		end
		self.votes[id] = true
		return "replay_waiting"
	end
	function self.replayReady()
		assert(self.locked, "Crew: replay requires a started roster")
		for _, id in self.members() do
			if not self.votes[id] then
				return false
			end
		end
		return true
	end
	function self.reset()
		assert(self.replayReady(), "Crew: replay requires crew consent")
		self.locked = false
		self.haul = 0
		self.cursor = 1
		self.votes = {}
		self.lastActive = {}
		self.admit()
	end
	return self
end
return Crew
