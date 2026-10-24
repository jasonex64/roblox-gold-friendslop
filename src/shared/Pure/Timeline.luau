--!strict
-- Shift timeline. All times are seconds since the shift started (after the ready
-- countdown); phase starts, the rich source name and the rush speedup are injected.
local Timeline = {}

export type Config = {
	nightStart: number,
	dawnStart: number,
	rushStart: number,
	shiftSeconds: number,
	richSource: string,
	-- Extra processing rate during the rush: 0.25 means 25% faster.
	rushSpeedup: number,
}

local function elapsedTime(value: number, name: string)
	assert(
		value >= 0 and value < math.huge,
		"Timeline: " .. name .. " must be finite and nonnegative"
	)
end

local function validate(config: Config)
	assert(
		0 < config.nightStart
			and config.nightStart < config.dawnStart
			and config.dawnStart < config.rushStart
			and config.rushStart < config.shiftSeconds
			and config.shiftSeconds < math.huge,
		"Timeline: phase starts must increase within the shift"
	)
	assert(config.richSource ~= "", "Timeline: richSource must not be empty")
	assert(
		config.rushSpeedup > 0 and config.rushSpeedup < math.huge,
		"Timeline: rushSpeedup must be positive"
	)
end

-- Each phase starts inclusively at its configured second.
function Timeline.phase(elapsed: number, config: Config): string
	validate(config)
	elapsedTime(elapsed, "elapsed")
	if elapsed >= config.shiftSeconds then
		return "ended"
	elseif elapsed >= config.rushStart then
		return "rush"
	elseif elapsed >= config.dawnStart then
		return "dawn"
	elseif elapsed >= config.nightStart then
		return "night"
	end
	return "day"
end

-- Gates new digging only. Dirt dug at night keeps its bonus because Batch stores
-- the outcome, including sourceMultiplier, at dig time.
function Timeline.canDig(source: string, elapsed: number, config: Config): string?
	assert(source ~= "", "Timeline.canDig: source must not be empty")
	if source == config.richSource and Timeline.phase(elapsed, config) ~= "night" then
		return "rich_bank_closed"
	end
	return nil
end

-- Processing runs at normal speed until the rush, then faster for whatever work
-- remains. The result may pass shiftSeconds; settlement discards such results.
function Timeline.finishAt(start: number, baseSeconds: number, config: Config): number
	validate(config)
	elapsedTime(start, "start")
	assert(
		baseSeconds > 0 and baseSeconds < math.huge,
		"Timeline.finishAt: baseSeconds must be positive"
	)
	local rate = 1 + config.rushSpeedup
	if start >= config.rushStart then
		return start + baseSeconds / rate
	end
	if start + baseSeconds <= config.rushStart then
		return start + baseSeconds
	end
	local remaining = baseSeconds - (config.rushStart - start)
	return config.rushStart + remaining / rate
end

return Timeline
