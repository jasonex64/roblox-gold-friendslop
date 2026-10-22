--!strict
-- Positions are normalized to [0, 1]; speed is sweeps per second.
-- The server owns the check and supplies authoritative timestamps.
local SkillCheck = {}

export type Config = { zoneWidth: number, needleSpeed: number }
export type Check = {
	startedAt: number,
	zoneStart: number,
	zoneWidth: number,
	needleSpeed: number,
	graded: boolean,
}

local function finite(value: number): boolean
	return value > -math.huge and value < math.huge
end

function SkillCheck.start(now: number, config: Config, rng: () -> number): Check
	assert(finite(now), "SkillCheck.start: now must be finite")
	assert(
		config.zoneWidth > 0 and config.zoneWidth <= 1,
		"SkillCheck.start: zoneWidth must be in (0, 1]"
	)
	assert(
		finite(config.needleSpeed) and config.needleSpeed > 0,
		"SkillCheck.start: needleSpeed must be finite and positive"
	)
	-- A single normalized draw places the whole zone inside the sweep.
	local placement = rng()
	assert(placement >= 0 and placement <= 1, "SkillCheck.start: rng must return a value in [0, 1]")
	return {
		startedAt = now,
		zoneStart = placement * (1 - config.zoneWidth),
		zoneWidth = config.zoneWidth,
		needleSpeed = config.needleSpeed,
		graded = false,
	}
end

-- Mutates only the consumed flag. Keep the original server check, not a copy.
-- Invalid timestamps error without consuming it. A sweep never wraps around.
function SkillCheck.grade(check: Check, pressTime: number): string
	assert(not check.graded, "SkillCheck.grade: check already graded")
	assert(finite(pressTime), "SkillCheck.grade: pressTime must be finite")
	assert(pressTime >= check.startedAt, "SkillCheck.grade: pressTime precedes check start")
	local zoneEntry = check.startedAt + check.zoneStart / check.needleSpeed
	local zoneExit = check.startedAt + (check.zoneStart + check.zoneWidth) / check.needleSpeed
	check.graded = true
	-- Compare against time boundaries rather than subtracting a large timestamp
	-- and multiplying back by speed, which can round an exact edge outside.
	if pressTime > check.startedAt + 1 / check.needleSpeed then
		return "expired"
	elseif pressTime >= zoneEntry and pressTime <= zoneExit then
		return "success"
	else
		return "miss"
	end
end

return SkillCheck
