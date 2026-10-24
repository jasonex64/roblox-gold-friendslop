--!strict
local Machine = require("../../src/shared/Pure/Machine")
local Sluice = require("../../src/shared/Pure/Sluice")
local Batch = require("../../src/shared/Pure/Batch")
local Crew = require("../../src/shared/Pure/Crew")
local Bin = require("../../src/shared/Pure/Bin")
local Economy = require("../../src/shared/Pure/Economy")
local Ledger = require("../../src/shared/Pure/Ledger")
local Config = require("../../src/shared/Config")
local function setup(count, config)
	local crew = Crew.new(config)
	local machine, controllers, digs, sifts = Machine.new(config, Sluice, Batch), {}, {}, {}
	for i = 1, count do
		local id = tostring(i)
		crew.join(id)
		digs[id] = { state = { batches = {} }, sifting = false, openingCount = 0 }
		sifts[id] = { outputs = {} }
		controllers[id] = Economy.new(config, digs[id], sifts[id], Batch, Ledger)
	end
	crew.start(0)
	machine.start(count)
	local bin = Bin.new(config, crew)
	bin.start("run", count)
	local function dirt(id, key, value)
		local item = table.freeze({
			id = key,
			source = "Bank",
			digger = id,
			status = "queued",
			active = false,
			outcome = table.freeze({
				kind = "Gold Flakes",
				baseValue = value,
				sourceMultiplier = 1,
			}),
		})
		digs[id].state.batches[key] = item
		return item
	end
	local function build()
		controllers["1"].ledger.wallet = machine.settings.price
		assert(
			machine.contribute("1", "Alice", controllers["1"], machine.settings.price, "build")
				== "sluice_built"
		)
	end
	return machine, crew, controllers, digs, sifts, bin, dirt, build
