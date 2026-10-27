--!strict
-- Permanent player progression (T-039, docs/GATE_D_CONTRACT.md). Pure: the server
-- passes stored data in and writes the returned profile back through server/Progression.
-- Run Cash, temporary tool/machine tiers and carried inventory are never stored here.
local Profile = {}

-- Schema version of the stored table, not a gameplay value.
Profile.VERSION = 1

export type RecordCandidate = {
	score: number,
	crewSize: number,
	assisted: boolean,
	rulesVersion: string,
}
-- One per participant per run; grant identity is (runId, userId).
export type Manifest = {
	runId: string,
	userId: string,
	rulesVersion: string,
	crewSize: number,
	crewHaul: number,
	assisted: boolean,
	eligible: boolean,
	claimTokens: number,
	completionDelta: number,
	discoveries: { [string]: boolean },
	recordCandidate: RecordCandidate?,
}
export type Data = {
	version: number,
	userId: string,
	tokens: number,
	completedRuns: number,
	discoveries: { [string]: boolean },
	-- Best crew score per crew-size/assistance/rules-version bucket.
	records: { [string]: number },
	-- runId -> fingerprint of the applied manifest; never pruned (deduplication).
	applied: { [string]: string },
	pending: { [string]: Manifest },
}

local function count(value: any): boolean
	return type(value) == "number" and value >= 0 and value < math.huge and value % 1 == 0
end

local function text(value: any): boolean
	return type(value) == "string" and value ~= ""
end

local function set(value: any): boolean
	if type(value) ~= "table" then
		return false
	end
	for key, flag in value do
		if not text(key) or flag ~= true then
			return false
		end
	end
	return true
end

-- Returns why a manifest is malformed, or nil.
local function manifestProblem(m: any): string?
	if type(m) ~= "table" then
		return "manifest must be a table"
	elseif not text(m.runId) or not text(m.userId) or not text(m.rulesVersion) then
		return "runId, userId and rulesVersion must be nonempty strings"
	elseif not count(m.crewSize) or m.crewSize < 1 then
		return "crewSize must be a positive integer"
	elseif not count(m.crewHaul) or not count(m.claimTokens) then
		return "crewHaul and claimTokens must be whole nonnegative numbers"
	elseif type(m.assisted) ~= "boolean" or type(m.eligible) ~= "boolean" then
		return "assisted and eligible must be booleans"
	elseif m.completionDelta ~= 0 and m.completionDelta ~= 1 then
		return "completionDelta must be 0 or 1"
	elseif not set(m.discoveries) then
		return "discoveries must be a set of find IDs"
	elseif
		not m.eligible
		and (m.claimTokens ~= 0 or m.completionDelta ~= 0 or m.recordCandidate ~= nil)
	then
		return "ineligible manifests carry only discoveries"
	end
	local record = m.recordCandidate
	if record ~= nil then
		if
			type(record) ~= "table"
			or not count(record.score)
			or not count(record.crewSize)
			or type(record.assisted) ~= "boolean"
			or not text(record.rulesVersion)
		then
			return "recordCandidate must have score, crewSize, assisted and rulesVersion"
		elseif m.completionDelta ~= 1 then
			return "a record needs an eligible completion"
		end
	end
	return nil
end

function Profile.checkManifest(m: Manifest)
	local problem = manifestProblem(m)
	if problem then
		error("Profile: invalid manifest: " .. problem, 2)
	end
end

function Profile.new(userId: string): Data
	assert(text(userId), "Profile.new: userId must be a nonempty string")
	return {
		version = Profile.VERSION,
		userId = userId,
		tokens = 0,
		completedRuns = 0,
		discoveries = {},
		records = {},
		applied = {},
		pending = {},
	}
end

