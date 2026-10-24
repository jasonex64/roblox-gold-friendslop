--!strict
-- Server-owned shared inventory. Transfers do not yield or draw new loot.
local Bin = {}
local function count(batches)
	local total = 0
	for _, item in batches do
		if item.status == "queued" or item.status == "processing" then
			total += 1
		end
	end
	return total
end
function Bin.new(config, crew)
	local self = { batches = {}, capacity = 0, revision = 0, runId = nil }
	function self.start(runId, members)
		assert(self.runId == nil and members > 0, "Bin: invalid start")
		self.runId = runId
		self.capacity = config.binBatchesPerMember * members
	end
	function self.count()
		return count(self.batches)
	end
	function self.clear()
		self.batches = {}
		self.revision += 1
	end
	function self.reset()
		self.clear()
		self.runId = nil
		self.capacity = 0
	end
	function self.transfer(id, dig, action, runId, revision, quantity, allowed)
		if
			(action ~= "deposit" and action ~= "withdraw")
			or (
				quantity ~= "all"
				and not (
					type(quantity) == "number"
					and quantity > 0
					and quantity < math.huge
					and quantity % 1 == 0
				)
			)
		then
			return "invalid_request"
		elseif runId ~= self.runId then
			return "stale_run"
		elseif not allowed then
			return "wrong_phase"
		elseif not crew.connected[id] or not crew.admitted[id] then
			return "waiting_for_crew"
		elseif revision ~= self.revision then
			return "bin_changed"
		elseif dig.pending then
			return "busy_digging"
		elseif dig.sifting then
			return "busy_sifting"
		end
		local deposit = action == "deposit"
		local source = if deposit then dig.state.batches else self.batches
		local target = if deposit then self.batches else dig.state.batches
		local capacity = if deposit then self.capacity else config.bucketBatches
		local room = capacity - count(target)
		if room <= 0 then
			return if deposit then "bin_full" else "full_capacity"
		end
		local selected = {}
		for _, item in source do
			if item.status == "queued" then
				table.insert(selected, item)
			end
		end
		if #selected == 0 then
			return if deposit then "bucket_empty" else "bin_empty"
		end
		local amount = if quantity == "all" then math.min(#selected, room) else quantity
		if amount > #selected or amount > room then
			return "bin_quantity_changed"
		end
		table.sort(selected, function(a, b)
			return a.id < b.id
		end)
		local from, to = table.clone(source), table.clone(target)
		for index = 1, amount do
			local item = selected[index]
			assert(not target[item.id], "Bin: duplicate batch in destination")
			from[item.id] = nil
			to[item.id] = item
		end
		local state = table.clone(dig.state)
		state.batches = if deposit then from else to
		dig.state = state
		self.batches = if deposit then to else from
		self.revision += 1
		return if deposit then "deposited" else "withdrawn", amount
	end
	return self
end
return Bin
