--!strict
local Machine = require("../../src/shared/Pure/Machine")
local Sluice = require("../../src/shared/Pure/Sluice")
local Batch = require("../../src/shared/Pure/Batch")
local Crew = require("../../src/shared/Pure/Crew")
local Bin = require("../../src/shared/Pure/Bin")
local Economy = require("../../src/shared/Pure/Economy")
local Ledger = require("../../src/shared/Pure/Ledger")
local Config = require("../../src/shared/Config")
local Timeline = require("../../src/shared/Pure/Timeline")
local function setup(count, config)
	local crew = Crew.new(config)
	local bin = Bin.new(config, crew)
	local machine, controllers, digs, sifts = Machine.new(config, Sluice, Batch, bin), {}, {}, {}
	for i = 1, count do
		local id = tostring(i)
		crew.join(id)
		digs[id] = { state = { batches = {} }, sifting = false, openingCount = 0 }
		sifts[id] = { outputs = {}, reserved = 0 }
		controllers[id] = Economy.new(config, digs[id], sifts[id], Batch, Ledger)
	end
	crew.start(0)
	machine.start(count)
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
	["MACHINE tier two is crew-funded after the build and never lowers haul"] = function(t)
		for count = 1, 4 do
			local m, crew, c, _, _, _, _, build = setup(count, Config)
			t.equal(m.settings.tierTwoPrice, 250 * count)
			t.equal(m.settings.tierTwoSeconds, 2.5)
			c["1"].ledger.wallet = 10_000
			crew.haul = 999
			t.equal(m.upgrade("1", "Alice", c["1"], 50, "early"), "not_built")
			t.equal(c["1"].ledger.wallet, 10_000)
			build()
			c["1"].ledger.wallet = 10_000
			local wallet = c["1"].ledger.wallet
			local result, charged = m.upgrade("1", "Alice", c["1"], 100, "first")
			t.equal(result, "upgrade_contributed")
			t.equal(charged, 100)
			t.equal(m.upgrade("1", "Alice", c["1"], 100, "first"), "duplicate_request")
			local final, rest = m.upgrade("1", "Alice", c["1"], 10_000, "final")
			t.equal(final, "tier_two_built")
			t.equal(rest, m.settings.tierTwoPrice - 100)
			t.equal(c["1"].ledger.wallet, wallet - m.settings.tierTwoPrice)
			t.equal(m.upgrade("1", "Alice", c["1"], 1, "late"), "already_upgraded")
			t.equal(m.contributors["1"].amount, m.settings.price + m.settings.tierTwoPrice)
			t.equal(crew.haul, 999)
		end
	end,
	["MACHINE lanes loaded after tier two run faster; the rush applies after 9:00"] = function(t)
		local m, _, c, d, s, _, dirt, build = setup(2, Config)
		build()
		dirt("1", "a", 10)
		m.transfer("1", d["1"], s["1"], "first")
		m.step(0, true)
		t.equal(m.state.lanes[1].readyAt, 4)
		c["1"].ledger.wallet = m.settings.tierTwoPrice
		m.upgrade("1", "Alice", c["1"], m.settings.tierTwoPrice, "tier")
		dirt("1", "b", 10)
		m.transfer("1", d["1"], s["1"], "second")
		m.step(1, true)
		t.equal(m.state.lanes[1].readyAt, 4)
		t.equal(m.state.lanes[2].readyAt, 3.5)
		-- Session injects Timeline.finishAt (shift started at 0 here).
		function m.finishAt(start, seconds)
			return Timeline.finishAt(start, seconds, Config)
		end
		m.step(4, true)
		dirt("1", "c", 10)
		m.transfer("1", d["1"], s["1"], "third")
		local load = Config.rushStart - 1
		m.step(load, true)
		local lane = m.state.lanes[1] or m.state.lanes[2]
		t.equal(lane.batch, "c")
		-- One second at normal speed, the remaining 1.5 s 25% faster.
		t.equal(lane.readyAt, Config.rushStart + 1.5 / (1 + Config.rushSpeedup))
	end,
	["MACHINE hopper feeds bin dirt into free lanes atomically and pauses when full"] = function(t)
		local m, crew, c, d, s, bin, dirt, build = setup(2, Config)
		t.equal(m.settings.hopperPrice, 150 * 2)
		build()
		c["1"].ledger.wallet = 10_000
		crew.haul = 7
		t.equal(m.hopper("1", "Alice", c["1"], 100, "first"), "hopper_contributed")
		-- Before it is built, bin dirt stays in the bin.
		for i = 1, 5 do
			dirt("2", string.format("b%d", i), 10 + i)
		end
		t.equal(bin.transfer("2", d["2"], "deposit", "run", bin.revision, "all", true), "deposited")
		local original = bin.batches.b1
		m.step(0, true)
		t.equal(bin.count(), 5)
		t.equal(m.dirtCount(), 0)
		local result, charged = m.hopper("1", "Alice", c["1"], 10_000, "final")
		t.equal(result, "hopper_built")
		t.equal(charged, 200)
		t.equal(m.hopper("1", "Alice", c["1"], 1, "late"), "hopper_already_built")
		t.equal(crew.haul, 7)
		-- Two lanes: two bin dirt move in, lowest IDs first, keeping their outcomes.
		local revision = bin.revision
		m.step(1, true)
		t.equal(bin.count(), 3)
		t.equal(bin.revision, revision + 1)
		t.equal(m.batches.b1.outcome, original.outcome)
		t.equal(m.batches.b1.status, "processing")
		t.equal(bin.batches.b1, nil)
		t.equal(m.state.lanes[1].batch, "b1")
		t.equal(m.state.lanes[2].batch, "b2")
		-- Lanes full: nothing moves and the bin revision is unchanged.
		m.step(2, true)
		t.equal(bin.count(), 3)
		t.equal(bin.revision, revision + 1)
		-- Manual dirt is loaded before bin dirt.
		dirt("1", "a1", 9)
		m.transfer("1", d["1"], s["1"], "manual")
		m.step(5, true)
		t.equal(m.state.lanes[1].batch, "a1")
		t.equal(m.state.lanes[2].batch, "b3")
		t.equal(bin.count(), 2)
		-- No dirt is ever in two places.
		for id in m.batches do
			t.equal(bin.batches[id], nil)
		end
	end,
	["MACHINE hopper pauses while sluice output is full"] = function(t)
		local m, _, c, d, _, bin, dirt, build = setup(1, Config)
		build()
		c["1"].ledger.wallet = m.settings.hopperPrice
		m.hopper("1", "Alice", c["1"], m.settings.hopperPrice, "hopper")
		local cap = m.settings.outputCapacity
		for i = 1, cap + 2 do
			dirt("1", string.format("b%03d", i), 5)
		end
		bin.capacity = cap + 2
		t.equal(bin.transfer("1", d["1"], "deposit", "run", bin.revision, "all", true), "deposited")
		local now = 0
		for _ = 1, cap + 2 do
			m.step(now, true)
			now += Config.sluiceProcessSeconds
		end
		m.step(now, true)
		t.equal(#m.queue, 0)
		t.equal(bin.count(), 2)
		local outputs = 0
		for _ in m.outputs do
			outputs += 1
		end
		t.equal(outputs, cap)
		local revision = bin.revision
		m.step(now + 100, true)
		t.equal(bin.count(), 2)
		t.equal(bin.revision, revision)
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
	["MACHINE quick transfer fills only twenty dirt including busy lanes across all crew sizes"] = function(
		t
	)
		for members = 1, 4 do
			local m, _, _, d, s, bin, dirt, build = setup(members, Config)
			build()
			for i = 1, 25 do
				dirt("1", string.format("a%02d", i), 12)
			end
			local original = d["1"].state.batches.a01
			local result, deposited, collected = m.transfer("1", d["1"], s["1"], "deposit")
			t.equal(result, "sluice_transferred")
			t.equal(deposited, 20)
			t.equal(collected, 0)
			t.equal(m.dirtCount(), 20)
			t.equal(bin.count(), 0)
			m.step(0, true)
			t.equal(m.dirtCount(), 20)
			t.equal(#m.queue, 20 - members)
			t.equal(m.batches.a01.outcome, original.outcome)
			t.equal(m.transfer("1", d["1"], s["1"], "repeat-full"), "sluice_no_transfer")
			t.equal(m.transfer("1", d["1"], s["1"], "deposit"), "duplicate_request")
			t.equal(m.step(3.999, true), 0)
			t.equal(m.step(4, true), members)
			t.equal(m.dirtCount(), 20 - members)
			t.equal(m.outputs.a01.digger, "1")
			t.equal(m.outputs.a01.value, 12)
		end
	end,
	["MACHINE output must be collected before shop sale; crew split and AFK remain"] = function(t)
		local m, crew, c, d, s, _, dirt, build = setup(2, Config)
		build()
		dirt("1", "shared", 13)
		m.transfer("1", d["1"], s["1"], "deposit")
		m.step(0, true)
		m.step(4, true)
		t.equal(crew.sale("2", c["2"], c, "uncollected", 4), "nothing_to_sell")
		t.equal(m.outputs.shared.value, 13)
		t.equal(crew.haul, 0)
		local own = dirt("2", "personal", 8)
		d["2"].state.batches.personal =
			Batch.transition(Batch.transition(own, "processing"), "completed")
		s["2"].outputs.personal = { id = "personal", value = 8 }
		local result, deposit, collect = m.transfer("2", d["2"], s["2"], "collect")
		t.equal(result, "sluice_transferred")
		t.equal(deposit, 0)
		t.equal(collect, 1)
		t.equal(next(m.outputs), nil)
		t.equal(s["2"].outputs.shared.digger, "1")
		t.equal(c["2"].ledger.wallet, 0)
		t.equal(crew.haul, 0)
		local sold, share, total = crew.sale("2", c["2"], c, "sale", 70)
		t.equal(sold, "sold")
		t.equal(share, 21)
		t.equal(total, 21)
		t.equal(c["1"].ledger.wallet, 0)
		t.equal(crew.haul, 21)
		t.equal(m.transfer("1", d["1"], s["1"], "race"), "sluice_no_transfer")
		t.equal(crew.sale("2", c["2"], c, "sale", 70), "duplicate_request")
	end,
	["MACHINE both transfer directions respect backpack capacity and preserve leftovers"] = function(
		t
	)
		local config = table.clone(Config)
		config.outputCapacity = 2
		local m, _, _, d, s, _, dirt, build = setup(2, config)
		build()
		dirt("1", "a", 12)
		dirt("1", "b", 13)
		m.transfer("1", d["1"], s["1"], "in")
		m.step(0, true)
		m.step(4, true)
		s["2"].outputs.own = { id = "own", value = 2 }
		dirt("2", "new", 9)
		local result, deposited, collected = m.transfer("2", d["2"], s["2"], "both")
		t.equal(result, "sluice_transferred")
		t.equal(deposited, 1)
		t.equal(collected, 1)
		t.equal(m.outputs.b.value, 13)
		t.equal(s["2"].outputs.a.value, 12)
		t.equal(d["2"].state.batches.new, nil)
		t.equal(m.dirtCount(), 1)
		t.equal(m.transfer("2", d["2"], s["2"], "full-bag"), "sluice_no_transfer")
		t.equal(m.outputs.b.value, 13)
		-- An outstanding pan reservation is never consumed by collecting machinery output.
		s["1"].reserved = 2
		t.equal(m.transfer("1", d["1"], s["1"], "reserved"), "sluice_no_transfer")
		s["1"].reserved = 0
		t.equal(m.transfer("1", d["1"], s["1"], "other-player"), "sluice_transferred")
		t.equal(next(m.outputs), nil)
	end,
	["MACHINE full output pauses queued dirt until collection and never rerolls"] = function(t)
		local config = table.clone(Config)
		config.sluiceOutputPerMember = 1
		local m, _, _, d, s, _, dirt, build = setup(1, config)
		build()
		dirt("1", "a", 12)
		local b = dirt("1", "b", 9)
		m.transfer("1", d["1"], s["1"], "in")
		m.step(0, true)
		m.step(4, true)
		t.equal(#m.queue, 1)
		t.equal(next(m.state.lanes), nil)
		m.step(100, true)
		t.equal(m.batches.b.outcome, b.outcome)
		t.equal(m.batches.b.status, "queued")
		m.transfer("1", d["1"], s["1"], "out")
		m.step(100, true)
		t.equal(m.step(103.999, true), 0)
		t.equal(m.step(104, true), 1)
		t.equal(m.outputs.b.value, 9)
	end,
	["MACHINE invalid collection is atomic and busy requests leave both inventories untouched"] = function(
		t
	)
		local m, _, _, d, s, _, dirt, build = setup(1, Config)
		dirt("1", "a", 12)
		t.equal(m.transfer("1", d["1"], s["1"], "early"), "not_built")
		build()
		d["1"].pending = {}
		t.equal(m.transfer("1", d["1"], s["1"], "busy"), "busy_digging")
		d["1"].pending = nil
		m.transfer("1", d["1"], s["1"], "in")
		m.step(0, true)
		m.step(4, true)
		dirt("1", "new", 8)
		dirt("1", "a", 7)
		local state, personal = m.state, d["1"].state
		t.errors(function()
			m.transfer("1", d["1"], s["1"], "collision")
		end)
		t.equal(m.state, state)
		t.equal(d["1"].state, personal)
		t.equal(m.outputs.a.value, 12)
		t.equal(m.batches.new, nil)
	end,
	["MACHINE cutoff clears queue processing output and funding without payment"] = function(t)
		local m, crew, c, d, s, _, dirt, build = setup(1, Config)
		build()
		for _, key in { "a", "b", "c" } do
			dirt("1", key, 12)
		end
		m.transfer("1", d["1"], s["1"], "in")
		m.step(0, true)
		m.step(4, true)
		t.equal(m.step(8, false), 0)
		t.equal(m.outputs.a.value, 12)
		t.equal(#m.queue, 1)
		m.clear()
		t.equal(m.state, nil)
		t.equal(m.dirtCount(), 0)
		t.equal(next(m.outputs), nil)
		t.equal(next(m.batches), nil)
		t.equal(crew.haul, 0)
		t.equal(c["1"].ledger.wallet, 0)
		m.start(1)
		c["1"].ledger.wallet = 17
		m.contribute("1", "Alice", c["1"], 17, "partial")
		m.clear()
		m.start(1)
		t.equal(m.state.funded, 0)
		t.equal(next(m.contributors), nil)
		t.equal(c["1"].ledger.wallet, 0)
	end,
}
