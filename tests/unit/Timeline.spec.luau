--!strict
local Timeline = require("../../src/shared/Pure/Timeline")

local function config()
	return {
		nightStart = 300,
		dawnStart = 480,
		rushStart = 540,
		shiftSeconds = 600,
		richSource = "rich",
		rushSpeedup = 0.25,
	}
end

local function namedError(t, fn, text)
	local ok, message = pcall(fn)
	t.equal(ok, false)
	t.equal(string.find(tostring(message), text, 1, true) ~= nil, true)
end

return {
	["TIME-1 phases start inclusively at their configured second"] = function(t)
		local cfg = config()
		t.equal(Timeline.phase(0, cfg), "day")
		t.equal(Timeline.phase(299.999, cfg), "day")
		t.equal(Timeline.phase(300, cfg), "night")
		t.equal(Timeline.phase(479.999, cfg), "night")
		t.equal(Timeline.phase(480, cfg), "dawn")
		t.equal(Timeline.phase(540, cfg), "rush")
		t.equal(Timeline.phase(599.999, cfg), "rush")
		t.equal(Timeline.phase(600, cfg), "ended")
		namedError(t, function()
			Timeline.phase(-1, cfg)
		end, "elapsed must be finite and nonnegative")
		namedError(t, function()
			Timeline.phase(0 / 0, cfg)
		end, "elapsed must be finite and nonnegative")
		local bad = config()
		bad.dawnStart = 300
		namedError(t, function()
			Timeline.phase(0, bad)
		end, "phase starts must increase")
	end,
	["TIME-2 the rich bank accepts digging only at night"] = function(t)
		local cfg = config()
		t.equal(Timeline.canDig("rich", 299.999, cfg), "rich_bank_closed")
		t.equal(Timeline.canDig("rich", 300, cfg), nil)
		t.equal(Timeline.canDig("rich", 479.999, cfg), nil)
		t.equal(Timeline.canDig("rich", 480, cfg), "rich_bank_closed")
		t.equal(Timeline.canDig("rich", 550, cfg), "rich_bank_closed")
		-- The ordinary bank stays open through every phase.
		for _, elapsed in { 0, 300, 480, 540, 599 } do
			t.equal(Timeline.canDig("ordinary", elapsed, cfg), nil)
		end
	end,
	["TIME-3 processing before the rush runs at normal speed"] = function(t)
		local cfg = config()
		t.equal(Timeline.finishAt(100, 6, cfg), 106)
		-- Finishing exactly when the rush starts gets no speedup.
		t.equal(Timeline.finishAt(530, 10, cfg), 540)
		namedError(t, function()
			Timeline.finishAt(100, 0, cfg)
		end, "baseSeconds must be positive")
	end,
	["TIME-4 the rush speeds up only the work left after it starts"] = function(t)
		local cfg = config()
		-- 5 s of work at 1.25x takes 4 s.
		t.equal(Timeline.finishAt(540, 5, cfg), 544)
		-- 5 s done before the rush, the other 5 s at 1.25x.
		t.equal(Timeline.finishAt(535, 10, cfg), 544)
		-- Results past the bell are returned as-is for settlement to discard.
		t.equal(Timeline.finishAt(598, 5, cfg), 602)
	end,
}
