--!strict
local Batch = require("../../src/shared/Pure/Batch")

local function fixture()
	local state = { phase = "day", batches = {}, lastDigAt = {} }
	local request = { id = "batch-a", source = "bank", digger = "alice", distance = 8, now = 10 }
	local config = { digPhases = { day = true }, maxDistance = 8, capacity = 2, digInterval = 1 }
	local calls = 0
	local outcome = {
		kind = "crate",
		baseValue = 12,
		sourceMultiplier = 1.5,
		crateKind = "gold",
		crateValue = 40,
	}
	local function rng()
		calls += 1
		return outcome
	end
	return state, request, config, rng, function()
		return calls
	end, outcome
end

return {
	["BATCH-1 rejected requests preserve state and do not draw"] = function(t)
		for _, reason in { "wrong_phase", "out_of_range", "full_capacity", "over_rate" } do
			local state, request, config, rng, calls = fixture()
			if reason == "wrong_phase" then
				state.phase = "results"
			elseif reason == "out_of_range" then
				request.distance = 8.01
			elseif reason == "full_capacity" then
				config.capacity = 0
			else
				state.lastDigAt.alice = 9.01
			end
			local result, rejection = Batch.create(state, request, config, rng)
			t.equal(result, state)
			t.equal(rejection, reason)
			t.equal(next(state.batches), nil)
			t.equal(calls(), 0)
		end
	end,
	["BATCH-1 exact boundaries, per-player rate and actual carry capacity"] = function(t)
		local state, request, config, rng, calls = fixture()
		state.lastDigAt.alice = 9
		local first, reason = Batch.create(state, request, config, rng)
		t.equal(reason, nil)
		t.equal(next(state.batches), nil)
		t.equal(state.lastDigAt.alice, 9)
		request.id = "batch-b"
		local rejected, rate = Batch.create(first, request, config, rng)
		t.equal(rejected, first)
		t.equal(rate, "over_rate")
		request.now = 11
		local second = Batch.create(first, request, config, rng)
		second.batches["batch-a"] = Batch.transition(second.batches["batch-a"], "processing")
		request.id = "batch-c"
		request.now = 12
		local full, capacity = Batch.create(second, request, config, rng)
		t.equal(full, second)
		t.equal(capacity, "full_capacity")
		request.digger = "bob"
		local bob, accepted = Batch.create(second, request, config, rng)
		t.equal(accepted, "full_capacity")
		t.equal(bob, second)
		t.equal(calls(), 2)
		second.batches["batch-a"] = Batch.transition(second.batches["batch-a"], "completed")
		request.digger = "alice"
		local freed, freedReason = Batch.create(second, request, config, rng)
		t.equal(freedReason, nil)
		t.equal(freed.batches["batch-c"].status, "queued")
	end,
	["BATCH-1 invalid distance and time fail closed"] = function(t)
		for _, distance in { -1, math.huge, 0 / 0 } do
			local state, request, config, rng, calls = fixture()
			request.distance = distance
			local result, reason = Batch.create(state, request, config, rng)
			t.equal(result, state)
			t.equal(reason, "out_of_range")
			t.equal(calls(), 0)
		end
		for _, now in { math.huge, -math.huge, 0 / 0 } do
			local state, request, config, rng, calls = fixture()
			request.now = now
			local result, reason = Batch.create(state, request, config, rng)
			t.equal(result, state)
			t.equal(reason, "invalid_time")
			t.equal(calls(), 0)
		end
	end,
	["BATCH-2 identity and complete outcome survive cancel retry and resolver mutation"] = function(
		t
	)
		local state, request, config, rng, calls, rolled = fixture()
		local created = Batch.create(state, request, config, rng)
		local item = created.batches[request.id]
		t.equal(item.id, "batch-a")
		t.equal(item.source, "bank")
		t.equal(item.digger, "alice")
		rolled.crateValue = 999
		t.equal(item.outcome.crateValue, 40)
		t.equal(item.outcome.sourceMultiplier, 1.5)
		t.errors(function()
			item.outcome.baseValue = 999
		end)
		local processing = Batch.transition(item, "processing")
		for _ = 1, 3 do
			local cancelled = Batch.cancel(processing)
			t.equal(cancelled.status, "processing")
			t.equal(cancelled.active, false)
			t.equal(processing.active, true)
			t.errors(function()
				Batch.transition(cancelled, "completed")
			end)
			processing = Batch.retry(cancelled)
			t.equal(processing.outcome, item.outcome)
		end
		local sold = Batch.transition(Batch.transition(processing, "completed"), "sold")
		t.equal(sold.outcome, item.outcome)
		t.equal(calls(), 1)
		request.now = 11
		local duplicate, reason = Batch.create(created, request, config, rng)
		t.equal(duplicate, created)
		t.equal(reason, "duplicate_id")
		t.equal(calls(), 1)
	end,
	["BATCH-3 only the three forward transitions are legal"] = function(t)
		local state, request, config, rng = fixture()
		local created = Batch.create(state, request, config, rng)
		local queued = created.batches[request.id]
		local processing = Batch.transition(queued, "processing")
		local completed = Batch.transition(processing, "completed")
		local sold = Batch.transition(completed, "sold")
		local allowed = { queued = "processing", processing = "completed", completed = "sold" }
		for _, item in { queued, processing, completed, sold } do
			for _, target in { "queued", "processing", "completed", "sold", "invalid" } do
				if allowed[item.status] == target then
					t.equal(Batch.transition(item, target).status, target)
				else
					t.errors(function()
						Batch.transition(item, target)
					end)
				end
			end
			if item.status ~= "processing" then
				t.errors(function()
					Batch.cancel(item)
				end)
			end
			t.errors(function()
				Batch.retry(item)
			end)
		end
		local cancelled = Batch.cancel(processing)
		t.errors(function()
			Batch.cancel(cancelled)
		end)
		t.equal(queued.status, "queued")
		t.equal(processing.status, "processing")
	end,
}
