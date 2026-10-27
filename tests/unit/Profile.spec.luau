--!strict
local Profile = require("../../src/shared/Pure/Profile")

local function manifest(overrides: { [string]: any }?): any
	local m: { [string]: any } = {
		runId = "run-1",
		userId = 42,
		rulesVersion = "gate-c",
		crewSize = 2,
		crewHaul = 3000,
		assisted = false,
		eligible = true,
		claimTokens = 23,
		completionDelta = 1,
		discoveries = { ["Gold Flakes"] = true },
		recordCandidate = {
			crewHaul = 3000,
			crewSize = 2,
			assisted = false,
			rulesVersion = "gate-c",
		},
	}
	for key, value in overrides or {} do
		m[key] = value
	end
	-- A nil inside an override table is just absent, so removal is a flag.
	if m.noRecord then
		m.noRecord, m.recordCandidate = nil, nil
	end
	return m
end

return {
	["PROFILE new profiles start empty at the current version"] = function(t)
		local data = Profile.new(42)
		t.equal(data.version, Profile.VERSION)
		t.equal(data.tokens, 0)
		t.equal(data.completedRuns, 0)
		t.equal(next(data.applied), nil)
		t.equal(next(data.pending), nil)
		t.errors(function()
			Profile.new(0)
		end)
	end,
	["PROFILE decode rejects wrong versions, owners and shapes without resetting"] = function(t)
		local good = Profile.new(42)
		local decoded, reason = Profile.decode(42, good)
		t.equal(decoded, good)
		t.equal(reason, nil)
		local future = table.clone(good)
		future.version = Profile.VERSION + 1
		t.equal(select(2, Profile.decode(42, future)), "unsupported_version")
		t.equal(select(2, Profile.decode(7, good)), "invalid_profile")
		t.equal(select(2, Profile.decode(42, "corrupt")), "invalid_profile")
		local negative = table.clone(good)
		negative.tokens = -1
		t.equal(select(2, Profile.decode(42, negative)), "invalid_profile")
		local badPending = table.clone(good)
		badPending.pending = { ["run-1"] = manifest({ claimTokens = 1.5 }) }
		t.equal(select(2, Profile.decode(42, badPending)), "invalid_profile")
		t.equal(future.version, Profile.VERSION + 1)
	end,
	["PROFILE invalid manifests error by name"] = function(t)
		Profile.checkManifest(manifest())
		for _, bad in
			{
				{ runId = "" },
				{ crewSize = 0 },
				{ claimTokens = -1 },
				{ completionDelta = 2 },
				{ discoveries = { "Gold Flakes" } },
				{ eligible = false },
				{ completionDelta = 0 },
			}
		do
			t.errors(function()
				Profile.checkManifest(manifest(bad))
			end)
		end
		Profile.checkManifest(manifest({
			eligible = false,
			claimTokens = 0,
			completionDelta = 0,
			noRecord = true,
		}))
	end,
	["PROFILE store then apply grants once and keeps the marker"] = function(t)
		local m = manifest()
		local empty = Profile.new(42)
		local pending, stored = Profile.store(empty, m)
		t.equal(stored, "pending")
		t.equal(empty.pending["run-1"], nil)
		local again, repeated = Profile.store(pending, manifest())
		t.equal(repeated, "alreadyPending")
		t.equal(again, pending)
		local saved, applied = Profile.apply(pending, "run-1")
		t.equal(applied, "saved")
		t.equal(saved.tokens, 23)
		t.equal(saved.completedRuns, 1)
		t.equal(saved.discoveries["Gold Flakes"], true)
		t.equal(saved.records["2|unassisted|gate-c"], 3000)
		t.equal(saved.pending["run-1"], nil)
		t.equal(saved.applied["run-1"], Profile.fingerprint(m))
		t.equal(pending.tokens, 0)
		local twice, second = Profile.apply(saved, "run-1")
		t.equal(second, "alreadyApplied")
		t.equal(twice, saved)
		local restored, afterApply = Profile.store(saved, manifest())
		t.equal(afterApply, "alreadyApplied")
		t.equal(restored, saved)
		t.equal(select(2, Profile.apply(saved, "run-2")), "missing")
	end,
	["PROFILE conflicting duplicate payloads are detected before and after apply"] = function(t)
		local pending = Profile.store(Profile.new(42), manifest())
		t.equal(select(2, Profile.store(pending, manifest({ claimTokens = 24 }))), "conflict")
		local saved = Profile.apply(pending, "run-1")
		t.equal(select(2, Profile.store(saved, manifest({ crewHaul = 3001 }))), "conflict")
		local reordered = manifest({ discoveries = { ["Garnet"] = true, ["Gold Flakes"] = true } })
		local other = manifest({ discoveries = { ["Gold Flakes"] = true, ["Garnet"] = true } })
		t.equal(Profile.fingerprint(reordered), Profile.fingerprint(other))
		t.errors(function()
			Profile.store(Profile.new(7), manifest())
		end)
	end,
	["PROFILE ineligible runs commit discoveries only; records keep the best per bucket"] = function(
		t
	)
		local data = Profile.new(42)
		data = Profile.apply(
			Profile.store(
				data,
				manifest({
					runId = "short",
					eligible = false,
					claimTokens = 0,
					completionDelta = 0,
					noRecord = true,
					discoveries = { Garnet = true },
				})
			),
			"short"
		)
		t.equal(data.tokens, 0)
		t.equal(data.completedRuns, 0)
		t.equal(data.discoveries.Garnet, true)
		t.equal(next(data.records), nil)
		data = Profile.apply(Profile.store(data, manifest({ runId = "a" })), "a")
		data = Profile.apply(
			Profile.store(
				data,
				manifest({
					runId = "b",
					crewHaul = 1000,
					claimTokens = 21,
					recordCandidate = {
						crewHaul = 1000,
						crewSize = 2,
						assisted = false,
						rulesVersion = "gate-c",
					},
				})
			),
			"b"
		)
		data = Profile.apply(
			Profile.store(
				data,
				manifest({
					runId = "c",
					assisted = true,
					recordCandidate = {
						crewHaul = 500,
						crewSize = 2,
						assisted = true,
						rulesVersion = "gate-c",
					},
				})
			),
			"c"
		)
		t.equal(data.records["2|unassisted|gate-c"], 3000)
		t.equal(data.records["2|assisted|gate-c"], 500)
		t.equal(data.tokens, 23 + 21 + 23)
		t.equal(data.completedRuns, 3)
		t.equal(#Profile.pendingList(data), 0)
	end,
}
