--!strict
local Contributions = require("../../src/shared/Pure/Contributions")

local function namedError(t, fn, text)
	local ok, message = pcall(fn)
	t.equal(ok, false)
	t.equal(string.find(tostring(message), text, 1, true) ~= nil, true)
end

return {
	["CREDIT-1 each kind adds to one player's own total without mutating input"] = function(t)
		local state = Contributions.new()
		local a = Contributions.record(state, "ana", "dug", 1, "e1")
		local b = Contributions.record(a, "ana", "dug", 1, "e2")
		local c = Contributions.record(b, "ana", "processed", 1, "e3")
		local d = Contributions.record(c, "ana", "loaded", 2, "e4")
		local e = Contributions.record(d, "ana", "sold", 42, "e5")
		local f = Contributions.record(e, "ana", "funded", 150, "e6")
		local totals = f.players.ana
		t.equal(totals.dug, 2)
		t.equal(totals.processed, 1)
		t.equal(totals.loaded, 2)
		t.equal(totals.sold, 42)
		t.equal(totals.funded, 150)
		t.equal(a.players.ana.dug, 1)
		t.equal(next(state.players), nil)
		t.equal(next(state.events), nil)
	end,
	["CREDIT-2 retries change nothing and bad input errors by name"] = function(t)
		local state = Contributions.record(Contributions.new(), "ana", "sold", 30, "sale:1")
		local replay, reason = Contributions.record(state, "ana", "sold", 30, "sale:1")
		t.equal(replay, state)
		t.equal(reason, "duplicate_event")
		t.equal(replay.players.ana.sold, 30)
		-- Event IDs are shift-wide, so another player cannot reuse one either.
		local other, otherReason = Contributions.record(state, "ben", "dug", 1, "sale:1")
		t.equal(other, state)
		t.equal(otherReason, "duplicate_event")
		namedError(t, function()
			Contributions.record(state, "ana", "hauled", 1, "e2")
		end, "unknown kind hauled")
		namedError(t, function()
			Contributions.record(state, "ana", "sold", 0, "e3")
		end, "amount must be a positive safe integer")
		namedError(t, function()
			Contributions.record(state, "ana", "dug", 1.5, "e4")
		end, "amount must be a positive safe integer")
	end,
	["CREDIT-3 summary keeps first-contribution order and sold adds up to Crew Haul"] = function(t)
		local state = Contributions.new()
		state = Contributions.record(state, "cat", "dug", 3, "e1")
		state = Contributions.record(state, "ana", "sold", 50, "e2")
		state = Contributions.record(state, "cat", "sold", 25, "e3")
		-- ben funds the sluice and then leaves; his credit stays.
		state = Contributions.record(state, "ben", "funded", 200, "e4")
		local rows = Contributions.summary(state)
		t.equal(#rows, 3)
		t.equal(rows[1].player, "cat")
		t.equal(rows[2].player, "ana")
		t.equal(rows[3].player, "ben")
		t.equal(rows[3].totals.funded, 200)
		local haul = 0
		for _, row in rows do
			haul += row.totals.sold
		end
		t.equal(haul, 75)
		t.equal(#Contributions.summary(Contributions.new()), 0)
	end,
}
