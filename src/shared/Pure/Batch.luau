--!strict
-- Server-owned inputs only. Distances, time, limits and the complete loot resolver
-- are injected; this module neither selects odds nor reads Roblox state.
local Batch = {}

export type Outcome = {
	kind: string,
	baseValue: number,
	sourceMultiplier: number,
	crateKind: string?,
	crateValue: number?,
}
export type Item = {
	id: string,
	source: string,
	digger: string,
	outcome: Outcome,
	status: string,
	active: boolean,
}
export type State = {
	phase: string,
	batches: { [string]: Item },
	lastDigAt: { [string]: number },
}
export type Request = { id: string, source: string, digger: string, distance: number, now: number }
export type Config = {
	digPhases: { [string]: boolean },
	maxDistance: number,
	capacity: number,
	digInterval: number,
}

-- The caller retains and commits the returned state atomically. Raw queued or
-- processing batches occupy capacity until completed. Transfers are out of scope.
function Batch.canCreate(state: State, request: Request, config: Config): string?
	if not config.digPhases[state.phase] then
		return "wrong_phase"
	end
	-- Positive comparisons also reject NaN rather than accidentally admitting it.
	if not (request.distance >= 0 and request.distance <= config.maxDistance) then
		return "out_of_range"
	end
	local carried = 0
	for _, item in state.batches do
		if
			item.digger == request.digger
			and (item.status == "queued" or item.status == "processing")
		then
			carried += 1
		end
	end
	if carried >= config.capacity then
		return "full_capacity"
	end
	local last = state.lastDigAt[request.digger]
	if not (request.now > -math.huge and request.now < math.huge) then
		return "invalid_time"
	end
	-- Compare deadlines directly so decimal upgraded intervals keep inclusive edges.
	if last ~= nil and not (request.now >= last + config.digInterval) then
		return "over_rate"
	end
	if state.batches[request.id] ~= nil then
		return "duplicate_id"
	end
	assert(
		request.id ~= "" and request.source ~= "" and request.digger ~= "",
		"Batch.create: missing identity"
	)
	return nil
end

function Batch.create(
	state: State,
	request: Request,
	config: Config,
	rng: (Request) -> Outcome
): (State, string?)
	local reason = Batch.canCreate(state, request, config)
	if reason then
		return state, reason
	end
	-- Snapshot even if the resolver reuses its result table. Nested crate results
	-- are resolved by the caller now, stored in crateKind/crateValue, never on reveal.
	local outcome = table.freeze(table.clone(rng(table.freeze(table.clone(request)))))
	local item: Item = table.freeze({
		id = request.id,
		source = request.source,
		digger = request.digger,
		outcome = outcome,
		status = "queued",
		active = false,
	})
	local batches = table.clone(state.batches)
	batches[item.id] = item
	local lastDigAt = table.clone(state.lastDigAt)
	lastDigAt[item.digger] = request.now
	return { phase = state.phase, batches = batches, lastDigAt = lastDigAt }, nil
end

local nextStatus = { queued = "processing", processing = "completed", completed = "sold" }

function Batch.transition(item: Item, target: string): Item
	assert(
		nextStatus[item.status] == target,
		"Batch.transition: illegal transition " .. item.status .. " -> " .. target
	)
	assert(
		item.status ~= "processing" or item.active,
		"Batch.transition: processing attempt is cancelled"
	)
	local result = table.clone(item)
	result.status = target
	result.active = target == "processing"
	return table.freeze(result)
end

-- Cancel/retry changes only the attempt flag, never the lifecycle or loot.
function Batch.cancel(item: Item): Item
	assert(
		item.status == "processing" and item.active,
		"Batch.cancel: no active processing attempt"
	)
	local result = table.clone(item)
	result.active = false
	return table.freeze(result)
end

function Batch.retry(item: Item): Item
	assert(
		item.status == "processing" and not item.active,
		"Batch.retry: no cancelled processing attempt"
	)
	local result = table.clone(item)
	result.active = true
	return table.freeze(result)
end

return Batch
