--!strict
local Economy = require("../../src/shared/Pure/Economy")
local Ledger = require("../../src/shared/Pure/Ledger")
local Batch = require("../../src/shared/Pure/Batch")
local Dig = require("../../src/shared/Pure/Dig")
local Config = require("../../src/shared/Config")
local function setup()
	local dig = Dig.new(Config, Batch, function()
		return { kind = "Gold", baseValue = 12, sourceMultiplier = 1 }
	end)
	local sift = { outputs = {}, reserved = 0 }
	local economy = Economy.new(Config, dig, sift, Batch, Ledger)
	local function find(id, value)
		dig.state.batches[id] = { id = id, status = "completed", active = false }
		sift.outputs[id] = { id = id, value = value }
	end
	return economy, dig, sift, find
end
return {
	["TIERS ordered purchases spend only wallet and update both tools immediately"] = function(t)
		local economy, dig, sift, find = setup()
		local total = Config.shovelUpgradePrice
			+ Config.shovelTierThreePrice
			+ Config.panTierTwoPrice
			+ Config.panTierThreePrice
		find("funding", total)
		economy.sell("funding")
		for _, id in { "shovel-3", "pan-3" } do
			local before = economy.ledger
			t.equal(economy.buy("early-" .. id, id), "missing_prerequisite")
			t.equal(economy.ledger, before)
		end
		for _, id in { "pan-2", "shovel-2", "pan-3", "shovel-3" } do
			t.equal(economy.buy(id, id), "purchased")
			t.equal(economy.buy(id, id), "duplicate_request")
			t.equal(economy.buy("again-" .. id, id), "already_owned")
			t.equal(economy.ledger.haul, total)
		end
		t.equal(economy.ledger.wallet, 0)
		t.equal(dig.digSeconds, Config.shovelTierThreeSeconds)
		t.equal(sift.upgrades, 2)
		t.equal(economy.buy("shovel-3", "pan-2"), "duplicate_request")
	end,
	["TIERS invalid catalog entries and unaffordable tiers preserve state"] = function(t)
		local economy, dig, sift = setup()
		for _, id in { "pan-1", "shovel-4", "", 3, {}, false } do
			t.equal(economy.buy("invalid", id), "invalid_request")
		end
		for _, id in { "shovel-2", "pan-2" } do
			local before = economy.ledger
			t.equal(economy.buy("poor", id), "unaffordable")
			t.equal(economy.ledger, before)
		end
		t.equal(dig.digSeconds, Config.digSeconds)
		t.equal(sift.upgrades, nil)
	end,
	["TIERS pan purchases widen actual subsequent checks and fresh controllers reset"] = function(
		t
	)
		local Sift = require("../../src/shared/Pure/Sift")
		local SkillCheck = require("../../src/shared/Pure/SkillCheck")
		local _, dig = setup()
		local sift = Sift.new(Config, dig, Batch, SkillCheck, function()
			return 0.5
		end)
		sift.upgrades = 0
		local economy = Economy.new(Config, dig, sift, Batch, Ledger)
		economy.ledger.wallet = Config.panTierTwoPrice + Config.panTierThreePrice
		for i, id in { "pan-2", "pan-3" } do
			t.equal(economy.buy(id, id), "purchased")
			t.equal(sift.upgrades, i)
			local now = i * Config.siftSeconds
			t.equal(
				dig.start(
					{ id = id, source = "Bank", digger = "a", distance = 0, now = now },
					"running"
				),
				"started"
			)
			t.equal(dig.step(now + Config.digSeconds, 0, "running", "Bank"), "created")
			t.equal(sift.start(now + Config.digSeconds, id, sift.upgrades, 1), "started")
			local check = sift.pending.checks[1]
			local scale = 1 + i * Config.siftUpgradeWidth
			t.equal(check.perfectWidth, Config.siftPerfectWidth * scale)
			t.equal(check.zoneWidth, (Config.siftPerfectWidth + 2 * Config.siftGoodWidth) * scale)
			sift.cancel()
		end
		local fresh, freshDig = setup()
		t.equal(next(fresh.ledger.owned), nil)
		t.equal(fresh.ledger.wallet, 0)
		t.equal(freshDig.digSeconds, Config.digSeconds)
	end,
	["CREW sale preparation preserves inventory until explicit commit"] = function(t)
		local economy, dig, sift, find = setup()
		find("gold", 57)
		local ledger, state, outputs = economy.ledger, dig.state, sift.outputs
		local prepared, reason = economy.prepareSale("shared-sale")
		t.equal(reason, nil)
		t.equal(prepared.amount, 57)
		t.equal(economy.ledger, ledger)
		t.equal(dig.state, state)
		t.equal(sift.outputs, outputs)
		economy.commitSale(prepared)
		t.equal(economy.ledger.wallet, 57)
		t.equal(dig.state.batches.gold.status, "sold")
		t.equal(next(sift.outputs), nil)
		local duplicate, rejection = economy.prepareSale("shared-sale")
		t.equal(duplicate, nil)
		t.equal(rejection, "duplicate_request")
	end,
	["ECON-2 decimal dig interval accepts its exact deadline at nonzero clock origins"] = function(
		t
	)
		local economy, dig, _, find = setup()
		find("funding", 50)
		economy.sell("sale")
		economy.buy("buy")
		dig.state.lastDigAt.alice = 100
		local req = { id = "decimal", source = "Bank", digger = "alice", distance = 0, now = 100 }
		t.equal(dig.start(req, "running"), "started")
		t.equal(dig.step(100.79, 0, "running", "Bank"), "digging")
		t.equal(dig.step(100.8, 0, "running", "Bank"), "created")
	end,
	["ECON-1 sell consumes completed finds and credits wallet and haul once"] = function(t)
		local economy, dig, sift, find = setup()
		find("a", 13)
		find("b", 14)
		dig.state.batches.raw = { id = "raw", status = "queued" }
		sift.reserved = 1
		local result, amount = economy.sell("sale")
		t.equal(result, "sold")
		t.equal(amount, 27)
		t.equal(economy.ledger.wallet, 27)
		t.equal(economy.ledger.haul, 27)
		t.equal(dig.state.batches.a.status, "sold")
		t.equal(dig.state.batches.raw.status, "queued")
		t.equal(next(sift.outputs), nil)
		t.equal(sift.reserved, 1)
		find("later", 10)
		t.equal(economy.sell("sale"), "duplicate_request")
		t.equal(sift.outputs.later.value, 10)
		t.equal(economy.sell("next-sale"), "sold")
		t.equal(economy.ledger.wallet, 37)
		t.equal(economy.sell("empty"), "nothing_to_sell")
		t.equal(economy.ledger.wallet, 37)
	end,
	["ECON-1 invalid output aborts all state changes"] = function(t)
		for _, value in { -1, 1.2, math.huge, 0 / 0 } do
			local economy, dig, sift, find = setup()
			find("valid", 10)
			find("bad", value)
			local ledger, state, outputs = economy.ledger, dig.state, sift.outputs
			t.errors(function()
				economy.sell("invalid")
			end)
			t.equal(economy.ledger, ledger)
			t.equal(dig.state, state)
			t.equal(sift.outputs, outputs)
		end
		local economy, dig, _, find = setup()
		find("raw", 12)
		dig.state.batches.raw.status = "queued"
		t.errors(function()
			economy.sell("raw")
		end)
		t.equal(economy.ledger.wallet, 0)
	end,
	["ECON-2 exact price purchase applies to later digs and survives repeats"] = function(t)
		local economy, dig, _, find = setup()
		t.equal(economy.buy("purchase"), "unaffordable")
		find("gold", 50)
		economy.sell("sale")
		local req = { id = "dig", source = "Bank", digger = "alice", distance = 0, now = 0 }
		t.equal(dig.start(req, "running"), "started")
		t.equal(economy.buy("purchase"), "purchased")
		t.equal(economy.ledger.wallet, 0)
		t.equal(economy.ledger.haul, 50)
		t.equal(dig.digSeconds, 0.8)
		t.equal(dig.pending.due, 1)
		t.equal(dig.step(0.8, 0, "running", "Bank"), "digging")
		t.equal(dig.step(1, 0, "running", "Bank"), "created")
		req.id = "faster"
		req.now = 1
		t.equal(dig.start(req, "running"), "started")
		t.equal(dig.pending.due, 1.8)
		t.equal(dig.step(1.79, 0, "running", "Bank"), "digging")
		t.equal(dig.step(1.8, 0, "running", "Bank"), "created")
		t.equal(economy.buy("purchase"), "duplicate_request")
		t.equal(economy.buy("new-purchase"), "already_owned")
		t.equal(economy.ledger.wallet, 0)
	end,
	["ECON-3 rejected purchases preserve all state; spending never reduces haul"] = function(t)
		local economy, dig, _, find = setup()
		find("poor", 49)
		economy.sell("sale")
		local before = economy.ledger
		t.equal(economy.buy("buy"), "unaffordable")
		t.equal(economy.ledger, before)
		t.equal(dig.digSeconds, 1)
		find("extra", 20)
		economy.sell("extra-sale")
		t.equal(economy.buy("buy"), "purchased")
		t.equal(economy.ledger.wallet, 19)
		t.equal(economy.ledger.haul, 69)
		t.equal(economy.sell("buy"), "duplicate_request")
		t.equal(economy.buy("extra-sale"), "duplicate_request")
	end,
}
