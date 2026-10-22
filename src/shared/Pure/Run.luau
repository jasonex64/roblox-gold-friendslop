--!strict
-- Pure Gate A lifecycle; timestamps and readiness are supplied by the server.
local Run = {}

export type Config = { readySeconds: number, shiftSeconds: number }
export type State = {
	id: string,
	phase: string,
	config: Config,
	lastNow: number,
	readyAt: number?,
	startedAt: number?,
	endsAt: number?,
}

local function finite(value: number): boolean
	return value > -math.huge and value < math.huge
end

function Run.new(runId: string, now: number, config: Config): State
	assert(runId ~= "", "Run.new: runId must not be empty")
	assert(finite(now), "Run.new: now must be finite")
	assert(
		finite(config.readySeconds) and config.readySeconds >= 0,
		"Run.new: invalid readySeconds"
	)
	assert(finite(config.shiftSeconds) and config.shiftSeconds > 0, "Run.new: invalid shiftSeconds")
	return {
		id = runId,
		phase = "waiting",
		config = table.freeze({
			readySeconds = config.readySeconds,
			shiftSeconds = config.shiftSeconds,
		}),
		lastNow = now,
	}
end

-- Mutates the retained server run. Readiness must stay true through countdown;
-- once running, readiness no longer pauses or extends the shift.
function Run.advance(run: State, now: number, ready: boolean)
	assert(finite(now) and now >= run.lastNow, "Run.advance: now must be finite and monotonic")
	assert(type(ready) == "boolean", "Run.advance: ready must be boolean")
	assert(run.phase ~= "reset", "Run.advance: run has been reset")
	if run.phase == "waiting" or run.phase == "countdown" then
		if not ready then
			run.readyAt = nil
			run.phase = "waiting"
		else
			local readyAt = run.readyAt
			if readyAt == nil then
				readyAt = now
			end
			local startedAt = readyAt + run.config.readySeconds
			local endsAt = startedAt + run.config.shiftSeconds
			assert(
				finite(startedAt) and finite(endsAt) and endsAt > startedAt,
				"Run.advance: invalid time range"
			)
			run.readyAt = readyAt
			run.phase = "countdown"
			if now >= startedAt then
				run.startedAt = startedAt
				run.endsAt = endsAt
				run.phase = "running"
			end
		end
	end
	if run.phase == "running" then
		local endsAt = run.endsAt
		assert(endsAt ~= nil, "Run.advance: running run has no endsAt")
		if now >= endsAt then
			run.phase = "ended"
		end
	end
	run.lastNow = now
end

-- No state mutation. Check the actual cutoff even if advance has not ticked yet.
function Run.accepts(run: State, now: number): boolean
	assert(finite(now), "Run.accepts: now must be finite")
	if run.phase ~= "running" then
		return false
	end
	local startedAt, endsAt = run.startedAt, run.endsAt
	assert(startedAt ~= nil and endsAt ~= nil, "Run.accepts: running run has no time range")
	return now >= run.lastNow and now >= startedAt and now < endsAt
end

function Run.finish(run: State): { string }
	assert(run.phase == "ended", "Run.finish: run must be ended and not already finished")
	run.phase = "results"
	return { "stop_production", "sell_completed", "discard_unprocessed", "freeze_result" }
end

-- Call only after executing finish's steps. The caller owns the unique initial
-- ID namespace; appending /replay gives each successor a distinct ID in its chain.
-- Reconstruct rather than clone, so attached inventory/cash/results cannot leak.
function Run.reset(run: State): State
	assert(run.phase == "results", "Run.reset: run must be finished and not already reset")
	local fresh = Run.new(run.id .. "/replay", run.lastNow, run.config)
	run.phase = "reset"
	return fresh
end

return Run
