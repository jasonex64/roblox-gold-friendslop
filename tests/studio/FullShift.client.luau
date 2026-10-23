--!strict
-- Run through Studio MCP in Client on a fresh test-only run. Uses real production
-- remotes, replicated state and wall-clock time; never seeds inventory or cash.
local player = game.Players.LocalPlayer
local storage = game.ReplicatedStorage
local config = require(storage.Shared.Config)
local status = storage.RunStatus
local action, sift = storage.ActionRequest, storage.SiftRequest
local runId = status:GetAttribute("RunId")
local autoHit = true
local connection = sift.OnClientEvent:Connect(function(_, view)
	if not autoHit or not view then
		return
	end
	local target = view.startedAt + (view.zoneStart + view.zoneWidth / 2) * view.duration
	task.delay(math.max(0, target - workspace:GetServerTimeNow()), function()
		if autoHit and player:GetAttribute("Sifting") then
			sift:FireServer("press", view.id, view.index)
		end
	end)
end)
local function waitFor(label, predicate, seconds)
	local deadline = os.clock() + seconds
	while not predicate() do
		assert(os.clock() < deadline, "FULL SHIFT timeout: " .. label)
		task.wait(0.05)
	end
end
local function stand(name)
	local pad = workspace.RiverCamp[name]
	player.Character:PivotTo(CFrame.new(pad.Position + Vector3.new(0, 4, 0)))
	task.wait(0.6)
end
local function digOne()
	stand("Bank")
	local before = player:GetAttribute("CarriedBatches")
	action:FireServer("dig")
	waitFor("dig", function()
		return player:GetAttribute("CarriedBatches") == before + 1
	end, 5)
end
local function siftOne()
	stand("River")
	local before = player:GetAttribute("CompletedFinds")
	action:FireServer("sift")
	waitFor("sift", function()
		return player:GetAttribute("CompletedFinds") == before + 1
	end, 10)
end
task.spawn(function()
	waitFor("run start", function()
		return status:GetAttribute("Phase") == "running"
	end, 15)
	assert(status:GetAttribute("EndsAt") - status:GetAttribute("StartedAt") == config.shiftSeconds)
	print("[T011 FULL] real shift started; duration=" .. config.shiftSeconds .. "; run=" .. runId)
	for _ = 1, config.openingBatches do
		digOne()
		siftOne()
	end
	assert(player:GetAttribute("RunCash") == 0 and player:GetAttribute("CrewHaul") == 0)
	stand("Buyer")
	action:FireServer("sell")
	waitFor("shop sale", function()
		return player:GetAttribute("CompletedFinds") == 0 and player:GetAttribute("RunCash") > 0
	end, 5)
	local sold = player:GetAttribute("CrewHaul")
	assert(player:GetAttribute("RunCash") == sold)
	stand("Camp")
	action:FireServer("buy")
	waitFor("upgrade", function()
		return player:GetAttribute("ShovelUpgraded")
	end, 5)
	assert(player:GetAttribute("RunCash") == sold - config.shovelUpgradePrice)
	assert(player:GetAttribute("CrewHaul") == sold)
	assert(player:GetAttribute("DigSeconds") == config.upgradedDigSeconds)
	digOne()
	siftOne()
	digOne()
	digOne()
	stand("River")
	print(
		"[T011 FULL] shop haul="
			.. sold
			.. "; wallet="
			.. player:GetAttribute("RunCash")
			.. "; upgrade verified; holding one unsold find and two raw batches"
	)
	waitFor("bell approach", function()
		return status:GetAttribute("RemainingSeconds") <= 3
	end, config.shiftSeconds)
	autoHit = false
	action:FireServer("sift")
	waitFor("pending cutoff sift", function()
		return player:GetAttribute("Sifting")
	end, 2)
	waitFor("real bell", function()
		return status:GetAttribute("Phase") == "results"
	end, 10)
	task.wait(0.3)
	assert(status:GetAttribute("ResultHaul") == sold)
	assert(player:GetAttribute("RunCash") == sold - config.shovelUpgradePrice)
	assert(player:GetAttribute("CrewHaul") == sold)
	assert(player:GetAttribute("CompletedFinds") == 0)
	assert(player:GetAttribute("CarriedBatches") == 0)
	assert(player:GetAttribute("ReservedOutput") == 0 and not player:GetAttribute("Sifting"))
	print(
		"[T011 FULL] real bell PASS: prior shop haul preserved; unsold completed/raw/processing discarded without payment"
	)
	_G.T011FullResult = {
		runId = runId,
		haul = sold,
		wallet = player:GetAttribute("RunCash"),
		result = "bell_pass",
	}
	connection:Disconnect()
end)
return "Full-duration production journey launched; results retained for UI/replay inspection"
