--!strict
local Sluice = require("../../src/shared/Pure/Sluice")

local function config()
	return {
		price = 400,
		lanes = 2,
		processSeconds = 4,
		outputCapacity = 3,
		tierTwoPrice = 500,
		tierTwoSeconds = 2.5,
		hopperPrice = 300,
	}
end

local function plain(now: number, seconds: number): number
	return now + seconds
end

local function built()
	local state = Sluice.contribute(Sluice.new(config()), config(), 400, 400, "fund")
	return state
end

local function namedError(t, fn, text)
	local ok, message = pcall(fn)
	t.equal(ok, false)
	t.equal(string.find(tostring(message), text, 1, true) ~= nil, true)
end

return {
	["SLUICE-1 contributions are capped at the remaining price and build exactly once"] = function(
		t
	)
		local cfg = config()
		local state = Sluice.new(cfg)
		local a, chargedA, reasonA = Sluice.contribute(state, cfg, 300, 250, "a:1")
		t.equal(reasonA, nil)
		t.equal(chargedA, 250)
		t.equal(a.funded, 250)
		t.equal(a.built, false)
		t.equal(state.funded, 0)
		t.equal(next(state.requests), nil)
		-- A competing contribution larger than the remainder pays only the remainder.
		local b, chargedB, reasonB = Sluice.contribute(a, cfg, 500, 500, "b:1")
		t.equal(reasonB, nil)
		t.equal(chargedB, 150)
		t.equal(b.funded, 400)
		t.equal(b.built, true)
		local c, chargedC, reasonC = Sluice.contribute(b, cfg, 500, 10, "c:1")
		t.equal(c, b)
		t.equal(chargedC, 0)
		t.equal(reasonC, "already_built")
	end,
	["SLUICE-2 insufficient funds and repeated requests leave state unchanged"] = function(t)
		local cfg = config()
		local state = Sluice.new(cfg)
		local poor, charged, reason = Sluice.contribute(state, cfg, 99, 100, "a:1")
		t.equal(poor, state)
		t.equal(charged, 0)
		t.equal(reason, "insufficient_funds")
		-- The rejected ID was not consumed, so a funded retry with it succeeds.
		local paid, chargedPaid = Sluice.contribute(state, cfg, 100, 100, "a:1")
		t.equal(chargedPaid, 100)
		local replay, chargedReplay, duplicate = Sluice.contribute(paid, cfg, 100, 100, "a:1")
		t.equal(replay, paid)
		t.equal(chargedReplay, 0)
		t.equal(duplicate, "duplicate_request")
		t.equal(replay.funded, 100)
		namedError(t, function()
			Sluice.contribute(state, cfg, 100, 0, "a:2")
		end, "amount must be positive")
		namedError(t, function()
			Sluice.contribute(state, cfg, 100, 1.5, "a:3")
		end, "amount must be a nonnegative safe integer")
	end,
	["SLUICE-3 load needs a built sluice and a free lane, lowest lane first"] = function(t)
		local cfg = config()
		local unbuilt, reason = Sluice.load(Sluice.new(cfg), cfg, "dirt1", 0, plain)
		t.equal(reason, "not_built")
		t.equal(next(unbuilt.lanes), nil)
		local state = built()
		local one = Sluice.load(state, cfg, "dirt1", 10, plain)
		local two = Sluice.load(one, cfg, "dirt2", 11, plain)
		t.equal(two.lanes[1].batch, "dirt1")
		t.equal(two.lanes[1].readyAt, 14)
		t.equal(two.lanes[2].batch, "dirt2")
		t.equal(next(state.lanes), nil)
		local three, full = Sluice.load(two, cfg, "dirt3", 12, plain)
		t.equal(three, two)
		t.equal(full, "lanes_full")
	end,
	["SLUICE-4 collect moves batches to output exactly at their ready time"] = function(t)
		local cfg = config()
		local loaded =
			Sluice.load(Sluice.load(built(), cfg, "dirt1", 10, plain), cfg, "dirt2", 11, plain)
		local early, none = Sluice.collect(loaded, cfg, 13.999)
		t.equal(early, loaded)
		t.equal(#none, 0)
		local first, finished = Sluice.collect(loaded, cfg, 14)
		t.equal(#finished, 1)
		t.equal(finished[1], "dirt1")
		t.equal(first.lanes[1], nil)
		t.equal(first.output.dirt1, true)
		t.equal(loaded.lanes[1].batch, "dirt1")
		local both, rest = Sluice.collect(first, cfg, 15)
		t.equal(rest[1], "dirt2")
		t.equal(both.output.dirt2, true)
		t.equal(next(both.lanes), nil)
	end,
	["SLUICE-5 a batch is processed once and full output pauses loading"] = function(t)
		local cfg = config()
		local state = Sluice.load(built(), cfg, "dirt1", 0, plain)
		local again, duplicate = Sluice.load(state, cfg, "dirt1", 1, plain)
		t.equal(again, state)
		t.equal(duplicate, "duplicate_batch")
		local done = Sluice.collect(state, cfg, 4)
		local after, stillDuplicate = Sluice.load(done, cfg, "dirt1", 5, plain)
		t.equal(after, done)
		t.equal(stillDuplicate, "duplicate_batch")
		-- Output capacity counts finished output plus batches already in lanes.
		local two = Sluice.load(done, cfg, "dirt2", 5, plain)
		local three = Sluice.load(two, cfg, "dirt3", 5, plain)
		local blocked, full = Sluice.load(Sluice.collect(three, cfg, 9), cfg, "dirt4", 9, plain)
		t.equal(full, "output_full")
		t.equal(blocked.output.dirt4, nil)
		local freed = Sluice.take(blocked, { "dirt1" })
		local resumed, reason = Sluice.load(freed, cfg, "dirt4", 9, plain)
		t.equal(reason, nil)
		t.equal(resumed.lanes[1].batch, "dirt4")
	end,
	["SLUICE-6 take removes shared output once"] = function(t)
		local cfg = config()
		local state = Sluice.collect(Sluice.load(built(), cfg, "dirt1", 0, plain), cfg, 4)
		local taken = Sluice.take(state, { "dirt1" })
		t.equal(taken.output.dirt1, nil)
		t.equal(state.output.dirt1, true)
		namedError(t, function()
			Sluice.take(taken, { "dirt1" })
		end, "not in output dirt1")
		namedError(t, function()
			Sluice.take(state, { "dirt1", "dirt1" })
		end, "not in output dirt1")
		namedError(t, function()
			Sluice.new({
				price = 0,
				lanes = 1,
				processSeconds = 4,
				outputCapacity = 1,
				tierTwoPrice = 1,
				tierTwoSeconds = 2,
				hopperPrice = 1,
			})
		end, "price must be positive")
	end,
	["SLUICE-7 tier two is funded like the build, only after it, and built once"] = function(t)
		local cfg = config()
		local early, chargedEarly, notBuilt = Sluice.upgrade(Sluice.new(cfg), cfg, 500, 100, "a:1")
		t.equal(notBuilt, "not_built")
		t.equal(chargedEarly, 0)
		t.equal(early.tierTwoFunded, 0)
		local state = built()
		local poor, chargedPoor, reason = Sluice.upgrade(state, cfg, 99, 100, "a:1")
		t.equal(poor, state)
		t.equal(chargedPoor, 0)
		t.equal(reason, "insufficient_funds")
		local a, chargedA = Sluice.upgrade(state, cfg, 300, 300, "a:1")
		t.equal(chargedA, 300)
		t.equal(a.tierTwoFunded, 300)
		t.equal(a.tierTwo, false)
		t.equal(state.tierTwoFunded, 0)
		local replay, chargedReplay, duplicate = Sluice.upgrade(a, cfg, 300, 300, "a:1")
		t.equal(replay, a)
		t.equal(chargedReplay, 0)
		t.equal(duplicate, "duplicate_request")
		-- A competing contribution larger than the remainder pays only the remainder.
		local b, chargedB = Sluice.upgrade(a, cfg, 900, 900, "b:1")
		t.equal(chargedB, 200)
		t.equal(b.tierTwoFunded, 500)
		t.equal(b.tierTwo, true)
		t.equal(b.funded, 400)
		local c, chargedC, already = Sluice.upgrade(b, cfg, 900, 10, "c:1")
		t.equal(c, b)
		t.equal(chargedC, 0)
		t.equal(already, "already_upgraded")
		-- Build and tier-two request IDs share one namespace.
		local _, _, shared = Sluice.upgrade(state, cfg, 100, 100, "fund")
		t.equal(shared, "duplicate_request")
	end,
	["SLUICE-8 lanes loaded after tier two use its speed; running lanes keep theirs"] = function(t)
		local cfg = config()
		local slow = Sluice.load(built(), cfg, "dirt1", 10, plain)
		t.equal(slow.lanes[1].readyAt, 14)
		local upgraded = Sluice.upgrade(slow, cfg, 500, 500, "up")
		t.equal(Sluice.processSeconds(upgraded, cfg), 2.5)
		local fast = Sluice.load(upgraded, cfg, "dirt2", 11, plain)
		t.equal(fast.lanes[1].readyAt, 14)
		t.equal(fast.lanes[2].readyAt, 13.5)
		-- The injected scheduler decides the finish time from load time and seconds.
		local seen
		local rushed = Sluice.load(upgraded, cfg, "dirt2", 11, function(now, seconds)
			seen = { now, seconds }
			return now + seconds / 2
		end)
		t.equal(seen[1], 11)
		t.equal(seen[2], 2.5)
		t.equal(rushed.lanes[2].readyAt, 12.25)
		namedError(t, function()
			Sluice.load(upgraded, cfg, "dirt3", 11, function(now)
				return now
			end)
		end, "invalid lane finish time")
	end,
	["SLUICE-9 the hopper is funded after the build, in either order with tier two"] = function(t)
		local cfg = config()
		local _, early, notBuilt = Sluice.hopper(Sluice.new(cfg), cfg, 500, 100, "a:1")
		t.equal(notBuilt, "not_built")
		t.equal(early, 0)
		-- Hopper first, then tier two.
		local a, chargedA = Sluice.hopper(built(), cfg, 500, 200, "a:1")
		t.equal(chargedA, 200)
		t.equal(a.hopper, false)
		local b, chargedB, reasonB = Sluice.hopper(a, cfg, 500, 500, "b:1")
		t.equal(reasonB, nil)
		t.equal(chargedB, 100)
		t.equal(b.hopper, true)
		t.equal(b.hopperFunded, 300)
		t.equal(b.tierTwo, false)
		local _, _, already = Sluice.hopper(b, cfg, 500, 1, "c:1")
		t.equal(already, "hopper_already_built")
		local both = Sluice.upgrade(b, cfg, 500, 500, "d:1")
		t.equal(both.tierTwo and both.hopper, true)
		-- Tier two first, then the hopper; request IDs stay shared.
		local tier = Sluice.upgrade(built(), cfg, 500, 500, "e:1")
		local _, _, duplicate = Sluice.hopper(tier, cfg, 500, 300, "e:1")
		t.equal(duplicate, "duplicate_request")
		local _, _, poor = Sluice.hopper(tier, cfg, 299, 300, "f:1")
		t.equal(poor, "insufficient_funds")
		local last = Sluice.hopper(tier, cfg, 300, 300, "f:1")
		t.equal(last.tierTwo and last.hopper, true)
	end,
}
