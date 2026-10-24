--!strict
local Bin = require("../../src/shared/Pure/Bin")
local Batch = require("../../src/shared/Pure/Batch")
local Dig = require("../../src/shared/Pure/Dig")
local Sift = require("../../src/shared/Pure/Sift")
local SkillCheck = require("../../src/shared/Pure/SkillCheck")
local Config = require("../../src/shared/Config")
local function setup()
	local config = table.clone(Config)
	config.binBatchesPerMember = 2
	local crew = { connected = { a = true, b = true }, admitted = { a = true, b = true } }
	local bin = Bin.new(config, crew)
	bin.start("run", 2)
	local draws = 0
	local function digger()
		return Dig.new(config, Batch, function()
			draws += 1
			return { kind = "Gold Flakes", baseValue = 12, sourceMultiplier = 1 }
		end)
	end
	local a, b = digger(), digger()
	local function dig(d, id, owner)
		local now = d.openingCount * config.digSeconds
		assert(
			d.start(
				{ id = id, source = "Bank", digger = owner, distance = 0, now = now },
				"running"
			) == "started"
		)
		assert(d.step(now + config.digSeconds, 0, "running", "Bank") == "created")
	end
	local function move(id, d, action)
		return bin.transfer(id, d, action, "run", bin.revision, 1, true)
	end
	return bin, crew, a, b, dig, move, function()
		return draws
	end
