--!strict
local function validate(config: any)
	assert(
		type(config.rulesVersion) == "string" and config.rulesVersion ~= "",
		"Config.rulesVersion required"
	)
	for _, key in
		{
			"crewCapacity",
			"binBatchesPerMember",
			"sluicePricePerMember",
			"sluiceLanesPerMember",
			"sluiceProcessSeconds",
			"sluiceOutputPerMember",
			"afkSeconds",
			"afkWarningSeconds",
			"readySeconds",
			"shiftSeconds",
			"digSeconds",
			"shovelUpgradePrice",
			"upgradedDigSeconds",
			"siftSeconds",
			"siftChecks",
			"siftSweepSeconds",
			"siftPerfectWidth",
			"siftGoodWidth",
			"siftUpgradeWidth",
			"siftPerfectBonus",
			"siftGoodBonus",
			"siftMissPenalty",
			"siftMinimumValue",
			"dirtPerBatch",
			"bucketBatches",
			"outputCapacity",
			"openingBatches",
			"openingValue",
			"ordinaryMultiplier",
		}
	do
		local value = config[key]
		assert(
			type(value) == "number" and value > 0 and value < math.huge,
			"Config." .. key .. " must be positive and finite"
		)
	end
	for _, key in { "loot", "crates" } do
		assert(type(config[key]) == "table" and #config[key] > 0, "Config." .. key .. " required")
		for _, entry in config[key] do
			assert(
				type(entry.weight) == "number" and entry.weight > 0 and entry.weight < math.huge,
				"Config." .. key .. ".weight invalid"
			)
			if key == "loot" then
				assert(
					type(entry.kind) == "string" and entry.kind ~= "",
					"Config.loot.kind required"
				)
			end
			if entry.kind ~= "Mystery Crate" then
				assert(
					type(entry.value) == "number" and entry.value >= 0 and entry.value < math.huge,
					"Config." .. key .. ".value invalid"
				)
			end
		end
	end
	assert(
		config.siftPerfectWidth + 2 * config.siftGoodWidth <= 1,
		"Config.sift zones must fit sweep"
	)
	assert(config.siftMinimumValue <= 1, "Config.siftMinimumValue must not exceed base value")
	assert(
		config.siftSeconds == config.siftChecks * config.siftSweepSeconds,
		"Config.siftSeconds must match checks"
	)
	for _, key in
		{
			"crewCapacity",
			"binBatchesPerMember",
			"sluicePricePerMember",
			"sluiceLanesPerMember",
			"sluiceOutputPerMember",
			"dirtPerBatch",
			"bucketBatches",
			"outputCapacity",
			"siftChecks",
			"shovelUpgradePrice",
		}
	do
		assert(config[key] % 1 == 0, "Config." .. key .. " must be an integer")
	end
	assert(
		type(config.starterTools) == "table" and #config.starterTools > 0,
		"Config.starterTools required"
	)
	local seen = {}
	for _, name in config.starterTools do
		assert(
			type(name) == "string" and name ~= "" and not seen[name],
			"Config.starterTools invalid or duplicate name"
		)
		seen[name] = true
	end
end
return validate
