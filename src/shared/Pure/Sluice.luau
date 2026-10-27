--!strict
-- One crew sluice. Price, lanes, timing and output capacity are computed by the
-- server from party size and injected. Batches keep the outcome rolled at dig;
-- the sluice only decides when each one finishes, never what it contains.
local Sluice = {}

export type Lane = { batch: string, readyAt: number }
export type State = {
	funded: number,
	built: boolean,
	tierTwoFunded: number,
	tierTwo: boolean,
	lanes: { [number]: Lane },
	output: { [string]: boolean },
	processed: { [string]: boolean },
	requests: { [string]: boolean },
}
export type Config = {
	price: number,
	lanes: number,
	processSeconds: number,
	outputCapacity: number,
	tierTwoPrice: number,
	tierTwoSeconds: number,
}

-- IEEE-754 exact-integer bound, not a gameplay limit or tuning value.
local MAX_INTEGER = 2 ^ 53 - 1

local function money(value: number, name: string)
	assert(
		value >= 0 and value <= MAX_INTEGER and value % 1 == 0,
		"Sluice: " .. name .. " must be a nonnegative safe integer"
	)
end

local function count(map: { [any]: any }): number
	local n = 0
	for _ in map do
		n += 1
	end
	return n
end

local function finite(now: number)
	assert(now > -math.huge and now < math.huge, "Sluice: now must be finite")
end

function Sluice.new(config: Config): State
	money(config.price, "price")
	assert(config.price > 0, "Sluice: price must be positive")
	assert(config.lanes >= 1 and config.lanes % 1 == 0, "Sluice: lanes must be a positive integer")
	assert(
		config.processSeconds > 0 and config.processSeconds < math.huge,
		"Sluice: processSeconds must be positive"
	)
	assert(
		config.outputCapacity >= 1 and config.outputCapacity % 1 == 0,
		"Sluice: outputCapacity must be a positive integer"
	)
	money(config.tierTwoPrice, "tierTwoPrice")
	assert(config.tierTwoPrice > 0, "Sluice: tierTwoPrice must be positive")
	assert(
		config.tierTwoSeconds > 0 and config.tierTwoSeconds < config.processSeconds,
		"Sluice: tierTwoSeconds must be positive and faster than processSeconds"
	)
	return {
		funded = 0,
		built = false,
		tierTwoFunded = 0,
		tierTwo = false,
		lanes = {},
		output = {},
		processed = {},
		requests = {},
	}
end

-- Shared D-035 funding request checks for the build and tier two.
local function duplicate(state: State, wallet: number, amount: number, requestId: string): boolean
	assert(requestId ~= "", "Sluice: requestId must not be empty")
	money(wallet, "wallet")
	money(amount, "amount")
	assert(amount > 0, "Sluice: amount must be positive")
	return state.requests[requestId] == true
end

-- Request IDs share one namespace for the whole crew, so the server must make them
-- unique across players. Rejected contributions do not consume their ID.
-- Returns the amount to deduct from the contributor's wallet; never touches Crew Haul.
function Sluice.contribute(
	state: State,
	config: Config,
	wallet: number,
	amount: number,
	requestId: string
): (State, number, string?)
	if duplicate(state, wallet, amount, requestId) then
		return state, 0, "duplicate_request"
	end
	if state.built then
		return state, 0, "already_built"
	end
	-- Cap at the remaining price so competing contributions can never overcharge.
	local charged = math.min(amount, config.price - state.funded)
	if wallet < charged then
		return state, 0, "insufficient_funds"
	end
	local result = table.clone(state)
	result.funded += charged
	result.built = result.funded == config.price
	result.requests = table.clone(state.requests)
	result.requests[requestId] = true
	return result, charged, nil
end

-- D-043: tier two is funded like the build, only once the sluice is built. It changes
-- the speed of lanes loaded afterwards; lanes already running keep their finish time.
function Sluice.upgrade(
	state: State,
	config: Config,
	wallet: number,
	amount: number,
	requestId: string
): (State, number, string?)
	if duplicate(state, wallet, amount, requestId) then
		return state, 0, "duplicate_request"
	end
	if not state.built then
		return state, 0, "not_built"
	end
	if state.tierTwo then
		return state, 0, "already_upgraded"
	end
	local charged = math.min(amount, config.tierTwoPrice - state.tierTwoFunded)
	if wallet < charged then
		return state, 0, "insufficient_funds"
	end
	local result = table.clone(state)
	result.tierTwoFunded += charged
	result.tierTwo = result.tierTwoFunded == config.tierTwoPrice
	result.requests = table.clone(state.requests)
	result.requests[requestId] = true
	return result, charged, nil
end

function Sluice.processSeconds(state: State, config: Config): number
	return if state.tierTwo then config.tierTwoSeconds else config.processSeconds
end

-- Loading reserves an output slot, so a finished lane can never overflow output:
-- the sluice pauses at the load step instead of mid-processing. finishAt schedules the
-- lane from its load time and process seconds (the server applies the final rush).
function Sluice.load(
	state: State,
	config: Config,
	batchId: string,
	now: number,
	finishAt: (number, number) -> number
): (State, string?)
	assert(batchId ~= "", "Sluice: batchId must not be empty")
	finite(now)
	if not state.built then
		return state, "not_built"
	end
	if state.processed[batchId] then
		return state, "duplicate_batch"
	end
	local lane = nil
	for i = 1, config.lanes do
		if state.lanes[i] == nil then
			lane = i
			break
		end
	end
	if lane == nil then
		return state, "lanes_full"
	end
	if count(state.lanes) + count(state.output) >= config.outputCapacity then
		return state, "output_full"
	end
	local readyAt = finishAt(now, Sluice.processSeconds(state, config))
	assert(readyAt > now and readyAt < math.huge, "Sluice: invalid lane finish time")
	local result = table.clone(state)
	result.lanes = table.clone(state.lanes)
	result.lanes[lane] = table.freeze({ batch = batchId, readyAt = readyAt })
	result.processed = table.clone(state.processed)
	result.processed[batchId] = true
	return result, nil
end

-- Finished batch IDs are returned in lane order; the server marks them completed.
function Sluice.collect(state: State, config: Config, now: number): (State, { string })
	finite(now)
	local finished = {}
	local result = state
	for i = 1, config.lanes do
		local lane = state.lanes[i]
		if lane ~= nil and now >= lane.readyAt then
			if result == state then
				result = table.clone(state)
				result.lanes = table.clone(state.lanes)
				result.output = table.clone(state.output)
			end
			result.lanes[i] = nil
			result.output[lane.batch] = true
			table.insert(finished, lane.batch)
		end
	end
	return result, finished
end

-- Removes shared output for a sale; the server pays it through T-019 payouts.
function Sluice.take(state: State, batchIds: { string }): State
	local result = table.clone(state)
	result.output = table.clone(state.output)
	for _, id in batchIds do
		assert(result.output[id], "Sluice.take: not in output " .. id)
		result.output[id] = nil
	end
	return result
end

return Sluice