-- Validates a stored value. Failures are explicit; nothing is reset to a default.
function Profile.decode(userId: string, raw: any): (Data?, string?)
	if type(raw) ~= "table" then
		return nil, "invalid_profile"
	elseif raw.version ~= Profile.VERSION then
		return nil, "unsupported_version"
	elseif
		raw.userId ~= userId
		or not count(raw.tokens)
		or not count(raw.completedRuns)
		or not set(raw.discoveries)
		or type(raw.records) ~= "table"
		or type(raw.applied) ~= "table"
		or type(raw.pending) ~= "table"
	then
		return nil, "invalid_profile"
	end
	for bucket, score in raw.records do
		if not text(bucket) or not count(score) then
			return nil, "invalid_profile"
		end
	end
	for runId, fingerprint in raw.applied do
		if not text(runId) or not text(fingerprint) then
			return nil, "invalid_profile"
		end
	end
	for runId, m in raw.pending do
		if manifestProblem(m) or m.runId ~= runId or m.userId ~= userId then
			return nil, "invalid_profile"
		end
	end
	return raw, nil
end

local function sorted(map: { [string]: any }): { string }
	local keys = {}
	for key in map do
		table.insert(keys, key)
	end
	table.sort(keys)
	return keys
end

-- Canonical text of every manifest field, so equal payloads compare equal.
local function canonical(m: Manifest): string
	local record = m.recordCandidate
	return table.concat({
		m.runId,
		m.userId,
		m.rulesVersion,
		tostring(m.crewSize),
		tostring(m.crewHaul),
		tostring(m.assisted),
		tostring(m.eligible),
		tostring(m.claimTokens),
		tostring(m.completionDelta),
		table.concat(sorted(m.discoveries), ","),
		if record
			then table.concat({
				tostring(record.score),
				tostring(record.crewSize),
				tostring(record.assisted),
				record.rulesVersion,
			}, ",")
			else "",
	}, "|")
end

-- 32-bit FNV-1a of the canonical text: a short applied marker that still detects
-- a conflicting payload for an already applied run.
function Profile.fingerprint(m: Manifest): string
	local hash = 2166136261
	local source = canonical(m)
	for i = 1, #source do
		hash = bit32.bxor(hash, string.byte(source, i))
		-- hash * 16777619 (the FNV prime, 2^24 + 403) without losing precision.
		hash = (bit32.lshift(hash, 24) + hash * 403) % 4294967296
	end
	return string.format("%08x", hash)
end

local function clone(data: Data): Data
	local result = table.clone(data)
	result.discoveries = table.clone(data.discoveries)
	result.records = table.clone(data.records)
	result.applied = table.clone(data.applied)
	result.pending = table.clone(data.pending)
	return result
end

-- Adds a manifest to the recipient's pending list. Returns the same table when
-- nothing changes. "conflict" means the run already has a different payload.
function Profile.store(data: Data, m: Manifest): (Data, string)
	Profile.checkManifest(m)
	assert(m.userId == data.userId, "Profile.store: manifest belongs to another player")
	local fingerprint = Profile.fingerprint(m)
	local applied = data.applied[m.runId]
	if applied then
		return data, if applied == fingerprint then "alreadyApplied" else "conflict"
	end
	local pending = data.pending[m.runId]
	if pending then
		return data,
			if Profile.fingerprint(pending) == fingerprint then "alreadyPending" else "conflict"
	end
	local result = clone(data)
	result.pending[m.runId] = m
	return result, "pending"
end

function Profile.recordBucket(record: RecordCandidate): string
	return string.format(
		"%d|%s|%s",
		record.crewSize,
		if record.assisted then "assisted" else "unassisted",
		record.rulesVersion
	)
end

-- Applies one pending manifest and its deduplication marker together.
function Profile.apply(data: Data, runId: string): (Data, string)
	if data.applied[runId] then
		return data, "alreadyApplied"
	end
	local m = data.pending[runId]
	if not m then
		return data, "missing"
	end
	local result = clone(data)
	result.tokens += m.claimTokens
	result.completedRuns += m.completionDelta
	for find in m.discoveries do
		result.discoveries[find] = true
	end
	local record = m.recordCandidate
	if record then
		local bucket = Profile.recordBucket(record)
		local best = result.records[bucket]
		if best == nil or record.score > best then
			result.records[bucket] = record.score
		end
	end
	result.applied[runId] = Profile.fingerprint(m)
	result.pending[runId] = nil
	return result, "saved"
end

-- Pending manifests in runId order.
function Profile.pendingList(data: Data): { Manifest }
	local list = {}
	for _, runId in sorted(data.pending) do
		table.insert(list, data.pending[runId])
	end
	return list
end

return Profile
