--!strict
-- Server-owned controllers and pure dependencies are injected. No yielding between
-- preparing a transaction and committing its inventory, ledger and tool changes.
local Economy = {}
function Economy.new(config, dig, sift, Batch, Ledger)
	local self = {
		ledger = { wallet = 0, haul = 0, finds = {}, owned = {}, requests = {} },
	}
	local shovel = { id = "shovel-2", price = config.shovelUpgradePrice, prerequisites = {} }
	-- Prepare without mutation so the crew can validate every recipient before commit.
	function self.prepareSale(requestId, machine)
		if self.ledger.requests[requestId] then
			return nil, "duplicate_request"
		end
		local prepared = table.clone(self.ledger)
		prepared.finds = table.clone(self.ledger.finds)
		local batches = table.clone(dig.state.batches)
		local ids = {}
		local shared = nil
		if machine and machine.state then
			shared = machine.prepareSale()
			for id, find in machine.outputs do
				assert(
					find.id == id and not prepared.finds[id] and not sift.outputs[id],
					"Economy: duplicate shared output"
				)
				prepared.finds[id] = { baseValue = find.value, sold = false }
				table.insert(ids, id)
			end
		end
		for id, find in sift.outputs do
			local batch = batches[id]
			assert(
				batch and batch.status == "completed",
				"Economy: output must have completed batch " .. id
			)
			assert(
				find.id == id and not prepared.finds[id],
				"Economy: duplicate or invalid output " .. id
			)
			prepared.finds[id] = { baseValue = find.value, sold = false }
			batches[id] = Batch.transition(batch, "sold")
			table.insert(ids, id)
		end
		local ledger, reason = Ledger.sell(prepared, ids, requestId)
		assert(reason == nil, "Economy: unexpected sale rejection")
		local amount = ledger.wallet - self.ledger.wallet
		local state = table.clone(dig.state)
		state.batches = batches
		return {
			machine = machine,
			shared = shared,
			ledger = ledger,
			state = state,
			amount = amount,
			result = if #ids == 0 then "nothing_to_sell" else "sold",
		},
			nil
	end
	function self.commitSale(prepared)
		if prepared.shared then
			prepared.machine.commitSale(prepared.shared)
		end
		self.ledger = prepared.ledger
		dig.state = prepared.state
		sift.outputs = {}
	end
	function self.sell(requestId)
		local prepared, reason = self.prepareSale(requestId)
		if not prepared then
			return reason, 0
		end
		self.commitSale(prepared)
		return prepared.result, prepared.amount
	end
	function self.buy(requestId)
		local ledger, reason = Ledger.buy(self.ledger, shovel, requestId)
		if reason then
			return reason
		end
		self.ledger = ledger
		dig.digSeconds = config.upgradedDigSeconds
		return "purchased"
	end
	return self
end
return Economy
