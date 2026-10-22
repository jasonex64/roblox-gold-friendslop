--!strict
return table.freeze({
	rulesVersion = "gate-a-provisional",
	readySeconds = 3, -- PROVISIONAL DESIGN §4
	shiftSeconds = 600, -- PROVISIONAL DESIGN §4
	digSeconds = 1, -- PROVISIONAL DESIGN §5
	siftSeconds = 4, -- PROVISIONAL DESIGN §5
	dirtPerBatch = 5, -- PROVISIONAL DESIGN §5
	bucketBatches = 5, -- PROVISIONAL DESIGN §5
	outputCapacity = 20, -- PROVISIONAL DESIGN §5
	starterTools = table.freeze({ "Shovel", "Pan", "Bucket" }),
})
