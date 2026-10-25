--!strict
local Config = require("../../src/shared/Config")
local Timeline = require("../../src/shared/Pure/Timeline")
local Dig = require("../../src/shared/Pure/Dig")
local Batch = require("../../src/shared/Pure/Batch")
local Sift = require("../../src/shared/Pure/Sift")
local SkillCheck = require("../../src/shared/Pure/SkillCheck")
local Hud = require("../../src/shared/Pure/Hud")
local function setup()
	local dig = Dig.new(Config, Batch, function(_, request)
		return {
			kind = "Gold",
			baseValue = Config.openingValue,
			sourceMultiplier = request.multiplier,
		}
	end)
	dig.finishAt = function(start, seconds)
		return Timeline.finishAt(start, seconds, Config)
	end
	local sift = Sift.new(Config, dig, Batch, SkillCheck, function()
		return 0.5
	end)
	sift.sweepDuration = function(start, settings, rate)
		return Timeline.sweepSeconds(
			start,
			settings.siftSweepSeconds,
			settings.rushSiftSweepSeconds,
			settings
		) / rate
	end
	return dig, sift
end
local function dirt(dig, id, at, source, multiplier)
	assert(dig.start({
		id = id,
		now = at,
		source = source,
		digger = "a",
		distance = 0,
		multiplier = multiplier,
	}, "running") == "started")
	assert(dig.step(dig.pending.due, 0, "running", source) == "created")
end
return {
	["GATE C scheduled dig straddles rush, keeps source bonus and cannot complete at cutoff"] = function(
		t
	)
		local dig = setup()
		local at = Config.rushStart - Config.digSeconds / 2
		t.equal(
			dig.start({
				id = "rush",
				now = at,
				source = "Bank",
				digger = "a",
				distance = 0,
				multiplier = 1,
			}, "running"),
			"started"
		)
		local due = Timeline.finishAt(at, Config.digSeconds, Config)
		t.equal(dig.pending.due, due)
		t.equal(dig.step(due - 0.001, 0, "running", "Bank"), "digging")
		t.equal(dig.step(due, 0, "running", "Bank"), "created")
		dirt(dig, "next", due, "Bank", 1)
		t.equal(dig.openingCount, 2)
		local rich = setup()
		dirt(
			rich,
			"rich",
			Config.dawnStart - Config.digSeconds / 2,
			Config.richSource,
			Config.richMultiplier
		)
		t.equal(rich.state.batches.rich.outcome.sourceMultiplier, Config.richMultiplier)
		t.equal(Timeline.canDig(Config.richSource, Config.dawnStart, Config), "rich_bank_closed")
		t.equal(
			dig.start({
				id = "late",
				now = Config.shiftSeconds - 0.1,
				source = "Bank",
				digger = "a",
				distance = 0,
				multiplier = 1,
			}, "running"),
			"started"
		)
		t.equal(dig.step(Config.shiftSeconds, 0, "closed", "Bank"), "cancelled")
		t.equal(dig.state.batches.late, nil)
	end,
	["GATE C active sweep stays normal across rush, following sweeps shorten"] = function(t)
		local dig, sift = setup()
		dirt(dig, "rich", Config.nightStart, Config.richSource, Config.richMultiplier)
		local at = Config.rushStart - 1
		t.equal(sift.start(at, "attempt", 0, 1), "started")
		local first = sift.pending.checks[1]
		t.equal(sift.pending.duration, Config.siftSweepSeconds)
		t.equal(sift.step(Config.rushStart, true), "sifting")
		t.equal(first.needleSpeed, 1 / Config.siftSweepSeconds)
		local secondStart = at + Config.siftSweepSeconds
		sift.step(secondStart, true)
		t.equal(sift.pending.index, 2)
		t.equal(sift.pending.duration, Config.rushSiftSweepSeconds)
		local finish = sift.pending.endsAt
		local code, find = sift.step(finish, true)
		t.equal(code, "completed")
		t.equal(find.outcome.sourceMultiplier, Config.richMultiplier)
		t.equal(
			find.value,
			math.round(Config.openingValue * Config.richMultiplier * Config.siftMinimumValue)
		)
	end,
	["GATE C early presses reschedule future sweeps on the correct side of rush"] = function(t)
		local dig, sift = setup()
		dirt(dig, "a", 0, "Bank", 1)
		local at = Config.rushStart - 1
		sift.start(at, "attempt", 0, 1)
		t.equal(sift.pending.checks[2].needleSpeed, 1 / Config.rushSiftSweepSeconds)
		sift.press(at + 0.1, "attempt", 1)
		t.equal(sift.pending.checks[2].startedAt, at + 0.1)
		t.equal(sift.pending.duration, Config.siftSweepSeconds)
		t.equal(sift.pending.checks[2].needleSpeed, 1 / Config.siftSweepSeconds)
		sift.press(Config.rushStart, "attempt", 2)
		t.equal(sift.pending.duration, Config.rushSiftSweepSeconds)
		t.equal(sift.pending.checks[3].startedAt, Config.rushStart)
		t.equal(sift.press(Config.rushStart, "old", 3), "stale_check")
		t.equal(sift.step(Config.shiftSeconds, false), "cancelled")
		t.equal(next(sift.outputs), nil)
	end,
	["GATE C rush-start sift lasts three short sweeps and HUD explains all phases"] = function(t)
		local dig, sift = setup()
		dirt(dig, "a", 0, "Bank", 1)
		sift.start(Config.rushStart, "attempt", 0, 1)
		t.equal(
			math.abs(
				sift.pending.endsAt
					- Config.rushStart
					- Config.siftChecks * Config.rushSiftSweepSeconds
			) < 1e-9,
			true
		)
		for _, phase in { "day", "night", "dawn", "rush", "ended" } do
			local text = Hud.timeline(phase, 10, 20, 30)
			t.equal(string.find(text, "discarded without payment", 1, true) ~= nil, true)
		end
		t.equal(string.find(Hud.timeline("night", 10, 20, 30), "OPEN", 1, true) ~= nil, true)
		t.equal(string.find(Hud.timeline("dawn", 0, 20, 30), "CLOSED", 1, true) ~= nil, true)
		t.errors(function()
			Hud.timeline("bogus", 0, 0, 0)
		end)
	end,
}
