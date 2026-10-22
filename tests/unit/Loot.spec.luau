--!strict
local Loot = require("../../src/shared/Pure/Loot")
local config = require("../../src/shared/Config")
return {
	["DIG-3 opening boundary bypasses rng then ordinary table applies"] = function(t)
		for count = 0, config.openingBatches - 1 do
			local item = Loot.draw(config, count, function()
				error("opening must not roll")
			end)
			t.equal(item.kind, "Gold Flakes")
			t.equal(item.baseValue, config.openingValue)
		end
		local item = Loot.draw(config, config.openingBatches, function()
			return 0
		end)
		t.equal(item.kind, "Old Boot")
		t.equal(item.baseValue, 3)
	end,
	["DIG-2 complete crate result is resolved during creation"] = function(t)
		local calls = 0
		local item = Loot.draw(config, config.openingBatches, function()
			calls += 1
			return if calls == 1 then 0.999 else 0.9
		end)
		t.equal(calls, 2)
		t.equal(item.kind, "Mystery Crate")
		t.equal(item.crateValue, 350)
		t.equal(item.baseValue, 350)
	end,
}
