--!strict
-- Owns reservations and results; dependencies and authoritative time are injected.
local Sift = {}
local function finite(value)
	return type(value) == "number" and value > -math.huge and value < math.huge
end

function Sift.new(config, dig, Batch, SkillCheck, rng)
	local self = { pending = nil, outputs = {}, reserved = 0 }
	local function countOutputs()
		local count = 0
		for _ in self.outputs do
			count += 1
		end
		return count
	end
	function self.start(now, attemptId, upgrades, rate)
		assert(finite(now), "Sift: invalid start time")
		assert(type(attemptId) == "string" and attemptId ~= "", "Sift: missing attempt ID")
		assert(
			finite(upgrades) and upgrades >= 0 and upgrades % 1 == 0,
			"Sift: invalid upgrade count"
		)
		assert(finite(rate) and rate > 0, "Sift: invalid processing rate")
		if self.pending then
			return "busy_sifting"
		end
		if dig.pending then
			return "busy_digging"
		end
		if countOutputs() + self.reserved >= config.outputCapacity then
			return "full_output"
		end
		local selected = nil
		for _, item in dig.state.batches do
			if item.status == "queued" and (selected == nil or item.id < selected.id) then
				selected = item
			end
		end
		if not selected then
			return "no_dirt"
		end
		local settings = table.clone(config)
		local scale = 1 + upgrades * settings.siftUpgradeWidth
		-- Normalized sweep geometry saturates at a full sweep, retaining proportions.
		local starterWidth = settings.siftPerfectWidth + 2 * settings.siftGoodWidth
		scale = math.min(scale, 1 / starterWidth)
		local duration = settings.siftSweepSeconds / rate
		local interval = duration + settings.siftPreviewSeconds
		local checks = {}
		for index = 1, settings.siftChecks do
			checks[index] =
				SkillCheck.start(now + settings.siftPreviewSeconds + (index - 1) * interval, {
					zoneWidth = starterWidth * scale,
					perfectWidth = settings.siftPerfectWidth * scale,
					needleSpeed = 1 / duration,
				}, rng, checks[index - 1])
		end
		local batches = table.clone(dig.state.batches)
		batches[selected.id] = Batch.transition(selected, "processing")
		dig.state = table.clone(dig.state)
		dig.state.batches = batches
		dig.sifting = true
		self.reserved = 1
		self.pending = {
			id = attemptId,
			batchId = selected.id,
			checks = checks,
			index = 1,
			startedAt = now,
			endsAt = now + settings.siftChecks * interval,
			duration = duration,
			rate = rate,
			settings = settings,
			results = {},
		}
		return "started"
	end
	function self.cancel()
		local pending = self.pending
		if not pending then
			return "idle"
		end
		-- D-014/015: cancellation destroys this batch, without replacing its loot.
		local batches = table.clone(dig.state.batches)
		batches[pending.batchId] = nil
		dig.state = table.clone(dig.state)
		dig.state.batches = batches
		dig.sifting = false
		self.pending = nil
		self.reserved = 0
		return "cancelled"
	end
	function self.press(now, attemptId, index)
		assert(finite(now), "Sift: invalid press time")
		local pending = self.pending
		if not pending or attemptId ~= pending.id or index ~= pending.index then
			return "stale_check"
		end
		local check = pending.checks[index]
		if now < check.startedAt or now >= check.startedAt + pending.duration then
			return "outside_check"
		end
		if check.graded then
			return "already_graded"
		end
		local result = SkillCheck.grade(check, now)
		pending.results[index] = result
		-- D-021: accepted hits resolve immediately; keep the next preview intact.
		local saved = check.startedAt + pending.duration - now
		for nextIndex = index + 1, #pending.checks do
			pending.checks[nextIndex].startedAt -= saved
		end
		pending.endsAt -= saved
		local _, find = self.step(now, true)
		return result, find
	end
	function self.step(now, allowed)
		assert(finite(now), "Sift: invalid step time")
		local pending = self.pending
		if not pending then
			return "idle"
		end
		-- Cutoff/context loss wins over a completion in the same server tick.
		if not allowed then
			return self.cancel()
		end
		assert(now >= pending.startedAt, "Sift: step precedes start")
		while pending.index <= #pending.checks do
			local check = pending.checks[pending.index]
			if not check.graded and now < check.startedAt + pending.duration then
				return "sifting"
			end
			if not check.graded then
				SkillCheck.grade(check, now)
				-- No input is a miss, even if the target happens to end at the sweep boundary.
				pending.results[pending.index] = "expired"
			end
			pending.index += 1
		end
		assert(self.reserved == 1, "Sift: completion requires reservation")
		assert(countOutputs() < config.outputCapacity, "Sift: reserved output space lost")
		local item = dig.state.batches[pending.batchId]
		assert(item and not self.outputs[item.id], "Sift: missing or duplicate batch")
		local modifier = 1
		for _, result in pending.results do
			if result == "perfect" then
				modifier += pending.settings.siftPerfectBonus
			elseif result == "good" then
				modifier += pending.settings.siftGoodBonus
			else
				assert(result == "miss" or result == "expired", "Sift: unknown grade")
				modifier -= pending.settings.siftMissPenalty
			end
		end
		modifier = math.max(pending.settings.siftMinimumValue, modifier)
		-- D-017/018: round each complete find, not the later sale total.
		local value = math.round(item.outcome.baseValue * item.outcome.sourceMultiplier * modifier)
		assert(finite(value) and value >= 0, "Sift: invalid completed value")
		local find = table.freeze({
			id = item.id,
			source = item.source,
			digger = item.digger,
			outcome = item.outcome,
			kind = item.outcome.kind,
			skillMultiplier = modifier,
			value = value,
			results = table.freeze(table.clone(pending.results)),
		})
		local batches = table.clone(dig.state.batches)
		batches[item.id] = Batch.transition(item, "completed")
		dig.state = table.clone(dig.state)
		dig.state.batches = batches
		self.outputs[item.id] = find
		self.reserved = 0
		self.pending = nil
		dig.sifting = false
		return "completed", find
	end
	return self
end
return Sift
