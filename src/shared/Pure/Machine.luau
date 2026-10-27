--!strict
-- Atomic inventory adapter for the crew sluice; all dependencies are injected.
local Machine = {}
local function count(items)
	local n = 0
	for _ in items do
		n += 1
	end
	return n
end
function Machine.new(config, Sluice, Batch, bin)
	assert(bin, "Machine: crew bin required")
	local self =
		{ state = nil, settings = nil, batches = {}, outputs = {}, contributors = {}, queue = {} }
	-- Server may inject the shift timeline (final rush); standalone lanes use constant speed.
	function self.finishAt(start, seconds)
		return start + seconds
	end
	function self.dirtCount()
		local n = #self.queue
		if self.state then
			n += count(self.state.lanes)
		end
		return n
	end
	function self.start(members)
		assert(self.state == nil and members > 0, "Machine: invalid start")
		self.settings = {
			price = config.sluicePricePerMember * members,
			lanes = config.sluiceLanesPerMember * members,
			processSeconds = config.sluiceProcessSeconds,
			outputCapacity = config.sluiceOutputPerMember * members,
			tierTwoPrice = config.sluiceTierTwoPricePerMember * members,
			tierTwoSeconds = config.sluiceTierTwoSeconds,
			hopperPrice = config.sluiceHopperPricePerMember * members,
		}
		self.state = Sluice.new(self.settings)
	end
	function self.clear()
		self.state, self.settings = nil, nil
		self.batches, self.outputs, self.contributors, self.queue = {}, {}, {}, {}
	end
	-- Build and tier-two funding share the D-035 rules and the contributor totals.
	local function fund(sluiceFund, id, name, economy, amount, requestId)
		assert(self.state and self.settings, "Machine: not started")
		if economy.ledger.requests[requestId] then
			return "duplicate_request", 0
		end
		local state, charged, reason = sluiceFund(
			self.state,
			self.settings,
			economy.ledger.wallet,
			amount,
			id .. ":" .. requestId
		)
		if reason then
			return reason, 0
		end
		local ledger = table.clone(economy.ledger)
		ledger.wallet -= charged
		ledger.requests = table.clone(ledger.requests)
		ledger.requests[requestId] = true
		local previous = self.contributors[id]
		local contribution =
			{ name = name, amount = charged + (if previous then previous.amount else 0) }
		self.state, economy.ledger, self.contributors[id] = state, ledger, contribution
		return nil, charged
	end
	function self.contribute(id, name, economy, amount, requestId)
		local reason, charged = fund(Sluice.contribute, id, name, economy, amount, requestId)
		if reason then
			return reason, 0
		end
		return if self.state.built then "sluice_built" else "contributed", charged
	end
	function self.upgrade(id, name, economy, amount, requestId)
		local reason, charged = fund(Sluice.upgrade, id, name, economy, amount, requestId)
		if reason then
			return reason, 0
		end
		return if self.state.tierTwo then "tier_two_built" else "upgrade_contributed", charged
	end
	function self.hopper(id, name, economy, amount, requestId)
		local reason, charged = fund(Sluice.hopper, id, name, economy, amount, requestId)
		if reason then
			return reason, 0
		end
		return if self.state.hopper then "hopper_built" else "hopper_contributed", charged
	end
	function self.transfer(id, dig, sift, requestId)
		assert(self.state and self.settings, "Machine: not started")
		local key = id .. ":" .. requestId
		if self.state.requests[key] then
			return "duplicate_request", 0, 0
		end
		if not self.state.built then
			return "not_built", 0, 0
		end
		if dig.pending then
			return "busy_digging", 0, 0
		end
		if dig.sifting or sift.pending then
			return "busy_sifting", 0, 0
		end
		local available = {}
		for batchId, batch in dig.state.batches do
			if batch.status == "queued" then
				table.insert(available, batchId)
			end
		end
		table.sort(available)
		local finished = {}
		for batchId in self.outputs do
			table.insert(finished, batchId)
		end
		table.sort(finished)
		local deposited = math.min(#available, config.sluiceDirtCapacity - self.dirtCount())
		local collected =
			math.min(#finished, config.outputCapacity - count(sift.outputs) - sift.reserved)
		assert(deposited >= 0 and collected >= 0, "Machine: inventory exceeds capacity")
		if deposited == 0 and collected == 0 then
			return "sluice_no_transfer", 0, 0
		end
		local personal, backpack = table.clone(dig.state.batches), table.clone(sift.outputs)
		local batches, outputs, queue =
			table.clone(self.batches), table.clone(self.outputs), table.clone(self.queue)
		local taken = {}
		for i = 1, collected do
			local batchId = finished[i]
			assert(
				batches[batchId]
					and batches[batchId].status == "completed"
					and not personal[batchId]
					and not backpack[batchId],
				"Machine: invalid collection inventory"
			)
			personal[batchId], backpack[batchId] = batches[batchId], outputs[batchId]
			batches[batchId], outputs[batchId] = nil, nil
			table.insert(taken, batchId)
		end
		for i = 1, deposited do
			local batchId = available[i]
			assert(
				not batches[batchId] and not self.state.processed[batchId],
				"Machine: duplicate deposit"
			)
			batches[batchId], personal[batchId] = personal[batchId], nil
			table.insert(queue, batchId)
		end
		local state = Sluice.take(self.state, taken)
		state.requests = table.clone(state.requests)
		state.requests[key] = true
		local digState = table.clone(dig.state)
		digState.batches = personal
		-- Commit both directions together, without a yield or payment.
		self.state, self.batches, self.outputs, self.queue = state, batches, outputs, queue
		dig.state, sift.outputs = digState, backpack
		return "sluice_transferred", deposited, collected
	end
	function self.step(now, allowed)
		if not allowed or not self.state then
			return 0
		end
		local state, finished = Sluice.collect(self.state, self.settings, now)
		local feeding = state.hopper and bin.count() > 0
		if #finished == 0 and #self.queue == 0 and not feeding then
			return 0
		end
		local batches, outputs, queue =
			table.clone(self.batches), table.clone(self.outputs), table.clone(self.queue)
		for _, id in finished do
			local batch = batches[id]
			assert(batch and not outputs[id], "Machine: missing/duplicate completion")
			local value = math.round(batch.outcome.baseValue * batch.outcome.sourceMultiplier)
			assert(value >= 0 and value < math.huge, "Machine: invalid find value")
			batches[id] = Batch.transition(batch, "completed")
			outputs[id] = table.freeze({
				id = id,
				value = value,
				kind = batch.outcome.kind,
				source = batch.source,
				digger = batch.digger,
				outcome = batch.outcome,
			})
		end
		while #queue > 0 do
			local id = queue[1]
			local loaded, reason = Sluice.load(state, self.settings, id, now, self.finishAt)
			if reason then
				assert(
					reason == "lanes_full" or reason == "output_full",
					"Machine: unexpected queued load rejection " .. reason
				)
				break
			end
			batches[id] = Batch.transition(batches[id], "processing")
			table.remove(queue, 1)
			state = loaded
		end
		-- D-044 hopper: after manual dirt, move bin dirt straight into free lanes. It only
		-- takes what Sluice.load accepts, so it pauses while lanes or output are full.
		local binBatches = nil
		if feeding and #queue == 0 then
			local waiting = {}
			for _, item in bin.batches do
				if item.status == "queued" then
					table.insert(waiting, item)
				end
			end
			table.sort(waiting, function(a, b)
				return a.id < b.id
			end)
			local inside = count(state.lanes)
			for _, item in waiting do
				if inside >= config.sluiceDirtCapacity then
					break
				end
				assert(not batches[item.id], "Machine: hopper duplicate batch " .. item.id)
				local loaded, reason =
					Sluice.load(state, self.settings, item.id, now, self.finishAt)
				if reason then
					assert(
						reason == "lanes_full" or reason == "output_full",
						"Machine: unexpected hopper load rejection " .. reason
					)
					break
				end
				if not binBatches then
					binBatches = table.clone(bin.batches)
				end
				binBatches[item.id] = nil
				batches[item.id] = Batch.transition(item, "processing")
				state = loaded
				inside += 1
			end
		end
		-- Commit sluice and bin together, without a yield.
		self.state, self.batches, self.outputs, self.queue = state, batches, outputs, queue
		if binBatches then
			bin.batches = binBatches
			bin.revision += 1
		end
		return #finished
	end
	return self
end
return Machine
