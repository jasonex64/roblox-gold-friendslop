--!strict
local Sift = require("../../src/shared/Pure/Sift")
local Dig = require("../../src/shared/Pure/Dig")
local Batch = require("../../src/shared/Pure/Batch")
local SkillCheck = require("../../src/shared/Pure/SkillCheck")
local Config = require("../../src/shared/Config")
local function setup(crate)
	local config = table.clone(Config)
	local draws = 0
	local dig = Dig.new(config, Batch, function()
		draws += 1
		return {
			kind = if crate then "Mystery Crate" else "Gold",
			baseValue = 100,
			sourceMultiplier = 2,
			crateValue = if crate then 100 else nil,
		}
	end)
	local req = { id = "batch", source = "Bank", digger = "alice", now = 0, distance = 0 }
	assert(dig.start(req, "running") == "started")
	assert(dig.step(1, 0, "running", "Bank") == "created")
	local sift = Sift.new(config, dig, Batch, SkillCheck, function()
		return 0.5
	end)
	return sift, dig, config, function()
		return draws
	end
end
local function play(sift, grade)
	for index = 1, 3 do
		local check = sift.pending.checks[index]
		local position = if grade == "perfect" then 0.5 elseif grade == "good" then 0.35 else 0.1
		assert(
			sift.press(check.startedAt + position / check.needleSpeed, "attempt", index) == grade
		)
		sift.step(check.startedAt + 2, true)
	end
end
return {
	["SIFT-1 reserves space and excludes simultaneous digging"] = function(t)
		local sift, dig = setup()
		t.equal(sift.start(10, "attempt", 0, 1), "started")
		t.equal(sift.reserved, 1)
		t.equal(dig.sifting, true)
		t.equal(dig.start({}, "running"), "busy_sifting")
		t.equal(sift.start(10, "other", 0, 1), "busy_sifting")
		t.equal(dig.state.batches.batch.status, "processing")
	end,
	["SIFT-1 rejects no dirt, active dig and full output without consuming dirt"] = function(t)
		local sift, dig, config = setup()
		dig.pending = {}
		t.equal(sift.start(10, "attempt", 0, 1), "busy_digging")
		dig.pending = nil
		for index = 1, config.outputCapacity do
			sift.outputs[tostring(index)] = {}
		end
		local item = dig.state.batches.batch
		t.equal(sift.start(10, "attempt", 0, 1), "full_output")
		t.equal(dig.state.batches.batch, item)
		t.equal(sift.reserved, 0)
		sift.outputs = {}
		dig.state.batches = {}
		t.equal(sift.start(10, "attempt", 0, 1), "no_dirt")
	end,
	["SIFT-1 snapshots rate, zones and value tuning; upgrades widen both zones"] = function(t)
		local sift, _, config = setup()
		sift.start(10, "attempt", 1, 2)
		t.equal(sift.pending.duration, 1)
		t.equal(sift.pending.endsAt, 13)
		t.equal(sift.pending.checks[1].zoneWidth, 0.5)
		t.equal(sift.pending.checks[1].perfectWidth, 0.125)
		config.siftPerfectBonus = 9
		config.siftSweepSeconds = 100
		t.equal(sift.pending.settings.siftPerfectBonus, 0.2)
		t.equal(sift.pending.duration, 1)
	end,
	["SIFT-2 assigned crate pays once without nested extra payout or reroll"] = function(t)
		local sift, dig, _, draws = setup(true)
		local outcome = dig.state.batches.batch.outcome
		sift.start(10, "attempt", 0, 1)
		play(sift, "perfect")
		local find = sift.outputs.batch
		t.equal(math.abs(find.value - 320) < 0.000001, true)
		t.equal(find.outcome, outcome)
		t.equal(find.id, "batch")
		t.equal(find.source, "Bank")
		t.equal(find.digger, "alice")
		t.equal(draws(), 1)
		t.equal(dig.state.batches.batch.status, "completed")
		t.equal(sift.step(100, true), "idle")
		t.equal(sift.outputs.batch, find)
		t.equal(sift.reserved, 0)
	end,
	["SIFT-3 cancel at each check destroys only active dirt and releases reservation"] = function(
		t
	)
		for index = 1, 3 do
			local sift, dig, _, draws = setup()
			local spare = table.clone(dig.state.batches.batch)
			spare.id = "spare"
			dig.state.batches.spare = spare
			sift.start(10, "attempt", 0, 1)
			sift.step(10 + (index - 1) * 2, true)
			t.equal(sift.cancel(), "cancelled")
			t.equal(sift.cancel(), "idle")
			t.equal(dig.state.batches.batch, nil)
			t.equal(dig.state.batches.spare, spare)
			t.equal(sift.reserved, 0)
			t.equal(dig.sifting, false)
			t.equal(sift.press(16, "attempt", index), "stale_check")
			t.equal(next(sift.outputs), nil)
			t.equal(draws(), 1)
		end
	end,
	["SIFT-3 reset and cutoff win over due completion"] = function(t)
		for _, time in { 10, 12, 14, 16, 100 } do
			local sift, dig = setup()
			sift.start(10, "attempt", 0, 1)
			t.equal(sift.step(time, false), "cancelled")
			t.equal(sift.reserved, 0)
			t.equal(dig.state.batches.batch, nil)
			t.equal(next(sift.outputs), nil)
		end
	end,
	["SIFT-4 press cannot complete early; stale and repeated inputs grant nothing"] = function(t)
		local sift = setup()
		sift.start(10, "attempt", 0, 1)
		t.equal(sift.press(11, "forged", 1), "stale_check")
		t.equal(sift.press(11, "attempt", 2), "stale_check")
		t.equal(sift.press(9, "attempt", 1), "outside_check")
		t.equal(sift.press(11, "attempt", 1), "perfect")
		t.equal(sift.press(11, "attempt", 1), "already_graded")
		t.equal(next(sift.outputs), nil)
		t.equal(sift.step(11.99, true), "sifting")
		t.equal(sift.press(12, "attempt", 1), "outside_check")
	end,
	["SIFT-5 perfect good miss and timeout apply approved additive modifiers"] = function(t)
		for _, case in { { "perfect", 1.6 }, { "good", 1.3 }, { "miss", 0.4 } } do
			local sift = setup()
			sift.start(10, "attempt", 0, 1)
			play(sift, case[1])
			t.equal(math.abs(sift.outputs.batch.skillMultiplier - case[2]) < 0.000001, true)
		end
		local sift = setup()
		sift.start(10, "attempt", 0, 1)
		t.equal(sift.step(16, true), "completed")
		t.equal(math.abs(sift.outputs.batch.value - 80) < 0.000001, true)
		for _, result in sift.outputs.batch.results do
			t.equal(result, "expired")
		end
	end,
	["SIFT-5 mixed grades retain identity and apply one combined adjustment"] = function(t)
		local sift, dig = setup()
		local outcome = dig.state.batches.batch.outcome
		sift.start(10, "attempt", 0, 1)
		t.equal(sift.press(11, "attempt", 1), "perfect")
		sift.step(12, true)
		t.equal(sift.press(12.7, "attempt", 2), "good")
		sift.step(14, true)
		t.equal(sift.press(14.1, "attempt", 3), "miss")
		sift.step(16, true)
		t.equal(sift.outputs.batch.outcome, outcome)
		t.equal(math.abs(sift.outputs.batch.value - 220) < 0.000001, true)
	end,
}