end
return {
	["BIN quantities selected and all transfers are atomic and respect space"] = function(t)
		local bin, _, a, b, dig = setup()
		for i = 1, 5 do
			dig(a, tostring(i), "a")
		end
		for _, amount in { 0, -1, 1.5, math.huge, 0 / 0, "bad", {} } do
			t.equal(
				bin.transfer("a", a, "deposit", "run", bin.revision, amount, true),
				"invalid_request"
			)
		end
		t.equal(bin.transfer("a", a, "deposit", "run", 0, 5, true), "bin_quantity_changed")
		t.equal(bin.count(), 0)
		local result, amount = bin.transfer("a", a, "deposit", "run", 0, "all", true)
		t.equal(result, "deposited")
		t.equal(amount, 4)
		t.equal(bin.count(), 4)
		t.equal(a.state.batches["5"].digger, "a")
		t.equal(bin.transfer("b", b, "withdraw", "run", bin.revision, 2, true), "withdrawn")
		t.equal(bin.count(), 2)
		t.equal(
			bin.transfer("a", a, "withdraw", "run", bin.revision, 3, true),
			"bin_quantity_changed"
		)
		t.equal(bin.count(), 2)
		t.equal(bin.transfer("b", b, "withdraw", "run", bin.revision, "all", true), "withdrawn")
		t.equal(bin.count(), 0)
	end,
	["BIN default sizes follow the locked starting crew"] = function(t)
		for members = 1, Config.crewCapacity do
			local bin = Bin.new(Config, {})
			bin.start("sizes", members)
			t.equal(bin.capacity, members * 5)
		end
	end,
	["BIN-1 transfer preserves identity loot provenance and opening count through teammate sift"] = function(
		t
	)
		local bin, _, a, b, dig, move, draws = setup()
		dig(a, "first", "a")
		local original = a.state.batches.first
		for _ = 1, 3 do
			t.equal(move("a", a, "deposit"), "deposited")
			t.equal(a.state.batches.first, nil)
			t.equal(bin.batches.first, original)
			t.equal(move("a", a, "withdraw"), "withdrawn")
		end
		move("a", a, "deposit")
		move("b", b, "withdraw")
		t.equal(b.state.batches.first, original)
		t.equal(b.openingCount, 0)
		t.equal(a.openingCount, 1)
		t.equal(draws(), 1)
		local sift = Sift.new(Config, b, Batch, SkillCheck, function()
			return 0.5
		end)
		t.equal(sift.start(0, "sift", 0, 1), "started")
		local result, find = sift.step(Config.siftSeconds, true)
		t.equal(result, "completed")
		t.equal(find.digger, "a")
		t.equal(find.source, "Bank")
		t.equal(find.outcome, original.outcome)
		t.equal(bin.count(), 0)
	end,
	["BIN-2 full empty and foreign bucket capacity preserve all inventory"] = function(t)
		local bin, _, a, b, dig, move = setup()
		t.equal(move("a", a, "deposit"), "bucket_empty")
		t.equal(move("b", b, "withdraw"), "bin_empty")
		for i = 1, bin.capacity do
			dig(a, tostring(i), "a")
			move("a", a, "deposit")
		end
		dig(a, "overflow", "a")
		local old = a.state
		t.equal(move("a", a, "deposit"), "bin_full")
		t.equal(a.state, old)
		for _ = 1, bin.capacity do
			move("b", b, "withdraw")
		end
		move("a", a, "deposit")
		move("b", b, "withdraw")
		t.equal(bin.count(), 0)
		t.equal(
			b.start({ id = "new", source = "Bank", digger = "b", distance = 0, now = 0 }, "running"),
			"full_capacity"
		)
		dig(a, "extra", "a")
		move("a", a, "deposit")
		t.equal(move("b", b, "withdraw"), "full_capacity")
		t.equal(bin.count(), 1)
	end,
	["BIN-3 competing and repeated requests move the last item only once"] = function(t)
		local bin, _, a, b, dig, move = setup()
		dig(a, "last", "a")
		local revision = bin.revision
		move("a", a, "deposit")
		t.equal(bin.transfer("a", a, "deposit", "run", revision, 1, true), "bin_changed")
		revision = bin.revision
		t.equal(bin.transfer("b", b, "withdraw", "run", revision, 1, true), "withdrawn")
		t.equal(bin.transfer("a", a, "withdraw", "run", revision, 1, true), "bin_changed")
		t.equal(bin.count(), 0)
		t.equal(a.state.batches.last, nil)
		t.equal(b.state.batches.last.digger, "a")
	end,
	["BIN-4 gates reject stale late disconnected busy and cutoff requests"] = function(t)
		local bin, crew, a, _, dig = setup()
		dig(a, "keep", "a")
		local old = a.state
		t.equal(bin.transfer("a", a, "other", "run", 0, 1, true), "invalid_request")
		t.equal(bin.transfer("a", a, "deposit", "old", 0, 1, true), "stale_run")
		t.equal(bin.transfer("a", a, "deposit", "run", 0, 1, false), "wrong_phase")
		t.equal(bin.transfer("late", a, "deposit", "run", 0, 1, true), "waiting_for_crew")
		crew.connected.a = nil
		t.equal(bin.transfer("a", a, "deposit", "run", 0, 1, true), "waiting_for_crew")
		crew.connected.a = true
		a.pending = {}
		t.equal(bin.transfer("a", a, "deposit", "run", 0, 1, true), "busy_digging")
		a.pending = nil
		a.sifting = true
		t.equal(bin.transfer("a", a, "deposit", "run", 0, 1, true), "busy_sifting")
		t.equal(a.state, old)
		t.equal(bin.revision, 0)
	end,
	["BIN-5 departure retains dirt and capacity; bell and replay clear without payout"] = function(
		t
	)
		local bin, crew, a, b, dig, move = setup()
		dig(a, "saved", "a")
		move("a", a, "deposit")
		crew.connected.a, crew.admitted.a = nil, nil
		t.equal(bin.capacity, 4)
		t.equal(move("b", b, "withdraw"), "withdrawn")
		move("b", b, "deposit")
		bin.clear()
		t.equal(bin.count(), 0)
		bin.reset()
		t.equal(bin.capacity, 0)
		bin.start("next", 1)
		t.equal(bin.capacity, 2)
		t.equal(bin.transfer("b", b, "withdraw", "run", bin.revision, 1, true), "stale_run")
	end,
	["BIN-6 invariant collision fails before either inventory changes"] = function(t)
		local bin, _, a, _, dig, move = setup()
		dig(a, "same", "a")
		bin.batches.same = a.state.batches.same
		local old = a.state
		t.errors(function()
			move("a", a, "deposit")
		end)
		t.equal(a.state, old)
		t.equal(bin.count(), 1)
		t.equal(bin.revision, 0)
	end,
}
