--!strict
-- Per-player shift credit for the results screen. The server records only
-- committed actions; amounts are dirt or batch counts, or money for sold/funded.
local Contributions = {}

export type Totals =
	{ dug: number, processed: number, loaded: number, sold: number, funded: number }
export type State = {
	players: { [string]: Totals },
	order: { string },
	events: { [string]: boolean },
}
export type Row = { player: string, totals: Totals }

-- IEEE-754 exact-integer bound, not a gameplay limit or tuning value.
local MAX_INTEGER = 2 ^ 53 - 1

local KINDS = { dug = true, processed = true, loaded = true, sold = true, funded = true }

function Contributions.new(): State
	return { players = {}, order = {}, events = {} }
end

-- Event IDs share one namespace for the whole shift; a retried event is a no-op.
-- Players stay in the summary after leaving, so their credit is never lost.
function Contributions.record(
	state: State,
	player: string,
	kind: string,
	amount: number,
	eventId: string
): (State, string?)
	assert(player ~= "", "Contributions: player must not be empty")
	assert(eventId ~= "", "Contributions: eventId must not be empty")
	assert(KINDS[kind], "Contributions: unknown kind " .. kind)
	assert(
		amount > 0 and amount <= MAX_INTEGER and amount % 1 == 0,
		"Contributions: amount must be a positive safe integer"
	)
	if state.events[eventId] then
		return state, "duplicate_event"
	end
	local result = table.clone(state)
	result.players = table.clone(state.players)
	local previous = state.players[player]
	local totals: Totals
	if previous then
		totals = table.clone(previous)
	else
		totals = { dug = 0, processed = 0, loaded = 0, sold = 0, funded = 0 }
		result.order = table.clone(state.order)
		table.insert(result.order, player)
	end
	local current = (totals :: any)[kind] :: number
	assert(amount <= MAX_INTEGER - current, "Contributions: total overflow");
	(totals :: any)[kind] = current + amount
	result.players[player] = table.freeze(totals)
	result.events = table.clone(state.events)
	result.events[eventId] = true
	return result, nil
end

function Contributions.summary(state: State): { Row }
	local rows = {}
	for _, player in state.order do
		table.insert(rows, { player = player, totals = state.players[player] })
	end
	return rows
end

return Contributions
