--!strict
local Rewards = require("../../src/shared/Pure/RunRewards")
local config = require("../../src/shared/Config")

local function snapshot(n: number, haul: number, active: number)
	local participants = {}
	for id = 1, n do
		participants[id] = { activeSeconds = active, discoveries = { ["Gold Flakes"] = true } }
	end
	return {
		runId = "run:one",
		rulesVersion = "test-rewards",
		crewSize = n,
		crewHaul = haul,
		assisted = false,
		participants = participants,
	}
end
local function deepEqual(t, a, b)
	t.equal(type(a), type(b))
	if type(a) == "table" then
		for k, v in a do
			deepEqual(t, v, b[k])
		end
		for k in b do
			t.equal(a[k] ~= nil, true)
		end
	else
		t.equal(a, b)
	end
end
local function freezeDeep(value)
	for _, child in value do
		if type(child) == "table" then
			freezeDeep(child)
		end
	end
	table.freeze(value)
end

return {
	["REWARD-1 eligibility boundary preserves discoveries without completion"] = function(t)
		for _, active in { 0, 479.999, 480, 600 } do
			local m = Rewards.build(snapshot(1, 500, active), config)[1]
			local eligible = active >= 480
			t.equal(m.eligible, eligible)
			t.equal(m.claimTokens, if eligible then 21 else 0)
			t.equal(m.completionDelta, if eligible then 1 else 0)
			t.equal(m.discoveries["Gold Flakes"], true)
			t.equal(m.recordCandidate ~= nil, eligible)
		end
	end,
	["REWARD-2 sold haul formula floors scales by locked crew and caps"] = function(t)
		for _, case in
			{ { 0, 20 }, { 499, 20 }, { 500, 21 }, { 9999, 39 }, { 10000, 40 }, { 1000000, 40 } }
		do
			for n = 1, 4 do
				local result = Rewards.build(snapshot(n, case[1] * n, 480), config)
				for id = 1, n do
					t.equal(result[id].claimTokens, case[2])
				end
			end
		end
		local result = Rewards.build(snapshot(4, 12000, 480), config)
		for id = 1, 4 do
			t.equal(result[id].claimTokens, 26)
		end
	end,
	["REWARD-3 tuning is injected rather than hardcoded"] = function(t)
		local cfg = table.clone(config)
		cfg.rewardBaseTokens, cfg.rewardBonusCap = 7, 3
		cfg.rewardHaulPerTokenPerMember, cfg.rewardActiveSeconds = 100, 100
		t.equal(Rewards.build(snapshot(1, 200, 100), cfg)[1].claimTokens, 9)
		t.equal(Rewards.build(snapshot(1, 1000, 100), cfg)[1].claimTokens, 10)
		t.equal(Rewards.build(snapshot(1, 1000, 99), cfg)[1].claimTokens, 0)
	end,
	["REWARD-4 grant identity stays run-user while records retain bucket"] = function(t)
		local s = snapshot(4, 12000, 480)
		s.participants[2].activeSeconds = 0
		local first = Rewards.build(s, config)
		s.rulesVersion, s.assisted = "new-rules", true
		local second = Rewards.build(s, config)
		for id = 1, 4 do
			t.equal(first[id].runId, second[id].runId)
			t.equal(first[id].userId, id)
			t.equal(second[id].userId, id)
			t.equal(first[id].claimTokens, second[id].claimTokens)
		end
		t.equal(second[2].recordCandidate, nil)
		t.equal(first[1].recordCandidate.crewSize, 4)
		t.equal(first[1].recordCandidate.assisted, false)
		t.equal(second[1].recordCandidate.assisted, true)
		t.equal(second[1].recordCandidate.rulesVersion, "new-rules")
		t.equal(second[1].recordCandidate.crewHaul, 12000)
	end,
	["REWARD-5 frozen inputs and repeated results are independent"] = function(t)
		local s = snapshot(2, 2000, 480)
		freezeDeep(s)
		local a, b = Rewards.build(s, config), Rewards.build(s, config)
		deepEqual(t, a, b)
		a[1].discoveries["Gold Flakes"] = nil
		a[1].recordCandidate.crewHaul = 0
		t.equal(b[1].discoveries["Gold Flakes"], true)
		t.equal(a[2].discoveries["Gold Flakes"], true)
		t.equal(b[1].recordCandidate.crewHaul, 2000)
		t.equal(s.participants[1].discoveries["Gold Flakes"], true)
		t.equal(s.crewHaul, 2000)
	end,
	["REWARD-6 irrelevant money inventory and progression cannot grant rewards"] = function(t)
		local s = snapshot(1, 0, 480)
		local baseline = Rewards.build(s, config)
		s.runCash, s.unsoldValue, s.spending, s.petXP, s.eggs =
			999999, 999999, 999999, 999999, 999999
		s.participants[1].runCash = 999999
		deepEqual(t, baseline, Rewards.build(s, config))
		t.equal(baseline[1].petXP, nil)
		t.equal(baseline[1].eggs, nil)
	end,
	["REWARD-7 malformed snapshots fail loudly"] = function(t)
		for _, key in
			{ "runId", "rulesVersion", "crewSize", "crewHaul", "assisted", "participants" }
		do
			local s = snapshot(1, 0, 480)
			s[key] = nil
			t.errors(function()
				Rewards.build(s, config)
			end)
		end
		for _, key in { "runId", "rulesVersion" } do
			for _, value in { "", "  ", 5 } do
				local s = snapshot(1, 0, 480)
				s[key] = value
				t.errors(function()
					Rewards.build(s, config)
				end)
			end
		end
		for _, value in { -1, 0.5, math.huge, 0 / 0, 2 ^ 53, "0" } do
			local s = snapshot(1, 0, 480)
			s.crewHaul = value
			t.errors(function()
				Rewards.build(s, config)
			end)
		end
		for _, value in { 0, 1.5, 5, math.huge, 0 / 0 } do
			local s = snapshot(1, 0, 480)
			s.crewSize = value
			t.errors(function()
				Rewards.build(s, config)
			end)
		end
		for _, value in { -1, 601, math.huge, 0 / 0, "480" } do
			local s = snapshot(1, 0, 480)
			s.participants[1].activeSeconds = value
			t.errors(function()
				Rewards.build(s, config)
			end)
		end
		for _, discoveries in { { unknown = true }, { ["Gold Flakes"] = false }, { "Gold Flakes" } } do
			local s = snapshot(1, 0, 480)
			s.participants[1].discoveries = discoveries
			t.errors(function()
				Rewards.build(s, config)
			end)
		end
		for _, id in { 0, -1, 1.5, "1", 2 ^ 53 } do
			local s = snapshot(1, 0, 480)
			s.participants = { [id] = s.participants[1] }
			t.errors(function()
				Rewards.build(s, config)
			end)
		end
		local s = snapshot(2, 0, 480)
		s.participants[2] = nil
		t.errors(function()
			Rewards.build(s, config)
		end)
		s = snapshot(1, 0, 480)
		s.participants[1].discoveries = nil
		t.errors(function()
			Rewards.build(s, config)
		end)
	end,
	["REWARD-8 invalid reward config fails before any manifest escapes"] = function(t)
		for _, key in
			{
				"rewardBaseTokens",
				"rewardBonusCap",
				"rewardHaulPerTokenPerMember",
				"rewardActiveSeconds",
			}
		do
			for _, value in { 0, -1, math.huge, 0 / 0, "20" } do
				local cfg = table.clone(config)
				cfg[key] = value
				t.errors(function()
					Rewards.build(snapshot(1, 0, 480), cfg)
				end)
			end
			local cfg = table.clone(config)
			cfg[key] = nil
			t.errors(function()
				Rewards.build(snapshot(1, 0, 480), cfg)
			end)
		end
		for _, key in { "rewardBaseTokens", "rewardBonusCap", "rewardHaulPerTokenPerMember" } do
			local cfg = table.clone(config)
			cfg[key] = 1.5
			t.errors(function()
				Rewards.build(snapshot(1, 0, 480), cfg)
			end)
		end
		local cfg = table.clone(config)
		cfg.rewardActiveSeconds = 601
		t.errors(function()
			Rewards.build(snapshot(1, 0, 480), cfg)
		end)
		cfg = table.clone(config)
		cfg.rewardBaseTokens = 2 ^ 53 - 1
		t.errors(function()
			Rewards.build(snapshot(1, 0, 480), cfg)
		end)
		cfg = table.clone(config)
		cfg.rewardHaulPerTokenPerMember = 2 ^ 53 - 1
		t.errors(function()
			Rewards.build(snapshot(1, 0, 480), cfg)
		end)
	end,
}
