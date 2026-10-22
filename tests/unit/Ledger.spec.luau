--!strict
local Ledger = require("../../src/shared/Pure/Ledger")

local function fixture()
	return {
		haul = 100,
		wallet = 20,
		finds = {
			gold = { baseValue = 12, sold = false },
			gem = { baseValue = 28, sold = false },
			old = { baseValue = 9, sold = true },
		},
		owned = { starter = true },
		requests = {},
	}
end

local function item()
	return { id = "shovel", price = 40, prerequisites = { "starter" } }
end

local function namedError(t, fn, text)
	local ok, message = pcall(fn)
	t.equal(ok, false)
	t.equal(string.find(tostring(message), text, 1, true) ~= nil, true)
end

return {
	["LEDGER-1 sale consumes registered values once without mutating input"] = function(t)
		local state = fixture()
		local sold, reason = Ledger.sell(state, { "gold", "gem" }, "sale")
		t.equal(reason, nil)
		t.equal(sold.haul, 140)
		t.equal(sold.wallet, 60)
		t.equal(sold.finds.gold.sold, true)
		t.equal(sold.finds.gem.sold, true)
		t.equal(sold.requests.sale, true)
		t.equal(state.haul, 100)
		t.equal(state.wallet, 20)
		t.equal(state.finds.gold.sold, false)
		t.equal(state.finds.gem.sold, false)
		t.equal(next(state.requests), nil)
		local replay, duplicate = Ledger.sell(sold, { "unknown" }, "sale")
		t.equal(replay, sold)
		t.equal(duplicate, "duplicate_request")
		t.equal(replay.wallet, 60)
	end,
	["LEDGER-1 empty and zero-value sales do not create money"] = function(t)
		local state = fixture()
		state.finds.zero = { baseValue = 0, sold = false }
		local empty = Ledger.sell(state, {}, "empty")
		t.equal(empty.haul, 100)
		t.equal(empty.wallet, 20)
		local zero = Ledger.sell(empty, { "zero" }, "zero")
		t.equal(zero.haul, 100)
		t.equal(zero.wallet, 20)
		t.equal(zero.finds.zero.sold, true)
	end,
	["LEDGER-2 affordable purchase deducts once and never changes haul"] = function(t)
		local state = Ledger.sell(fixture(), { "gold", "gem" }, "sale")
		local bought, reason = Ledger.buy(state, item(), "buy")
		t.equal(reason, nil)
		t.equal(bought.wallet, 20)
		t.equal(bought.haul, 140)
		t.equal(bought.owned.shovel, true)
		t.equal(bought.requests.buy, true)
		t.equal(state.wallet, 60)
		t.equal(state.owned.shovel, nil)
		t.equal(state.requests.buy, nil)
		local replay, duplicate = Ledger.buy(bought, item(), "buy")
		t.equal(replay, bought)
		t.equal(duplicate, "duplicate_request")
		local again, owned = Ledger.buy(bought, item(), "new-buy")
		t.equal(again, bought)
		t.equal(owned, "already_owned")
	end,
	["LEDGER-2 rejections are unchanged and can retry after prerequisites or money arrive"] = function(
		t
	)
		local state = fixture()
		local rejected, reason = Ledger.buy(state, item(), "buy")
		t.equal(rejected, state)
		t.equal(reason, "unaffordable")
		t.equal(next(state.requests), nil)
		state.wallet = 40
		state.owned.starter = nil
		local missing, prerequisite = Ledger.buy(state, item(), "buy")
		t.equal(missing, state)
		t.equal(prerequisite, "missing_prerequisite")
		t.equal(state.wallet, 40)
		t.equal(next(state.requests), nil)
		state.owned.starter = true
		local bought, accepted = Ledger.buy(state, item(), "buy")
		t.equal(accepted, nil)
		t.equal(bought.wallet, 0)
		t.equal(bought.haul, 100)
	end,
	["LEDGER-2 all prerequisites required and zero-price items allowed"] = function(t)
		local state = fixture()
		local upgrade = { id = "pan", price = 0, prerequisites = { "starter", "shovel" } }
		local rejected, reason = Ledger.buy(state, upgrade, "free")
		t.equal(rejected, state)
		t.equal(reason, "missing_prerequisite")
		state.owned.shovel = true
		local bought = Ledger.buy(state, upgrade, "free")
		t.equal(bought.owned.pan, true)
		t.equal(bought.wallet, 20)
		t.equal(bought.haul, 100)
	end,
	["LEDGER-1 and LEDGER-2 request IDs cannot cross operation boundaries"] = function(t)
		local sold = Ledger.sell(fixture(), { "gold", "gem" }, "shared")
		local replay, reason = Ledger.buy(sold, item(), "shared")
		t.equal(replay, sold)
		t.equal(reason, "duplicate_request")
		local bought = Ledger.buy(sold, item(), "purchase")
		local saleReplay, saleReason = Ledger.sell(bought, { "unknown" }, "purchase")
		t.equal(saleReplay, bought)
		t.equal(saleReason, "duplicate_request")
	end,
	["LEDGER-3 unknown sold and duplicate finds error by name atomically"] = function(t)
		for _, case in
			{
				{ "unknown", "unknown_find unknown" },
				{ "old", "already_sold old" },
				{ "gold", "duplicate_find gold" },
			}
		do
			local state = fixture()
			namedError(t, function()
				Ledger.sell(state, { "gold", case[1] }, "bad")
			end, case[2])
			t.equal(state.finds.gold.sold, false)
			t.equal(state.wallet, 20)
			t.equal(state.haul, 100)
			t.equal(next(state.requests), nil)
		end
		local sold = Ledger.sell(fixture(), { "gold" }, "first")
		namedError(t, function()
			Ledger.sell(sold, { "gold" }, "second")
		end, "already_sold gold")
		t.equal(sold.wallet, 32)
	end,
	["LEDGER invalid amounts and overflow cannot partially commit"] = function(t)
		for _, value in { -1, 0.5, math.huge, 0 / 0, 2 ^ 53 } do
			local state = fixture()
			state.finds.gem.baseValue = value
			t.errors(function()
				Ledger.sell(state, { "gold", "gem" }, "bad")
			end)
			local upgrade = item()
			upgrade.price = value
			t.errors(function()
				Ledger.buy(state, upgrade, "bad")
			end)
			t.equal(state.wallet, 20)
			t.equal(state.finds.gold.sold, false)
			t.equal(next(state.requests), nil)
		end
		for _, field in { "haul", "wallet" } do
			local state = fixture()
			state[field] = 2 ^ 53 - 1
			namedError(t, function()
				Ledger.sell(state, { "gold" }, "overflow")
			end, field .. " overflow")
			t.equal(state.finds.gold.sold, false)
			t.equal(next(state.requests), nil)
		end
		local state = fixture()
		state.finds.gem.baseValue = 2 ^ 53 - 1
		namedError(t, function()
			Ledger.sell(state, { "gold", "gem" }, "overflow")
		end, "total overflow")
		t.equal(state.finds.gold.sold, false)
	end,
}
