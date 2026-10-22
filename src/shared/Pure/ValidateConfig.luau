--!strict
local function validate(config: any)
	assert(
		type(config.rulesVersion) == "string" and config.rulesVersion ~= "",
		"Config.rulesVersion required"
	)
	for _, key in
		{
			"readySeconds",
			"shiftSeconds",
			"digSeconds",
			"siftSeconds",
			"dirtPerBatch",
			"bucketBatches",
			"outputCapacity",
		}
	do
		local value = config[key]
		assert(
			type(value) == "number" and value > 0 and value < math.huge,
			"Config." .. key .. " must be positive and finite"
		)
	end
	for _, key in { "dirtPerBatch", "bucketBatches", "outputCapacity" } do
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
