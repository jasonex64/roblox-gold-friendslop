--!strict
-- Positions are normalized to [0, 1]; speed is sweeps per second.
-- The server owns the check and supplies authoritative timestamps.
local SkillCheck = {}

export type Config = { zoneWidth: number, needleSpeed: number, perfectWidth: number? }
export type Check = {
	startedAt: number,
	zoneStart: number,
	zoneWidth: number,
	needleSpeed: number,
	graded: boolean,
	perfectWidth: number?,
}

local function finite(value: number): boolean
	return value > -math.huge and value < math.huge
end

function SkillCheck.start(now: number, config: Config, rng: () -> number, previous: Check?): Check
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
	if config.perfectWidth ~= nil then
		assert(
			config.perfectWidth > 0 and config.perfectWidth <= config.zoneWidth,
			"SkillCheck.start: perfectWidth must fit inside zoneWidth"
		)
	end
	local placement = rng()
	assert(placement >= 0 and placement <= 1, "SkillCheck.start: rng must return a value in [0, 1]")
	local maximum = 1 - config.zoneWidth
	local zoneStart = placement * maximum
	if previous then
		-- Sample the free spans on either side of the previous target, once.
		-- Adjacent checks cannot overlap when their widths leave room to separate.
		local leftEnd = previous.zoneStart - config.zoneWidth
		local rightStart = previous.zoneStart + previous.zoneWidth
		local leftLength = math.max(0, leftEnd)
		local rightLength = math.max(0, maximum - rightStart)
		local distance = placement * (leftLength + rightLength)
		if leftLength + rightLength > 0 then
			zoneStart = if distance < leftLength or rightLength == 0
				then distance
				else rightStart + distance - leftLength
		elseif leftEnd >= 0 then
			zoneStart = 0
		elseif rightStart <= maximum then
			zoneStart = maximum
		else
			-- Very wide upgraded targets cannot be disjoint. Maximize separation.
			zoneStart = if previous.zoneStart < maximum / 2 then maximum else 0
		end
	end
	return {
		startedAt = now,
		zoneStart = zoneStart,
		zoneWidth = config.zoneWidth,
		needleSpeed = config.needleSpeed,
		graded = false,
		perfectWidth = config.perfectWidth,
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
		if check.perfectWidth ~= nil then
			local goodWidth = (check.zoneWidth - check.perfectWidth) / 2
			local perfectEntry = check.startedAt + (check.zoneStart + goodWidth) / check.needleSpeed
			local perfectExit = check.startedAt
				+ (check.zoneStart + goodWidth + check.perfectWidth) / check.needleSpeed
			return if pressTime >= perfectEntry and pressTime <= perfectExit
				then "perfect"
				else "good"
		end
		return "success"
	else
		return "miss"
	end
end

return SkillCheck
