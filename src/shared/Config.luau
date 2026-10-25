--!strict
return table.freeze({
	rulesVersion = "gate-c-night-rush-prototype",
	nightStart = 300, -- D-037
	dawnStart = 480, -- D-037
	rushStart = 540, -- D-037
	rushSpeedup = 0.25, -- D-037
	richMultiplier = 1.5, -- D-037
	richBankDistance = 130, -- D-039
	rushSiftSweepSeconds = 1.6, -- D-040
	richSource = "RichBank",
	crewCapacity = 4, -- D-032
	binBatchesPerMember = 5, -- D-033
	sluicePricePerMember = 200, -- D-035
	sluiceLanesPerMember = 1, -- D-035
	sluiceProcessSeconds = 4, -- D-035
	sluiceOutputPerMember = 20, -- D-035
	sluiceDirtCapacity = 20, -- D-036
	afkSeconds = 60, -- D-032
	afkWarningSeconds = 10, -- D-032
	readySeconds = 3, -- D-024
	shiftSeconds = 600, -- D-024
	digSeconds = 1, -- D-024
	shovelUpgradePrice = 50, -- D-018
	upgradedDigSeconds = 0.8, -- D-018
	siftSeconds = 6, -- D-022
	siftChecks = 3, -- D-015
	siftSweepSeconds = 2, -- D-015
	siftPerfectWidth = 0.05, -- D-016
	siftGoodWidth = 0.10, -- D-016
	siftUpgradeWidth = 0.25, -- D-015
	siftPerfectBonus = 0.20, -- D-015
	siftGoodBonus = 0.10, -- D-015
	siftMissPenalty = 0.20, -- D-015
	siftMinimumValue = 0.40, -- D-015
	dirtPerBatch = 1, -- D-028
	bucketBatches = 5, -- D-024
	outputCapacity = 20, -- D-024
	openingBatches = 5, -- D-024
	openingValue = 12, -- D-024
	ordinaryMultiplier = 1, -- D-024
	loot = {
		{
			kind = "Old Boot",
			weight = 20, -- D-024
			value = 3, -- D-024
		},
		{
			kind = "Tin Can",
			weight = 10, -- D-024
			value = 2, -- D-024
		},
		{
			kind = "Rusty Coin",
			weight = 10, -- D-024
			value = 8, -- D-024
		},
		{
			kind = "Small Fish",
			weight = 10, -- D-024
			value = 10, -- D-024
		},
		{
			kind = "Gold Flakes",
			weight = 30, -- D-024
			value = 12, -- D-024
		},
		{
			kind = "Gold Nugget",
			weight = 12, -- D-024
			value = 30, -- D-024
		},
		{
			kind = "Silver Ring",
			weight = 4, -- D-024
			value = 55, -- D-024
		},
		{
			kind = "Sapphire",
			weight = 2, -- D-024
			value = 120, -- D-024
		},
		{
			kind = "Ruby",
			weight = 1.5, -- D-024
			value = 220, -- D-024
		},
		{
			kind = "Mystery Crate",
			weight = 0.5, -- D-024
		},
	},
	crates = {
		{
			weight = 40, -- D-024
			value = 50, -- D-024
		},
		{
			weight = 40, -- D-024
			value = 150, -- D-024
		},
		{
			weight = 20, -- D-024
			value = 350, -- D-024
		},
	},
	starterTools = table.freeze({ "Shovel", "Pan", "Bucket" }),
})
