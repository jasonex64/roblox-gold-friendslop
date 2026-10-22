--!strict
local SkillCheck = require("../../src/shared/Pure/SkillCheck")

local function start()
	return SkillCheck.start(10, { zoneWidth = 0.25, needleSpeed = 0.5 }, function()
		return 0.5
	end)
end

return {
	["SKILL-1 snapshots config and uses exactly one injected draw"] = function(t)
		local config = { zoneWidth = 0.25, needleSpeed = 0.5 }
		local calls = 0
		local check = SkillCheck.start(10, config, function()
			calls += 1
			return 0.5
		end)
		t.equal(check.startedAt, 10)
		t.equal(check.zoneStart, 0.375)
		t.equal(check.zoneWidth, 0.25)
		t.equal(check.needleSpeed, 0.5)
		t.equal(check.graded, false)
		t.equal(calls, 1)
		config.zoneWidth = 1
		config.needleSpeed = 3
		t.equal(check.zoneWidth, 0.25)
		t.equal(check.needleSpeed, 0.5)
	end,
	["SKILL-1 placement endpoints keep the whole zone inside the sweep"] = function(t)
		for _, placement in { 0, 0.5, 1 } do
			local check = SkillCheck.start(0, { zoneWidth = 0.25, needleSpeed = 2 }, function()
				return placement
			end)
			t.equal(check.zoneStart, placement * 0.75)
			t.equal(check.zoneStart >= 0 and check.zoneStart + check.zoneWidth <= 1, true)
		end
	end,
	["SKILL-1 invalid config and random draws fail loudly"] = function(t)
		for _, width in { 0, -1, 1.01, math.huge, 0 / 0 } do
			local calls = 0
			t.errors(function()
				SkillCheck.start(0, { zoneWidth = width, needleSpeed = 1 }, function()
					calls += 1
					return 0
				end)
			end)
			t.equal(calls, 0)
		end
		for _, speed in { 0, -1, math.huge, 0 / 0 } do
			t.errors(function()
				SkillCheck.start(0, { zoneWidth = 0.25, needleSpeed = speed }, function()
					return 0
				end)
			end)
		end
		for _, placement in { -0.01, 1.01, math.huge, 0 / 0 } do
			t.errors(function()
				SkillCheck.start(0, { zoneWidth = 0.25, needleSpeed = 1 }, function()
					return placement
				end)
			end)
		end
		for _, now in { -math.huge, math.huge, 0 / 0 } do
			t.errors(function()
				SkillCheck.start(now, { zoneWidth = 0.25, needleSpeed = 1 }, function()
					return 0
				end)
			end)
		end
	end,
	["SKILL-2 exact zone edges are inclusive and adjacent times miss"] = function(t)
		for _, case in
			{
				{ 10, "miss" },
				{ 10.749, "miss" },
				{ 10.75, "success" },
				{ 11, "success" },
				{ 11.25, "success" },
				{ 11.251, "miss" },
				{ 12, "miss" },
				{ 12.001, "expired" },
				{ 14, "expired" },
			}
		do
			t.equal(SkillCheck.grade(start(), case[1]), case[2])
		end
	end,
	["SKILL-2 sweep endpoints are inclusive even for a full-width zone"] = function(t)
		for _, case in { { 0, 0 }, { 1, 0.5 } } do
			local check = SkillCheck.start(0, { zoneWidth = 0.25, needleSpeed = 2 }, function()
				return case[1]
			end)
			t.equal(SkillCheck.grade(check, case[2]), "success")
		end
		for _, time in { 0, 0.5 } do
			local check = SkillCheck.start(0, { zoneWidth = 1, needleSpeed = 2 }, function()
				return 1
			end)
			t.equal(check.zoneStart, 0)
			t.equal(SkillCheck.grade(check, time), "success")
		end
	end,
	["SKILL-2 grade depends on elapsed time and configured speed"] = function(t)
		for _, origin in { 0, 10, 10000 } do
			for _, speed in { 0.25, 0.5, 2 } do
				local check = SkillCheck.start(
					origin,
					{ zoneWidth = 0.25, needleSpeed = speed },
					function()
						return 0.5
					end
				)
				t.equal(SkillCheck.grade(check, origin + 0.5 / speed), "success")
			end
		end
	end,
	["SKILL-2 decimal boundaries survive nonzero timestamp rounding"] = function(t)
		for _, origin in { 10, 10000 } do
			for _, edge in { "entry", "exit", "end" } do
				local check = SkillCheck.start(
					origin,
					{ zoneWidth = 0.2, needleSpeed = 0.7 },
					function()
						return 1
					end
				)
				local position = if edge == "entry" then check.zoneStart else 1
				t.equal(SkillCheck.grade(check, origin + position / check.needleSpeed), "success")
			end
		end
	end,
	["SKILL-2 invalid timestamps error without consuming check"] = function(t)
		local check = start()
		for _, time in { 9, -math.huge, math.huge, 0 / 0 } do
			t.errors(function()
				SkillCheck.grade(check, time)
			end)
			t.equal(check.graded, false)
		end
		t.equal(SkillCheck.grade(check, 11), "success")
	end,
	["SKILL-3 success miss and expiry each consume the check"] = function(t)
		for _, case in { { 11, "success" }, { 10, "miss" }, { 13, "expired" } } do
			local check = start()
			t.equal(SkillCheck.grade(check, case[1]), case[2])
			t.equal(check.graded, true)
			t.equal(check.zoneStart, 0.375)
			for _, retry in { 10, 11, 13 } do
				t.errors(function()
					SkillCheck.grade(check, retry)
				end)
			end
		end
	end,
}
