--!strict
-- End-to-end fake-store evidence; no live data store or human playtest.
local serde = require("@lune/serde")
local Profile = require("../../src/shared/Pure/Profile")
local Progression = require("../../src/server/Progression")
local Rewards = require("../../src/shared/Pure/RunRewards")
local Flow = require("../../src/server/RewardFlow")
local Config = require("../../src/shared/Config")
local function snapshot(runId)
	return {
		runId = runId,
		rulesVersion = "rules",
		crewSize = 2,
		crewHaul = 12000,
		assisted = false,
		participants = {
			[42] = { activeSeconds = 490, discoveries = { Ruby = true } },
			[7] = { activeSeconds = 70, discoveries = { ["Gold Flakes"] = true } },
		},
	}
end
local function setup()
	local data = {}
	local store =
		{ failRead = false, failWrite = false, failApply = false, loseAck = false, writes = 0 }
	local function copy(v)
		return if v == nil then nil else serde.decode("json", serde.encode("json", v))
	end
	function store.read(key)
		if store.failRead then
			return false, "read failed"
		end
		return true, copy(data[key])
	end
	function store.update(key, transform)
		if store.failWrite then
			return false, "write failed"
		end
		local old = copy(data[key])
		local new = transform(old)
		if new and old and new.completedRuns > old.completedRuns and store.failApply then
			return false, "apply failed"
		end
		if new then
			data[key] = copy(new)
			store.writes += 1
		end
		if store.loseAck then
			store.loseAck = false
			return false, "ack lost"
		end
		return true, copy(new)
	end
	local queue = {}
	local function schedule(fn)
		table.insert(queue, fn)
	end
	local function drain()
		while #queue > 0 do
			local fn = table.remove(queue, 1)
			fn()
		end
	end
	local service = Progression.new(store, Profile)
	local flow = Flow.new(service, Rewards.build, Config, schedule, function() end)
	return flow, service, store, drain, schedule
end
return {
	["REWARDFLOW bell is non-yielding and duplicate finish cannot grant twice"] = function(t)
		local flow, service, _, drain = setup()
		t.equal(flow.finish(snapshot("one")), "started")
		t.equal(flow.result("one", 42).status, "pending")
		t.equal(flow.durable("one"), false)
		t.equal(flow.finish(snapshot("one")), "already_started")
		drain()
		t.equal(flow.durable("one"), true)
		t.equal(flow.result("one", 42).status, "saved")
		t.equal(flow.result("one", 7).status, "saved")
		t.equal(service.load(42).profile.tokens, 32)
		t.equal(service.load(7).profile.tokens, 0)
		t.equal(service.load(7).profile.discoveries["Gold Flakes"], true)
		flow.retry("one")
		drain()
		t.equal(service.load(42).profile.completedRuns, 1)
	end,
	["REWARDFLOW failed manifest write blocks replay until explicit recovery"] = function(t)
		local flow, service, store, drain = setup()
		flow.recover(42)
		flow.recover(7)
		drain()
		store.failWrite = true
		flow.finish(snapshot("one"))
		drain()
		t.equal(flow.durable("one"), false)
		t.equal(flow.result("one", 42).status, "failed")
		t.equal(service.load(42).profile.tokens, 0)
		store.failWrite = false
		flow.retry("one")
		drain()
		t.equal(flow.durable("one"), true)
		t.equal(flow.result("one", 42).status, "saved")
		t.equal(service.load(42).profile.tokens, 32)
	end,
	["REWARDFLOW pending apply recovers after restart including departed recipients"] = function(t)
		local flow, service, store, drain, schedule = setup()
		store.failApply = true
		flow.finish(snapshot("one"))
		drain()
		t.equal(flow.durable("one"), true)
		t.equal(flow.result("one", 42).status, "failed")
		t.equal(service.load(42).profile.tokens, 0)
		store.failApply = false
		local restarted = Flow.new(service, Rewards.build, Config, schedule, function() end)
		restarted.recover(42)
		restarted.recover(7)
		drain()
		t.equal(restarted.ready(42), true)
		t.equal(service.load(42).profile.tokens, 32)
		t.equal(service.load(42).profile.completedRuns, 1)
		t.equal(#service.pending(42).manifests, 0)
		flow.retry("one")
		drain()
		t.equal(flow.result("one", 42).status, "saved")
		t.equal(service.load(42).profile.tokens, 32)
	end,
	["REWARDFLOW load failure cannot overwrite prior progression"] = function(t)
		local flow, service, store, drain = setup()
		flow.finish(snapshot("one"))
		drain()
		local writes = store.writes
		store.failRead = true
		flow.recover(42)
		drain()
		t.equal(flow.profiles[42].status, "failed")
		t.equal(flow.ready(42), false)
		t.equal(store.writes, writes)
		store.failRead = false
		flow.recover(42)
		drain()
		t.equal(service.load(42).profile.tokens, 32)
	end,
	["REWARDFLOW load in flight and lost ack keep replay idempotent"] = function(t)
		local flow, service, store, drain = setup()
		flow.recover(42)
		t.equal(flow.recover(42), "busy")
		flow.finish(snapshot("one"))
		drain()
		t.equal(flow.durable("one"), true)
		flow.finish(snapshot("two"))
		store.loseAck = true
		drain()
		flow.retry("two")
		drain()
		t.equal(service.load(42).profile.tokens, 64)
		t.equal(service.load(42).profile.completedRuns, 2)
		t.equal(flow.result("one", 42), nil)
	end,
	["REWARDFLOW shutdown attempts retained manifests without resetting data"] = function(t)
		local flow, service, store, drain = setup()
		flow.recover(42)
		flow.recover(7)
		drain()
		store.failWrite = true
		flow.finish(snapshot("one"))
		drain()
		store.failWrite = false
		flow.shutdown()
		t.equal(flow.durable("one"), true)
		t.equal(service.load(42).profile.completedRuns, 1)
		flow.shutdown()
		t.equal(service.load(42).profile.completedRuns, 1)
	end,
}
