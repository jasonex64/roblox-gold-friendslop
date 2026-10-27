--!strict
-- Durable progression over an injected store (T-039, docs/GATE_D_CONTRACT.md).
--
-- Store boundary: `store.read(key) -> (ok, value | err)` and
-- `store.update(key, transform) -> (ok, value | err)`, with Roblox UpdateAsync
-- semantics: the transform gets the current stored value, may run more than once
-- when another server wrote in between, and returning nil cancels the write.
--
-- Every write is a transform of the current stored value, so a stale caller can
-- never write an old snapshot over newer progress. A manifest is stored inside its
-- recipient's own profile key in one write, so once `store` succeeds the manifest is
-- discoverable on the next load even if the process stops right after. `apply`
-- moves it into the profile together with its deduplication marker in one write.
--
-- Failures are explicit and nothing retries here (AGENTS.md). A failed request
-- may have committed if its acknowledgement was lost. Load pending/applied state
-- to reconcile; repeating store/apply is harmless. Never show failed as saved.
--
-- Schema 2 stores exact payloads, not 32-bit hashes. Schema 1 is rejected as
-- unsupported_version without writes/reset: its hashes cannot reconstruct the
-- original applied payloads. No automatic or lossy migration is safe. This
-- foundation has no live persistence rollout; preserve any old test data for
-- explicit recovery rather than accepting a legacy hash as proof of equality.
-- Marker growth is proportional to the full encoded manifest, including its
-- discovery IDs and record. The old ~80,000-run estimate no longer applies.
-- Markers are never pruned. Capacity/write failures remain explicit; a durable
-- archival design is required before deployment beyond the per-key size limit.
export type Outcome = {
	status: string,
	reason: string?,
	message: string?,
	profile: any,
	manifests: { any }?,
}

local Progression = {}

function Progression.new(store, Profile)
	local self = {}
	local function key(userId: number): string
		return "profile:" .. tostring(userId)
	end
	local function failed(reason: string, message: string?): Outcome
		return { status = "failed", reason = reason, message = message, profile = nil }
	end
	-- Runs step(profile) -> (newProfile, result) inside one store update. Returns the
	-- result of the transform run that the store committed (or cancelled).
	local function change(userId: number, create: boolean, step): (string, any)
		local result, profile = nil, nil
		local ok, err = store.update(key(userId), function(raw)
			local data, reason
			if raw == nil then
				if not create then
					result, profile = "missing_profile", nil
					return nil
				end
				data = Profile.new(userId)
			else
				data, reason = Profile.decode(userId, raw)
				if reason then
					result, profile = reason, nil
					return nil
				end
			end
			local nextData, outcome = step(data)
			result, profile = outcome, nextData
			-- Unchanged existing data needs no write.
			if nextData == data and raw ~= nil then
				return nil
			end
			return nextData
		end)
		if not ok then
			return "store_error", err
		end
		assert(result, "Progression: store reported success without running the transform")
		return result, profile
	end

	-- Loads a profile; a default is created only after a successful read finds none.
	function self.load(userId: number): Outcome
		local ok, raw = store.read(key(userId))
		if not ok then
			return failed("store_error", raw)
		end
		if raw ~= nil then
			local data, reason = Profile.decode(userId, raw)
			if reason then
				return failed(reason)
			end
			return { status = "loaded", profile = data }
		end
		local result, value = change(userId, true, function(data)
			return data, "loaded"
		end)
		if result ~= "loaded" then
			return failed(result, if result == "store_error" then value else nil)
		end
		return { status = "loaded", profile = value }
	end

	-- Durably stores a manifest for its recipient. "pending" only after the write is
	-- acknowledged; a conflicting payload for the same run is a bug and errors.
	function self.store(manifest): Outcome
		Profile.checkManifest(manifest)
		local result, value = change(manifest.userId, true, function(data)
			return Profile.store(data, manifest)
		end)
		if result == "conflict" then
			error(
				string.format(
					"Progression: conflicting manifest for run %s player %d",
					manifest.runId,
					manifest.userId
				)
			)
		elseif result == "pending" or result == "alreadyPending" then
			return { status = "pending", profile = value }
		elseif result == "alreadyApplied" then
			return { status = "alreadyApplied", profile = value }
		end
		return failed(result, if result == "store_error" then value else nil)
	end

	function self.pending(userId: number): Outcome
		local loaded = self.load(userId)
		if loaded.status ~= "loaded" then
			return loaded
		end
		return {
			status = "loaded",
			profile = loaded.profile,
			manifests = Profile.pendingList(loaded.profile),
		}
	end

	-- Applies a pending manifest. "saved" only after the write is acknowledged.
	function self.apply(userId: number, runId: string): Outcome
		local result, value = change(userId, false, function(data)
			return Profile.apply(data, runId)
		end)
		if result == "missing" then
			error(string.format("Progression: run %s is not pending for player %d", runId, userId))
		elseif result == "saved" or result == "alreadyApplied" then
			return { status = result, profile = value }
		end
		return failed(result, if result == "store_error" then value else nil)
	end

	return self
end

return Progression