end
return {
	["MACHINE sizes and competing final contributions preserve money and haul"] = function(t)
		for count = 1, 4 do
			local m, crew, c = setup(count, Config)
			t.equal(m.settings.price, 200 * count)
			t.equal(m.settings.lanes, count)
			t.equal(m.settings.processSeconds, 4)
			t.equal(m.settings.outputCapacity, 20 * count)
			c["1"].ledger.wallet = m.settings.price + 50
			crew.haul = 999
			t.equal(
				m.contribute("1", "Alice", c["1"], m.settings.price - 1, "first"),
				"contributed"
			)
			local result, charged = m.contribute("1", "Alice", c["1"], 100, "final")
			t.equal(result, "sluice_built")
			t.equal(charged, 1)
			t.equal(c["1"].ledger.wallet, 50)
			t.equal(m.contribute("1", "Alice", c["1"], 1, "final"), "duplicate_request")
			t.equal(m.contribute("1", "Alice", c["1"], 1, "racing-final"), "already_built")
			t.equal(m.contributors["1"].amount, m.settings.price)
			t.equal(crew.haul, 999)
		end
	end,
	["MACHINE rejected contributions never charge or create records"] = function(t)
		local m, _, c = setup(1, Config)
		local state, ledger = m.state, c["1"].ledger
		t.equal(m.contribute("1", "Alice", c["1"], 5, "poor"), "insufficient_funds")
		t.equal(m.state, state)
		t.equal(c["1"].ledger, ledger)
		t.equal(next(m.contributors), nil)
		for _, amount in { 0, -1, 0 / 0, math.huge, 1.5 } do
			t.errors(function()
				m.contribute("1", "Alice", c["1"], amount, "bad")
			end)
			t.equal(c["1"].ledger, ledger)
		end
	end,
	["MACHINE bucket and bin loads preserve outcomes and invalidate stale transfers"] = function(t)
		local m, _, _, d, _, bin, dirt, build = setup(2, Config)
		local a = dirt("1", "a", 12)
		t.equal(m.load("1", d["1"], bin, "bucket", "early", 0), "not_built")
		t.equal(d["1"].state.batches.a, a)
		build()
		t.equal(bin.transfer("1", d["1"], "deposit", "run", bin.revision, "all", true), "deposited")
		local revision = bin.revision
		t.equal(m.load("2", d["2"], bin, "bin", "load-a", 0), "sluice_loaded")
		t.equal(bin.revision, revision + 1)
		t.equal(bin.count(), 0)
		t.equal(m.batches.a.outcome, a.outcome)
		t.equal(m.batches.a.digger, "1")
		t.equal(d["2"].openingCount, 0)
		dirt("2", "b", 19)
		t.equal(m.load("2", d["2"], bin, "bucket", "load-a", 0), "duplicate_request")
		t.equal(m.load("2", d["2"], bin, "bucket", "load-b", 0), "sluice_loaded")
		dirt("2", "c", 20)
		t.equal(m.load("2", d["2"], bin, "bucket", "load-c", 0), "lanes_full")
		t.equal(m.step(3.999, true), 0)
		t.equal(m.step(4, true), 2)
		t.equal(m.outputs.a.outcome, a.outcome)
		t.equal(m.outputs.a.value, 12)
		t.equal(m.outputs.b.value, 19)
		t.equal(m.step(5, true), 0)
	end,
	["MACHINE combined shop sale pays personal and shared once and resumes AFK seller"] = function(
		t
	)
		local m, crew, c, d, s, bin, dirt, build = setup(2, Config)
		build()
		dirt("1", "shared", 13)
		m.load("1", d["1"], bin, "bucket", "load", 0)
		m.step(4, true)
		local own = dirt("2", "personal", 8)
		d["2"].state.batches.personal =
			Batch.transition(Batch.transition(own, "processing"), "completed")
		s["2"].outputs.personal = { id = "personal", value = 8 }
		local result, share, total = crew.sale("2", c["2"], c, "combined", 70, m)
		t.equal(result, "sold")
		t.equal(share, 21)
		t.equal(total, 21)
		t.equal(c["1"].ledger.wallet, 0)
		t.equal(c["2"].ledger.wallet, 21)
		t.equal(crew.haul, 21)
		t.equal(next(m.outputs), nil)
		t.equal(next(m.state.output), nil)
		t.equal(crew.sale("2", c["2"], c, "combined", 70, m), "duplicate_request")
		t.equal(crew.sale("1", c["1"], c, "empty", 70, m), "nothing_to_sell")
		t.equal(crew.haul, 21)
	end,
	["MACHINE payout failure rolls back both inventories and machine output"] = function(t)
		local m, crew, c, d, _, bin, dirt, build = setup(2, Config)
		build()
		dirt("1", "shared", 12)
		m.load("1", d["1"], bin, "bucket", "load", 0)
		m.step(4, true)
		c["2"].ledger.wallet = 2 ^ 53 - 1
		local state = m.state
		t.errors(function()
			crew.sale("1", c["1"], c, "overflow", 4, m)
		end)
		t.equal(m.state, state)
		t.equal(m.outputs.shared.value, 12)
		t.equal(crew.haul, 0)
		t.equal(c["1"].ledger.requests.overflow, nil)
		c["2"].ledger.wallet = 0
		t.equal(crew.sale("1", c["1"], c, "overflow", 4, m), "sold")
		t.equal(c["1"].ledger.wallet, 6)
		t.equal(c["2"].ledger.wallet, 6)
	end,
	["MACHINE reserved output stops loading and sales reopen space"] = function(t)
		local config = table.clone(Config)
		config.sluiceOutputPerMember = 1
		local m, crew, c, d, _, bin, dirt, build = setup(1, config)
		build()
		dirt("1", "a", 12)
		m.load("1", d["1"], bin, "bucket", "a", 0)
		m.step(4, true)
		local b = dirt("1", "b", 9)
		t.equal(m.load("1", d["1"], bin, "bucket", "b", 4), "output_full")
		t.equal(d["1"].state.batches.b, b)
		crew.sale("1", c["1"], c, "sell", 4, m)
		t.equal(m.load("1", d["1"], bin, "bucket", "b", 4), "sluice_loaded")
	end,
	["MACHINE cutoff wins over due completion; reset loses unfinished funding without payout"] = function(
		t
	)
		local m, crew, c, d, _, bin, dirt, build = setup(1, Config)
		build()
		dirt("1", "late", 12)
		m.load("1", d["1"], bin, "bucket", "load", 0)
		t.equal(m.step(4, false), 0)
		t.equal(next(m.outputs), nil)
		m.clear()
		t.equal(m.state, nil)
		t.equal(next(m.batches), nil)
		t.equal(next(m.contributors), nil)
		m.start(1)
		c["1"].ledger.wallet = 17
		m.contribute("1", "Alice", c["1"], 17, "partial")
		m.clear()
		t.equal(c["1"].ledger.wallet, 0)
		t.equal(crew.haul, 0)
		m.start(1)
		t.equal(m.state.funded, 0)
		t.equal(m.state.built, false)
	end,
}
