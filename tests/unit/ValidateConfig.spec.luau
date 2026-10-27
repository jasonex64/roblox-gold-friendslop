--!strict
local validate = require("../../src/shared/Pure/ValidateConfig")
local config = require("../../src/shared/Config")
return {
	["REWARD config rejects invalid tuning and unsafe arithmetic"] = function(t)
		for _, key in
			{
				"rewardBaseTokens",
				"rewardBonusCap",
				"rewardHaulPerTokenPerMember",
				"rewardActiveSeconds",
			}
		do
			for _, value in { 0, -1, math.huge, 0 / 0 } do
				local bad = table.clone(config)
				bad[key] = value
				t.errors(function()
					validate(bad)
				end)
			end
		end
		for _, key in { "rewardBaseTokens", "rewardBonusCap", "rewardHaulPerTokenPerMember" } do
			local bad = table.clone(config)
			bad[key] = 1.5
			t.errors(function()
				validate(bad)
			end)
		end
		for key, value in
			{
				rewardActiveSeconds = 601,
				rewardBaseTokens = 2 ^ 53 - 1,
				rewardHaulPerTokenPerMember = 2 ^ 53 - 1,
			}
		do
			local bad = table.clone(config)
			bad[key] = value
			t.errors(function()
				validate(bad)
			end)
		end
	end,
	["RUN-3 shipped config validates and every missing field errors by name"] = function(t)
		validate(config)
		for key in config do
			local missing = table.clone(config)
			missing[key] = nil
			local ok, message = pcall(validate, missing)
			t.equal(ok, false)
			t.equal(string.find(tostring(message), "Config." .. key, 1, true) ~= nil, true)
		end
	end,
	["RUN-3 invalid timings and fractional capacities fail"] = function(t)
		for _, value in { 0, -1, math.huge, 0 / 0 } do
			local bad = table.clone(config)
			bad.shiftSeconds = value
			t.errors(function()
				validate(bad)
			end)
		end
		local bad = table.clone(config)
		bad.bucketBatches = 1.5
		t.errors(function()
			validate(bad)
		end)
	end,
}
