--!strict
local Run = require("../../src/shared/Pure/Run")

local function new()
	return Run.new("run-a", 10, { readySeconds = 3, shiftSeconds = 20 })
end

local function ended()
	local run = new()
	Run.advance(run, 10, true)
	Run.advance(run, 33, true)
	return run
end

return {
	["RUN-SM-1 waits for readiness and excludes countdown from shift"] = function(t)
		local run = new()
		t.equal(run.phase, "waiting")
		t.equal(Run.accepts(run, 10), false)
		Run.advance(run, 50, false)
		t.equal(run.startedAt, nil)
		Run.advance(run, 60, true)
		t.equal(run.phase, "countdown")
		t.equal(Run.accepts(run, 62.999), false)
		Run.advance(run, 63, true)
		t.equal(run.phase, "running")
		t.equal(run.startedAt, 63)
		t.equal(run.endsAt, 83)
		t.equal(Run.accepts(run, 62.999), false)
		t.equal(Run.accepts(run, 63), true)
		t.equal(Run.accepts(run, 82.999), true)
		t.equal(Run.accepts(run, 83), false)
		t.equal(Run.accepts(run, 100), false)
		Run.advance(run, 83, false)
		t.equal(run.phase, "ended")
		t.equal(Run.accepts(run, 70), false)
	end,
	["RUN-SM-1 readiness loss restarts countdown but does not pause running"] = function(t)
		local run = new()
		Run.advance(run, 10, true)
		Run.advance(run, 12, false)
		t.equal(run.phase, "waiting")
		t.equal(run.readyAt, nil)
		Run.advance(run, 20, true)
		Run.advance(run, 23, true)
		Run.advance(run, 24, false)
		t.equal(run.phase, "running")
		t.equal(run.startedAt, 23)
		t.equal(run.endsAt, 43)
		t.equal(Run.accepts(run, 24), true)
		t.equal(Run.accepts(run, 23), false)
	end,
	["RUN-SM-1 delayed ticks preserve scheduled boundaries and can skip entire shift"] = function(
		t
	)
		local run = new()
		Run.advance(run, 10, true)
		Run.advance(run, 15, true)
		t.equal(run.startedAt, 13)
		t.equal(run.endsAt, 33)
		local skipped = new()
		Run.advance(skipped, 10, true)
		Run.advance(skipped, 100, true)
		t.equal(skipped.phase, "ended")
		t.equal(skipped.startedAt, 13)
		t.equal(skipped.endsAt, 33)
		t.equal(Run.accepts(skipped, 100), false)
	end,
	["RUN-SM-1 zero countdown and config snapshots"] = function(t)
		local config = { readySeconds = 0, shiftSeconds = 5 }
		local run = Run.new("instant", 0, config)
		config.shiftSeconds = 100
		Run.advance(run, 2, true)
		t.equal(run.phase, "running")
		t.equal(run.endsAt, 7)
		t.equal(Run.accepts(run, 7), false)
		t.errors(function()
			run.config.shiftSeconds = 100
		end)
	end,
	["RUN-SM-1 invalid inputs and backwards clock fail loudly"] = function(t)
		for _, bad in { -1, math.huge, 0 / 0 } do
			t.errors(function()
				Run.new("bad", 0, { readySeconds = bad, shiftSeconds = 5 })
			end)
			t.errors(function()
				Run.new("bad", 0, { readySeconds = 0, shiftSeconds = bad })
			end)
		end
		t.errors(function()
			Run.new("bad", 0, { readySeconds = 0, shiftSeconds = 0 })
		end)
		local run = new()
		for _, bad in { 9, math.huge, -math.huge, 0 / 0 } do
			t.errors(function()
				Run.advance(run, bad, true)
			end)
			t.equal(run.phase, "waiting")
			t.equal(run.lastNow, 10)
		end
		for _, bad in { math.huge, -math.huge, 0 / 0 } do
			t.errors(function()
				Run.new("bad", bad, { readySeconds = 0, shiftSeconds = 5 })
			end)
			t.errors(function()
				Run.accepts(run, bad)
			end)
		end
	end,
	["RUN-SM-2 finish returns exactly the required order once"] = function(t)
		local run = ended()
		local steps = Run.finish(run)
		t.equal(#steps, 3)
		for index, expected in { "stop_production", "discard_unsold", "freeze_result" } do
			t.equal(steps[index], expected)
		end
		t.equal(run.phase, "results")
		t.equal(Run.accepts(run, 33), false)
		t.errors(function()
			Run.finish(run)
		end)
		Run.advance(run, 40, true)
		t.equal(run.phase, "results")
	end,
	["RUN-SM-2 early finish and reset are rejected"] = function(t)
		local run = new()
		for _, time in { 10, 11, 13 } do
			t.errors(function()
				Run.finish(run)
			end)
			t.errors(function()
				Run.reset(run)
			end)
			Run.advance(run, time, true)
		end
		t.equal(run.phase, "running")
		t.errors(function()
			Run.finish(run)
		end)
		Run.advance(run, 33, true)
		t.errors(function()
			Run.reset(run)
		end)
	end,
	["RUN-SM-3 reset clears carried state and yields unique single-use replay"] = function(t)
		local run = ended()
		Run.finish(run)
		local attached: any = run
		attached.inventory = { "gold" }
		attached.wallet = 99
		attached.upgrade = "shovel"
		attached.openingCounter = 5
		attached.result = { haul = 200 }
		local fresh = Run.reset(run)
		t.equal(fresh.id ~= run.id, true)
		t.equal(fresh.phase, "waiting")
		t.equal(fresh.startedAt, nil)
		t.equal(fresh.endsAt, nil)
		t.equal(fresh.readyAt, nil)
		local cleared: any = fresh
		for _, field in { "inventory", "wallet", "upgrade", "openingCounter", "result" } do
			t.equal(cleared[field], nil)
		end
		t.equal(fresh.config == run.config, false)
		t.equal(fresh.config.shiftSeconds, 20)
		t.equal(Run.accepts(run, 33), false)
		t.errors(function()
			Run.reset(run)
		end)
		t.errors(function()
			Run.advance(run, 40, true)
		end)
		Run.advance(fresh, 40, true)
		Run.advance(fresh, 63, true)
		Run.finish(fresh)
		local third = Run.reset(fresh)
		t.equal(third.id ~= fresh.id and third.id ~= run.id, true)
		t.equal(third.phase, "waiting")
	end,
}
