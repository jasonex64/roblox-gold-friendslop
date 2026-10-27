--!strict
-- Fake-store tests: technical evidence for the storage rules, not live data stores.
local serde = require("@lune/serde")
local Profile = require("../../src/shared/Pure/Profile")
local Progression = require("../../src/server/Progression")
local RunRewards = require("../../src/shared/Pure/RunRewards")
local Config = require("../../src/shared/Config")

-- In-memory store with UpdateAsync semantics. Values round-trip through JSON like
-- data store values. `interleave` runs another writer between a transform's read
-- and its commit; the transform then reruns on the newer value, as UpdateAsync does.
local function fakeStore()
	local saved: { [string]: string } = {}
	local store: any =
		{ failRead = false, failUpdate = false, loseAck = false, interleave = nil, writes = 0 }
	local function copy(value: any): any
		return if value == nil then nil else serde.decode("json", serde.encode("json", value))
	end
	function store.read(key: string): (boolean, any)
		if store.failRead then
			return false, "read failed"
		end
		return true, if saved[key] then serde.decode("json", saved[key]) else nil
	end
	function store.update(key: string, transform): (boolean, any)
		if store.failUpdate then
			return false, "write failed"
		end
		while true do
			local before = saved[key]
			local result = transform(if before then serde.decode("json", before) else nil)
			local other = store.interleave
			if other then
				store.interleave = nil
				other()
			end
			if saved[key] == before then
				if result ~= nil then
					saved[key] = serde.encode("json", result)
					store.writes += 1
				end
				if store.loseAck then
					store.loseAck = false
					return false, "acknowledgement lost"
				end
				return true, copy(result)
			end
		end
	end
	function store.raw(key: string): any
		return if saved[key] then serde.decode("json", saved[key]) else nil
	end
	function store.put(key: string, value: any)
		saved[key] = serde.encode("json", value)
	end
	return store
end

local function manifest(runId: string, overrides: { [string]: any }?): any
	local m: { [string]: any } = {
		runId = runId,
		userId = 42,
		rulesVersion = "gate-c",
		crewSize = 1,
		crewHaul = 600,
		assisted = false,
		eligible = true,
		claimTokens = 21,
		completionDelta = 1,
		discoveries = { ["Gold Flakes"] = true },
		recordCandidate = {
			crewHaul = 600,
			crewSize = 1,
			assisted = false,
			rulesVersion = "gate-c",
		},
	}
	for key, value in overrides or {} do
		m[key] = value
	end
	return m
end

