--!strict
return table.freeze({
	rulesVersion = "gate-a-provisional",
	readySeconds = 3, -- PROVISIONAL DESIGN §4
	shiftSeconds = 600, -- PROVISIONAL DESIGN §4
	digSeconds = 1, -- PROVISIONAL DESIGN §5
	siftSeconds = 6, -- D-015
	siftChecks = 3, -- D-015
	siftSweepSeconds = 2, -- D-015
	siftPerfectWidth = 0.05, -- D-016
	siftGoodWidth = 0.10, -- D-016
	siftUpgradeWidth = 0.25, -- D-015
	siftPerfectBonus = 0.20, -- D-015
	siftGoodBonus = 0.10, -- D-015
	siftMissPenalty = 0.20, -- D-015
	siftMinimumValue = 0.40, -- D-015
	dirtPerBatch = 5, -- PROVISIONAL DESIGN §5
	bucketBatches = 5, -- PROVISIONAL DESIGN §5
	outputCapacity = 20, -- PROVISIONAL DESIGN §5
	openingBatches = 5, -- PROVISIONAL DESIGN §5
	openingValue = 12, -- PROVISIONAL DESIGN §5
	ordinaryMultiplier = 1, -- PROVISIONAL DESIGN §8
	loot = {
		{
			kind = "Old Boot",
			weight = 20, -- PROVISIONAL DESIGN §8
			value = 3, -- PROVISIONAL DESIGN §8
		},
		{
			kind = "Tin Can",
			weight = 10, -- PROVISIONAL DESIGN §8
			value = 2, -- PROVISIONAL DESIGN §8
		},
		{
			kind = "Rusty Coin",
			weight = 10, -- PROVISIONAL DESIGN §8
			value = 8, -- PROVISIONAL DESIGN §8
		},
		{
			kind = "Small Fish",
			weight = 10, -- PROVISIONAL DESIGN §8
			value = 10, -- PROVISIONAL DESIGN §8
		},
		{
			kind = "Gold Flakes",
			weight = 30, -- PROVISIONAL DESIGN §8
			value = 12, -- PROVISIONAL DESIGN §8
		},
		{
			kind = "Gold Nugget",
			weight = 12, -- PROVISIONAL DESIGN §8
			value = 30, -- PROVISIONAL DESIGN §8
		},
		{
			kind = "Silver Ring",
			weight = 4, -- PROVISIONAL DESIGN §8
			value = 55, -- PROVISIONAL DESIGN §8
		},
		{
			kind = "Sapphire",
			weight = 2, -- PROVISIONAL DESIGN §8
			value = 120, -- PROVISIONAL DESIGN §8
		},
		{
			kind = "Ruby",
			weight = 1.5, -- PROVISIONAL DESIGN §8
			value = 220, -- PROVISIONAL DESIGN §8
		},
		{
			kind = "Mystery Crate",
			weight = 0.5, -- PROVISIONAL DESIGN §8
		},
	},
	crates = {
		{
			weight = 40, -- PROVISIONAL DESIGN §8
			value = 50, -- PROVISIONAL DESIGN §8
		},
		{
			weight = 40, -- PROVISIONAL DESIGN §8
			value = 150, -- PROVISIONAL DESIGN §8
		},
		{
			weight = 20, -- PROVISIONAL DESIGN §8
			value = 350, -- PROVISIONAL DESIGN §8
		},
	},
	starterTools = table.freeze({ "Shovel", "Pan", "Bucket" }),
})
