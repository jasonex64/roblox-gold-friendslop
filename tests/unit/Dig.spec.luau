--!strict
local Dig = require("../../src/shared/Pure/Dig")
local Batch = require("../../src/shared/Pure/Batch")
local function setup()
	local draws = 0
	local dig = Dig.new({ bucketBatches = 2, digSeconds = 1 }, Batch, function(count)
		draws += 1
		return { kind = tostring(count), baseValue = 12, sourceMultiplier = 1 }
	end)
	local request = { id = "a", source = "Bank", digger = "alice", now = 0, distance = 0 }
	return dig, request, function()
		return draws
	end
end
return {
	["DIG-1 full duration, repeated requests and capacity"] = function(t)
		local dig, req, draws = setup()
		t.equal(dig.start(req, "running"), "started")
		t.equal(dig.start(req, "running"), "over_rate")
		t.equal(dig.step(0.999, 0, "running", "Bank"), "digging")
		t.equal(next(dig.state.batches), nil)
		t.equal(draws(), 0)
		t.equal(dig.step(1, 0, "running", "Bank"), "created")
		t.equal(dig.step(1, 0, "running", "Bank"), "idle")
		req.id = "b"
		req.now = 1
		t.equal(dig.start(req, "running"), "started")
		t.equal(dig.step(2, 0, "running", "Bank"), "created")
		req.id = "c"
		req.now = 2
		local state = dig.state
		t.equal(dig.start(req, "running"), "full_capacity")
		t.equal(dig.state, state)
		t.equal(draws(), 2)
	end,
	["DIG-1 rejected phase and distance leave state unchanged"] = function(t)
		local dig, req, draws = setup()
		local state = dig.state
		t.equal(dig.start(req, "ended"), "wrong_phase")
		req.distance = 9
		t.equal(dig.start(req, "running"), "out_of_range")
		t.equal(dig.state, state)
		t.equal(dig.pending, nil)
		t.equal(draws(), 0)
	end,
	["DIG-2 cancellation and movement never reroll completed batches"] = function(t)
		local dig, req, draws = setup()
		dig.start(req, "running")
		dig.cancel()
		t.equal(dig.step(1, 0, "running", "Bank"), "idle")
		t.equal(draws(), 0)
		dig.start(req, "running")
		t.equal(dig.step(0.5, 9, "running"), "cancelled")
		t.equal(draws(), 0)
		dig.start(req, "running")
		dig.step(1, 0, "running", "Bank")
		local item = dig.state.batches.a
		dig.cancel()
		dig.step(5, 100, "running")
		t.equal(dig.state.batches.a, item)
		t.equal(item.source, "Bank")
		t.equal(item.digger, "alice")
		t.equal(draws(), 1)
		req.id = "b"
		req.now = 5
		dig.start(req, "running")
		t.equal(dig.step(6, 0, "ended", "Bank"), "cancelled")
		t.equal(draws(), 1)
	end,
	["DIG-3 opening counts are per controller and only count created batches"] = function(t)
		local a, req = setup()
		local b = setup()
		a.start(req, "running")
		a.step(1, 0, "running", "Bank")
		a.cancel()
		t.equal(a.openingCount, 1)
		t.equal(b.openingCount, 0)
	end,
	["DIG-2 changing pads cancels pending dig and snapshots source quality"] = function(t)
		local dig = Dig.new({ bucketBatches = 2, digSeconds = 1 }, Batch, function(_, req)
			return { kind = "Gold", baseValue = 12, sourceMultiplier = req.multiplier }
		end)
		local req = {
			id = "a",
			source = "QualityBank",
			multiplier = 2,
			digger = "alice",
			now = 0,
			distance = 0,
		}
		dig.start(req, "running")
		t.equal(dig.step(1, 0, "running", "OtherBank"), "cancelled")
		t.equal(dig.openingCount, 0)
		dig.start(req, "running")
		req.multiplier = 99
		t.equal(dig.step(1, 0, "running", "QualityBank"), "created")
		t.equal(dig.state.batches.a.outcome.sourceMultiplier, 2)
		t.equal(dig.state.batches.a.source, "QualityBank")
	end,
}
