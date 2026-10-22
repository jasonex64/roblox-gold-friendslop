--!strict
local Loot = {}

local function choose(entries, rng)
	local total = 0
	for _, entry in entries do
		assert(entry.weight > 0 and entry.weight < math.huge, "Loot: invalid weight")
		total += entry.weight
	end
	assert(total > 0 and total < math.huge, "Loot: invalid total weight")
	local draw = rng()
	assert(draw >= 0 and draw < 1, "Loot: rng must be in [0, 1)")
	local threshold = draw * total
	local cumulative = 0
	for _, entry in entries do
		cumulative += entry.weight
		if threshold < cumulative then
			return entry
		end
	end
	error("Loot: selection failed")
end

function Loot.draw(config, openingCount: number, rng)
	if openingCount < config.openingBatches then
		return {
			kind = "Gold Flakes",
			baseValue = config.openingValue,
			sourceMultiplier = config.ordinaryMultiplier,
		}
	end
	local selected = choose(config.loot, rng)
	if selected.kind == "Mystery Crate" then
		local cache = choose(config.crates, rng)
		return {
			kind = selected.kind,
			baseValue = cache.value,
			sourceMultiplier = config.ordinaryMultiplier,
			crateKind = "Gold Cache",
			crateValue = cache.value,
		}
	end
	return {
		kind = selected.kind,
		baseValue = selected.value,
		sourceMultiplier = config.ordinaryMultiplier,
	}
end

return Loot
