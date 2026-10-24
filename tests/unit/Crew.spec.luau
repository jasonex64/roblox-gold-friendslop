--!strict
local Crew = require("../../src/shared/Pure/Crew")
local Economy = require("../../src/shared/Pure/Economy")
local Batch = require("../../src/shared/Pure/Batch")
local Ledger = require("../../src/shared/Pure/Ledger")
local Config = require("../../src/shared/Config")
local function setup(count)
	local crew = Crew.new(Config)
	local controllers, digs, sifts = {}, {}, {}
	for index = 1, count do
		local id = tostring(index)
		crew.join(id)
		local dig = { state = { batches = {} }, digSeconds = Config.digSeconds }
		local sift = { outputs = {} }
		controllers[id] = Economy.new(Config, dig, sift, Batch, Ledger)
		digs[id], sifts[id] = dig, sift
	end
	crew.start(0)
	local function find(id, key, value)
		digs[id].state.batches[key] = { id = key, status = "completed", active = false }
		sifts[id].outputs[key] = { id = key, value = value }
	end
	return crew, controllers, digs, sifts, find
end
return {
	["CREW-1 admission locks; overflow and reconnect wait; prestart departure frees a slot"] = function(
		t
	)
		local crew = Crew.new(Config)
		for i = 1, 5 do
			crew.join(tostring(i))
		end
		t.equal(#crew.members(), 4)
		t.equal(crew.admitted["5"], nil)
		crew.leave("2")
		t.equal(crew.admitted["5"], true)
		crew.start(0)
		crew.join("6")
		t.equal(crew.admitted["6"], nil)
		crew.leave("1")
		crew.join("1")
		t.equal(crew.admitted["1"], nil)
		t.equal(crew.vote("1"), "waiting_for_crew")
		for _, id in crew.members() do
			crew.vote(id)
		end
		t.equal(crew.replayReady(), true)
		crew.reset()
		t.equal(#crew.members(), 4)
		t.equal(crew.haul, 0)
		t.equal(crew.locked, false)
	end,
	["CREW-2 solo and four-player shares conserve every dollar; spending preserves haul"] = function(
		t
	)
		for count = 1, 4 do
			local crew, econ, _, _, find = setup(count)
			find("1", "sale", 200)
			local result, _, total = crew.sale("1", econ["1"], econ, "sale", 0)
			t.equal(result, "sold")
			t.equal(total, 200)
			local sum = 0
			for _, entry in econ do
				sum += entry.ledger.wallet
			end
			t.equal(sum, 200)
			t.equal(crew.haul, 200)
			if count == 4 then
				for _, entry in econ do
					t.equal(entry.ledger.wallet, 50)
				end
				t.equal(econ["1"].buy("upgrade"), "purchased")
				t.equal(econ["1"].ledger.wallet, 0)
				t.equal(crew.haul, 200)
			end
		end
	end,
	["CREW-2 rotating remainders cannot create money and duplicate requests cannot advance them"] = function(
		t
	)
		local crew, econ, _, sift, find = setup(4)
		for i = 1, 4 do
			find("1", tostring(i), 1)
			crew.sale("1", econ["1"], econ, tostring(i), 0)
			local cursor = crew.cursor
			t.equal(crew.sale("1", econ["1"], econ, tostring(i), 0), "duplicate_request")
			t.equal(crew.cursor, cursor)
		end
		for _, entry in econ do
			t.equal(entry.ledger.wallet, 1)
		end
		t.equal(crew.haul, 4)
		find("1", "later", 9)
		t.equal(crew.sale("1", econ["1"], econ, "1", 0), "duplicate_request")
		t.equal(sift["1"].outputs.later.value, 9)
		crew.leave("4")
		find("2", "second-seller", 2)
		t.equal(crew.sale("2", econ["2"], econ, "1", 0), "sold")
		t.equal(crew.haul, 6)
	end,
	["CREW-3 AFK boundaries; empty/repeated sales do not reactivate; real sale resumes seller"] = function(
		t
	)
		local crew, econ, _, _, find = setup(2)
		t.equal(crew.eligibility("1", 59.99), "active")
		t.equal(crew.eligibility("1", 60), "warning")
		t.equal(crew.eligibility("1", 69.99), "warning")
		t.equal(crew.eligibility("1", 70), "paused")
		t.equal(crew.sale("1", econ["1"], econ, "empty", 70), "nothing_to_sell")
		t.equal(crew.eligibility("1", 70), "paused")
		find("1", "gold", 57)
		local result, share = crew.sale("1", econ["1"], econ, "sell", 70)
		t.equal(result, "sold")
		t.equal(share, 57)
		t.equal(econ["2"].ledger.wallet, 0)
		t.equal(crew.eligibility("1", 70), "active")
		t.equal(crew.sale("1", econ["1"], econ, "sell", 140), "duplicate_request")
		t.equal(crew.eligibility("1", 140), "paused")
		crew.activity("2", 140)
		find("1", "next", 10)
		crew.sale("1", econ["1"], econ, "next", 140)
		t.equal(econ["2"].ledger.wallet, 5)
		t.equal(crew.haul, 67)
	end,
	["CREW-4 invalid recipient or output rolls back all inventory, balances, cursor and activity"] = function(
		t
	)
		local crew, econ, dig, sift, find = setup(2)
		find("1", "gold", 10)
		econ["2"].ledger.wallet = 2 ^ 53 - 1
		local ledger, state, outputs = econ["1"].ledger, dig["1"].state, sift["1"].outputs
		t.errors(function()
			crew.sale("1", econ["1"], econ, "bad", 60)
		end)
		t.equal(econ["1"].ledger, ledger)
		t.equal(dig["1"].state, state)
		t.equal(sift["1"].outputs, outputs)
		t.equal(crew.haul, 0)
		t.equal(crew.cursor, 1)
		t.equal(crew.lastActive["1"], 0)
		econ["2"].ledger.wallet = 0
		sift["1"].outputs.gold.value = -1
		t.errors(function()
			crew.sale("1", econ["1"], econ, "bad", 60)
		end)
		t.equal(crew.haul, 0)
		t.equal(dig["1"].state, state)
	end,
	["CREW-5 departed sellers do not erase haul; replay requires remaining crew and clears state"] = function(
		t
	)
		local crew, econ, _, _, find = setup(3)
		find("1", "gold", 57)
		crew.sale("1", econ["1"], econ, "sale", 0)
		crew.leave("1")
		t.equal(crew.haul, 57)
		crew.join("4")
		t.equal(crew.vote("4"), "waiting_for_crew")
		t.equal(crew.vote("2"), "replay_waiting")
		t.equal(crew.replayReady(), false)
		t.errors(function()
			crew.reset()
		end)
		crew.leave("3")
		t.equal(crew.replayReady(), true)
		crew.reset()
		t.equal(crew.haul, 0)
		t.equal(crew.admitted["4"], true)
		t.equal(next(crew.votes), nil)
		t.equal(next(crew.lastActive), nil)
	end,
	["CREW-5 late arrivals cannot sell and all disconnected members release replay"] = function(t)
		local crew, econ = setup(1)
		crew.join("2")
		t.equal(crew.sale("2", econ["1"], econ, "forged", 0), "waiting_for_crew")
		crew.leave("1")
		t.equal(crew.replayReady(), true)
		crew.reset()
		t.equal(crew.admitted["2"], true)
	end,
}
