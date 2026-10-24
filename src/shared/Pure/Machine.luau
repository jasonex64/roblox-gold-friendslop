--!strict
-- Atomic ownership/money adapter for T-023. Injected controllers are server-owned.
local Machine = {}
function Machine.new(config, Sluice, Batch)
	local self = { state = nil, settings = nil, batches = {}, outputs = {}, contributors = {} }
	function self.start(members)
		assert(self.state == nil and members > 0, "Machine: invalid start")
		self.settings = {
			price = config.sluicePricePerMember * members,
			lanes = config.sluiceLanesPerMember * members,
			processSeconds = config.sluiceProcessSeconds,
			outputCapacity = config.sluiceOutputPerMember * members,
		}
		self.state = Sluice.new(self.settings)
	end
	function self.clear()
		self.state, self.settings = nil, nil
		self.batches, self.outputs, self.contributors = {}, {}, {}
	end
	function self.contribute(id, name, economy, amount, requestId)
		assert(self.state and self.settings, "Machine: not started")
		if economy.ledger.requests[requestId] then
			return "duplicate_request", 0
		end
		local state, charged, reason = Sluice.contribute(
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
		self.state = state
		economy.ledger = ledger
		self.contributors[id] = contribution
		return if state.built then "sluice_built" else "contributed", charged
	end
	function self.load(id, dig, bin, sourceName, requestId, now)
		assert(self.state and self.settings, "Machine: not started")
		if sourceName ~= "bucket" and sourceName ~= "bin" then
			return "invalid_request"
		end
		if self.state.requests[id .. ":" .. requestId] then
			return "duplicate_request"
		end
		if dig.pending then
			return "busy_digging"
		end
		if dig.sifting then
			return "busy_sifting"
		end
		local source = if sourceName == "bin" then bin.batches else dig.state.batches
		local item = nil
		for _, batch in source do
			if batch.status == "queued" and (item == nil or batch.id < item.id) then
				item = batch
			end
		end
		if not item then
			return if sourceName == "bin" then "bin_empty" else "bucket_empty"
		end
		assert(not self.batches[item.id], "Machine: duplicate inventory")
		local state, reason = Sluice.load(self.state, self.settings, item.id, now)
		if reason then
			return reason
		end
		local processing = Batch.transition(item, "processing")
		state.requests = table.clone(state.requests)
		state.requests[id .. ":" .. requestId] = true
		local remaining = table.clone(source)
		remaining[item.id] = nil
		local digState = table.clone(dig.state)
		if sourceName == "bucket" then
			digState.batches = remaining
		end
		-- Commit without yielding, after all validation and preparation.
		self.state = state
		self.batches[item.id] = processing
		dig.state = digState
		if sourceName == "bin" then
			bin.batches = remaining
			bin.revision += 1
		end
		return "sluice_loaded"
	end
	function self.step(now, allowed)
		if not allowed or not self.state then
			return 0
		end
		local state, finished = Sluice.collect(self.state, self.settings, now)
		if #finished == 0 then
			return 0
		end
		local batches, outputs = table.clone(self.batches), table.clone(self.outputs)
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
		self.state, self.batches, self.outputs = state, batches, outputs
		return #finished
	end
	function self.prepareSale()
		local ids, batches = {}, table.clone(self.batches)
		for id in self.outputs do
			assert(
				batches[id] and batches[id].status == "completed",
				"Machine: invalid sale inventory"
			)
			table.insert(ids, id)
			batches[id] = nil
		end
		return { state = Sluice.take(self.state, ids), batches = batches }
	end
	function self.commitSale(prepared)
		self.state, self.batches, self.outputs = prepared.state, prepared.batches, {}
	end
	return self
end
return Machine
