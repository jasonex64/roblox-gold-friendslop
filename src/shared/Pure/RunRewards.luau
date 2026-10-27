--!strict
-- Detached manifests only; storage and live wiring are separate.
local RunRewards = {}
local MAX_INTEGER = 2 ^ 53 - 1 -- IEEE-754 limit, not gameplay tuning.
local function integer(value: any, name: string, minimum: number)
	assert(
		type(value) == "number" and value >= minimum and value <= MAX_INTEGER and value % 1 == 0,
		name .. " must be a safe integer >= " .. tostring(minimum)
	)
end
local function nonempty(value: any, name: string)
	assert(type(value) == "string" and string.find(value, "%S") ~= nil, name .. " must be nonempty")
end
function RunRewards.build(snapshot: any, config: any): { [number]: any }
	assert(type(config) == "table", "Config required")
	for _, key in
		{ "rewardBaseTokens", "rewardBonusCap", "rewardHaulPerTokenPerMember", "crewCapacity" }
	do
		integer(config[key], "Config." .. key, 1)
	end
	assert(
		config.rewardBaseTokens <= MAX_INTEGER - config.rewardBonusCap,
		"Config.reward token sum unsafe"
	)
	assert(
		config.rewardHaulPerTokenPerMember <= MAX_INTEGER / config.crewCapacity,
		"Config.reward divisor unsafe"
	)
	for _, key in { "rewardActiveSeconds", "shiftSeconds" } do
		assert(
			type(config[key]) == "number" and config[key] > 0 and config[key] < math.huge,
			"Config." .. key .. " must be positive and finite"
		)
	end
	assert(
		config.rewardActiveSeconds <= config.shiftSeconds,
		"Config.rewardActiveSeconds exceeds shift"
	)
	assert(type(config.loot) == "table" and #config.loot > 0, "Config.loot required")
	local knownFinds = {}
	for _, entry in config.loot do
		assert(type(entry) == "table", "Config.loot entry required")
		nonempty(entry.kind, "Config.loot.kind")
		assert(not knownFinds[entry.kind], "Config.loot duplicate kind")
		knownFinds[entry.kind] = true
	end
	assert(type(snapshot) == "table", "snapshot required")
	nonempty(snapshot.runId, "runId")
	nonempty(snapshot.rulesVersion, "rulesVersion")
	integer(snapshot.crewSize, "crewSize", 1)
	assert(snapshot.crewSize <= config.crewCapacity, "crewSize exceeds capacity")
	integer(snapshot.crewHaul, "crewHaul", 0)
	assert(type(snapshot.assisted) == "boolean", "assisted must be boolean")
	assert(type(snapshot.participants) == "table", "participants required")
	local manifests = {}
	local count = 0
	for userId, participant in snapshot.participants do
		integer(userId, "userId", 1)
		assert(type(participant) == "table", "participant required")
		local active = participant.activeSeconds
		assert(
			type(active) == "number" and active >= 0 and active <= config.shiftSeconds,
			"activeSeconds must be finite and within shift"
		)
		assert(type(participant.discoveries) == "table", "discoveries must be a set")
		local discoveries = {}
		for kind, present in participant.discoveries do
			assert(
				type(kind) == "string" and knownFinds[kind] == true and present == true,
				"discoveries must contain known find IDs with true values"
			)
			discoveries[kind] = true
		end
		local eligible = active >= config.rewardActiveSeconds
		local tokens = 0
		local record = nil
		if eligible then
			tokens = config.rewardBaseTokens
				+ math.min(
					config.rewardBonusCap,
					math.floor(
						snapshot.crewHaul / (config.rewardHaulPerTokenPerMember * snapshot.crewSize)
					)
				)
			record = {
				crewHaul = snapshot.crewHaul,
				crewSize = snapshot.crewSize,
				assisted = snapshot.assisted,
				rulesVersion = snapshot.rulesVersion,
			}
		end
		manifests[userId] = {
			runId = snapshot.runId,
			userId = userId,
			rulesVersion = snapshot.rulesVersion,
			crewSize = snapshot.crewSize,
			crewHaul = snapshot.crewHaul,
			assisted = snapshot.assisted,
			eligible = eligible,
			claimTokens = tokens,
			completionDelta = if eligible then 1 else 0,
			discoveries = discoveries,
			recordCandidate = record,
		}
		count += 1
	end
	assert(count == snapshot.crewSize, "participants must include every admitted crew member")
	return manifests
end
return RunRewards