return {

	["PROGRESSION exact manifest conflicts survive JSON restart and apply"] = function(t)
		local function reward(haul)
			return RunRewards.build({
				runId = "run-review",
				rulesVersion = "gate-c",
				crewSize = 1,
				crewHaul = haul,
				assisted = false,
				participants = {
					[42] = { activeSeconds = 480, discoveries = { ["Gold Flakes"] = true } },
				},
			}, Config)[42]
		end
		local store = fakeStore()
		local service = Progression.new(store, Profile)
		t.equal(service.store(reward(17950)).status, "pending")
		service = Progression.new(store, Profile)
		t.errors(function()
			service.store(reward(61116))
		end)
		t.equal(service.store(reward(17950)).status, "pending")
		t.equal(service.apply(42, "run-review").status, "saved")
		service = Progression.new(store, Profile)
		t.errors(function()
			service.store(reward(61116))
		end)
		t.equal(service.store(reward(17950)).status, "alreadyApplied")
		t.equal(service.apply(42, "run-review").status, "alreadyApplied")
		local saved = service.load(42).profile
		t.equal(saved.tokens, 40)
		t.equal(saved.completedRuns, 1)
		t.equal(saved.records["1|unassisted|gate-c"], 17950)
	end,
	["PROGRESSION legacy profiles are preserved on load store and apply"] = function(t)
		local store = fakeStore()
		local old = Profile.new(42)
		old.version, old.tokens = 1, 123
		old.applied["run-1"] = "6c42859e"
		store.put("profile:42", old)
		local service = Progression.new(store, Profile)
		t.equal(service.load(42).reason, "unsupported_version")
		t.equal(service.store(manifest("run-1")).reason, "unsupported_version")
		t.equal(service.apply(42, "run-1").reason, "unsupported_version")
		t.equal(store.writes, 0)
		t.equal(store.raw("profile:42").tokens, 123)
		t.equal(store.raw("profile:42").applied["run-1"], "6c42859e")
	end,
	["PROGRESSION failed loads never become a default profile"] = function(t)
		local store = fakeStore()
		local service = Progression.new(store, Profile)
		store.failRead = true
		local failed = service.load(42)
		t.equal(failed.status, "failed")
		t.equal(failed.reason, "store_error")
		t.equal(failed.profile, nil)
		t.equal(store.raw("profile:42"), nil)
		store.failRead = false
		store.put("profile:42", { version = Profile.VERSION + 1, userId = 42 })
		t.equal(service.load(42).reason, "unsupported_version")
		store.put("profile:42", "corrupt")
		t.equal(service.load(42).reason, "invalid_profile")
		t.equal(store.raw("profile:42"), "corrupt")
		t.equal(service.store(manifest("run-1")).reason, "invalid_profile")
		t.equal(store.raw("profile:42"), "corrupt")
		t.equal(store.writes, 0)
	end,
	["PROGRESSION a missing profile is created only after a successful read"] = function(t)
		local store = fakeStore()
		local service = Progression.new(store, Profile)
		store.failUpdate = true
		t.equal(service.load(42).reason, "store_error")
		t.equal(store.raw("profile:42"), nil)
		store.failUpdate = false
		local loaded = service.load(42)
		t.equal(loaded.status, "loaded")
		t.equal(loaded.profile.tokens, 0)
		t.equal(store.writes, 1)
		t.equal(service.load(42).status, "loaded")
		t.equal(store.writes, 1)
	end,
	["PROGRESSION interruption at each settlement step recovers without double grants"] = function(
		t
	)
		local store = fakeStore()
		local service = Progression.new(store, Profile)
		t.equal(service.load(42).status, "loaded")
		-- 1. The manifest write fails: nothing is pending and nothing may be shown as saved.
		store.failUpdate = true
		t.equal(service.store(manifest("run-1")).status, "failed")
		store.failUpdate = false
		t.equal(#service.pending(42).manifests, 0)
		-- 2. The manifest write lands but its acknowledgement is lost; storing again is harmless.
		store.loseAck = true
		t.equal(service.store(manifest("run-1")).status, "failed")
		t.equal(#service.pending(42).manifests, 1)
		t.equal(service.store(manifest("run-1")).status, "pending")
		-- 3. The process stops after storing: a new service finds the manifest pending.
		local restarted = Progression.new(store, Profile)
		local pending = restarted.pending(42)
		t.equal(#pending.manifests, 1)
		t.equal(pending.manifests[1].runId, "run-1")
		-- 4. The apply write fails: the manifest stays pending and tokens are unchanged.
		store.failUpdate = true
		t.equal(restarted.apply(42, "run-1").status, "failed")
		store.failUpdate = false
		t.equal(restarted.load(42).profile.tokens, 0)
		-- 5. The apply lands but its acknowledgement is lost; applying again grants nothing.
		store.loseAck = true
		t.equal(restarted.apply(42, "run-1").status, "failed")
		local again = restarted.apply(42, "run-1")
		t.equal(again.status, "alreadyApplied")
		t.equal(again.profile.tokens, 21)
		t.equal(again.profile.completedRuns, 1)
		t.equal(#restarted.pending(42).manifests, 0)
		t.equal(restarted.store(manifest("run-1")).status, "alreadyApplied")
	end,
	["PROGRESSION saved is reported only after the write is acknowledged"] = function(t)
		local store = fakeStore()
		local service = Progression.new(store, Profile)
		t.equal(service.store(manifest("run-1")).status, "pending")
		local saved = service.apply(42, "run-1")
		t.equal(saved.status, "saved")
		t.equal(saved.profile.tokens, 21)
		t.equal(store.raw("profile:42").tokens, 21)
		t.equal(store.raw("profile:42").applied["run-1"], Profile.fingerprint(manifest("run-1")))
	end,
	["PROGRESSION conflicting duplicates fail loudly; unknown runs error"] = function(t)
		local store = fakeStore()
		local service = Progression.new(store, Profile)
		service.store(manifest("run-1"))
		t.errors(function()
			service.store(manifest("run-1", { claimTokens = 22 }))
		end)
		service.apply(42, "run-1")
		t.errors(function()
			service.store(manifest("run-1", { crewHaul = 601 }))
		end)
		t.errors(function()
			service.apply(42, "run-9")
		end)
		t.errors(function()
			service.store(manifest("run-2", { claimTokens = -1 }))
		end)
		t.equal(service.load(42).profile.tokens, 21)
	end,
	["PROGRESSION stores and applies RunRewards manifests unchanged (T-038 contract)"] = function(
		t
	)
		local store = fakeStore()
		local service = Progression.new(store, Profile)
		local manifests = RunRewards.build({
			runId = "run-7",
			rulesVersion = Config.rulesVersion,
			crewSize = 2,
			crewHaul = 12000,
			assisted = false,
			participants = {
				[42] = { activeSeconds = Config.shiftSeconds, discoveries = { ["Tin Can"] = true } },
				[7] = { activeSeconds = 10, discoveries = { ["Old Boot"] = true } },
			},
		}, Config)
		for _, m in manifests do
			t.equal(service.store(m).status, "pending")
			t.equal(service.apply(m.userId, m.runId).status, "saved")
			t.equal(service.store(m).status, "alreadyApplied")
		end
		local full = service.load(42).profile
		t.equal(full.tokens, manifests[42].claimTokens)
		t.equal(full.completedRuns, 1)
		t.equal(full.records["2|unassisted|" .. Config.rulesVersion], 12000)
		local short = service.load(7).profile
		t.equal(short.tokens, 0)
		t.equal(short.completedRuns, 0)
		t.equal(short.discoveries["Old Boot"], true)
		t.equal(next(short.records), nil)
	end,
	["PROGRESSION concurrent writers cannot overwrite newer progress"] = function(t)
		local store = fakeStore()
		local serverA = Progression.new(store, Profile)
		local serverB = Progression.new(store, Profile)
		serverA.store(manifest("run-1"))
		serverA.store(manifest("run-2", { claimTokens = 30, crewHaul = 4000 }))
		-- Server B applies run-2 while server A's apply of run-1 is between read and commit.
		store.interleave = function()
			t.equal(serverB.apply(42, "run-2").status, "saved")
		end
		t.equal(serverA.apply(42, "run-1").status, "saved")
		local profile = serverA.load(42).profile
		t.equal(profile.tokens, 51)
		t.equal(profile.completedRuns, 2)
		t.equal(#Profile.pendingList(profile), 0)
		-- A stale caller applying an already-applied run cannot roll anything back.
		t.equal(serverB.apply(42, "run-1").status, "alreadyApplied")
		t.equal(serverB.load(42).profile.tokens, 51)
	end,
}
