--!strict
-- Gate A solo ledger. Money uses integer fixed-point units chosen by the caller.
-- Register only completed finds, with final source-adjusted base sale values.
local Ledger = {}

export type Find = { baseValue: number, sold: boolean }
export type State = {
	haul: number,
	wallet: number,
	finds: { [string]: Find },
	owned: { [string]: boolean },
	requests: { [string]: boolean },
}
export type Item = { id: string, price: number, prerequisites: { string } }

-- IEEE-754 exact-integer bound, not a gameplay limit or tuning value.
local MAX_INTEGER = 2 ^ 53 - 1

local function money(value: number, name: string)
	assert(
		value >= 0 and value <= MAX_INTEGER and value % 1 == 0,
		"Ledger: " .. name .. " must be a nonnegative safe integer"
	)
end

local function validate(ledger: State, requestId: string)
	assert(requestId ~= "", "Ledger: requestId must not be empty")
	money(ledger.haul, "haul")
	money(ledger.wallet, "wallet")
end

-- All requests for one run share the same ID namespace. Replays are no-ops,
-- even if their payload or operation changes. Rejected buys do not consume IDs.
function Ledger.sell(ledger: State, finds: { string }, requestId: string): (State, string?)
	validate(ledger, requestId)
	if ledger.requests[requestId] then
		return ledger, "duplicate_request"
	end
	local total = 0
	local seen: { [string]: boolean } = {}
	for _, id in finds do
		local find = ledger.finds[id]
		assert(find ~= nil, "Ledger.sell: unknown_find " .. id)
		assert(not find.sold, "Ledger.sell: already_sold " .. id)
		assert(not seen[id], "Ledger.sell: duplicate_find " .. id)
		money(find.baseValue, "find " .. id .. " baseValue")
		assert(find.baseValue <= MAX_INTEGER - total, "Ledger.sell: total overflow")
		total += find.baseValue
		seen[id] = true
	end
	assert(total <= MAX_INTEGER - ledger.haul, "Ledger.sell: haul overflow")
	assert(total <= MAX_INTEGER - ledger.wallet, "Ledger.sell: wallet overflow")
	local result = table.clone(ledger)
	result.finds = table.clone(ledger.finds)
	for id in seen do
		local sold = table.clone(ledger.finds[id])
		sold.sold = true
		result.finds[id] = table.freeze(sold)
	end
	result.haul += total
	result.wallet += total
	result.requests = table.clone(ledger.requests)
	result.requests[requestId] = true
	return result, nil
end

-- item is a trusted server catalog entry, never a client-supplied price.
function Ledger.buy(ledger: State, item: Item, requestId: string): (State, string?)
	validate(ledger, requestId)
	if ledger.requests[requestId] then
		return ledger, "duplicate_request"
	end
	assert(item.id ~= "", "Ledger.buy: item id must not be empty")
	money(item.price, "item " .. item.id .. " price")
	if ledger.owned[item.id] then
		return ledger, "already_owned"
	end
	for _, prerequisite in item.prerequisites do
		if not ledger.owned[prerequisite] then
			return ledger, "missing_prerequisite"
		end
	end
	if ledger.wallet < item.price then
		return ledger, "unaffordable"
	end
	local result = table.clone(ledger)
	result.wallet -= item.price
	result.owned = table.clone(ledger.owned)
	result.owned[item.id] = true
	result.requests = table.clone(ledger.requests)
	result.requests[requestId] = true
	return result, nil
end

return Ledger
