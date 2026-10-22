--!strict
-- Server-owned controllers and pure dependencies are injected. No yielding between
-- preparing a transaction and committing its inventory, ledger and tool changes.
local Economy = {}
function Economy.new(config, dig, sift, Batch, Ledger)
	local self = {
		ledger = { wallet = 0, haul = 0, finds = {}, owned = {}, requests = {} },
	}
	local shovel = { id = "shovel-2", price = config.shovelUpgradePrice, prerequisites = {} }
	function self.sell(requestId)
		if self.ledger.requests[requestId] then
			return "duplicate_request", 0
		end
		local prepared = table.clone(self.ledger)
		prepared.finds = table.clone(self.ledger.finds)
		local batches = table.clone(dig.state.batches)
		local ids = {}
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
		self.ledger = ledger
		dig.state = state
		sift.outputs = {}
		return if #ids == 0 then "nothing_to_sell" else "sold", amount
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
