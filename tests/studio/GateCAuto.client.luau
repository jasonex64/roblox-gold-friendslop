--!strict
-- EXP-003 automated evidence only. Real clock, loot, earnings and remotes;
-- scripted station teleports and ideal timing inputs are not human play.
local p, rs = game.Players.LocalPlayer, game.ReplicatedStorage
local cfg, status = require(rs.Shared.Config), rs.RunStatus
local camp = workspace.RiverCamp
local report = { state = "running", events = {}, coverage = {}, sales = 0 }
_G.GateCAuto = report
local function elapsed()
	local start = status:GetAttribute("StartedAt")
	return if start then math.floor(workspace:GetServerTimeNow() - start) else 0
end
local function event(message)
	local line = string.format("[GATE C auto] %ds: %s", elapsed(), message)
	table.insert(report.events, line)
	print(line)
end
local function waitFor(predicate, seconds, label)
	local deadline = os.clock() + seconds
	while not predicate() do
		assert(os.clock() < deadline, "GATE C timed out: " .. label)
		task.wait(0.05)
	end
end
local function stand(pad)
	p.Character:PivotTo(CFrame.new(pad.Position + Vector3.new(0, 4, 0)))
	task.wait(0.5)
end
local function guid()
	return game.HttpService:GenerateGUID(false)
end
local scheduled = {}
local connection = rs.SiftRequest.OnClientEvent:Connect(function(_, view)
	if view and not view.graded then
		local key = view.id .. ":" .. view.index
		if not scheduled[key] then
			scheduled[key] = true
			local delay = view.startedAt
				+ (view.zoneStart + view.zoneWidth / 2) * view.duration
				- workspace:GetServerTimeNow()
			task.delay(math.max(0, delay), function()
				rs.SiftRequest:FireServer("press", view.id, view.index)
			end)
		end
	end
end)
local phases = status:GetAttributeChangedSignal("ShiftPhase"):Connect(function()
	local phase = status:GetAttribute("ShiftPhase")
	report.coverage[phase] = true
	event("phase " .. phase)
end)
local function digOne()
	local before = p:GetAttribute("CarriedBatches")
	rs.ActionRequest:FireServer("dig")
	waitFor(function()
		return p:GetAttribute("CarriedBatches") == before + 1
	end, cfg.digSeconds + 3, "dig")
end
local function siftAll()
	stand(camp.River)
	while p:GetAttribute("CarriedBatches") > 0 do
		local before = p:GetAttribute("CompletedFinds")
		rs.ActionRequest:FireServer("sift")
		waitFor(function()
			return p:GetAttribute("CompletedFinds") == before + 1
		end, cfg.siftSeconds + 3, "sift")
	end
end
local function sell()
	if p:GetAttribute("CompletedFinds") == 0 then
		return
	end
	stand(camp.Buyer)
	local beforeCash, beforeHaul = p:GetAttribute("RunCash"), p:GetAttribute("CrewHaul")
	rs.EconomyRequest:FireServer("sell", guid())
	waitFor(function()
		return p:GetAttribute("CompletedFinds") == 0
	end, 3, "sale")
	assert(
		p:GetAttribute("RunCash") - beforeCash == p:GetAttribute("CrewHaul") - beforeHaul,
		"Solo payout mismatch"
	)
	report.sales += 1
	if report.sales == 1 then
		event("first earned sale; wallet/haul delta matches")
	end
end
local purchases = {
	{ "shovel-2", cfg.shovelUpgradePrice, "ShovelUpgraded" },
	{ "pan-2", cfg.panTierTwoPrice, "PanUpgraded" },
	{ "shovel-3", cfg.shovelTierThreePrice, "ShovelTierThree" },
	{ "pan-3", cfg.panTierThreePrice, "PanTierThree" },
}
local function spend()
	for _, item in purchases do
		if not p:GetAttribute(item[3]) and p:GetAttribute("RunCash") >= item[2] then
			stand(camp.Camp)
			local cash, haul = p:GetAttribute("RunCash"), p:GetAttribute("CrewHaul")
			rs.EconomyRequest:FireServer("buy", guid(), item[1])
			waitFor(function()
				return p:GetAttribute(item[3])
			end, 3, item[1])
			assert(
				p:GetAttribute("RunCash") == cash - item[2] and p:GetAttribute("CrewHaul") == haul,
				"Tool charge mismatch"
			)
			report.coverage[item[1]] = true
			event("bought " .. item[1] .. "; haul unchanged")
		end
	end
	for _, item in
		{
			{ "contribute", "SluiceBuilt", "SluicePrice" },
			{ "hopper", "SluiceHopper", "SluiceHopperPrice" },
			{ "upgrade", "SluiceTierTwo", "SluiceTierTwoPrice" },
		}
	do
		local price = status:GetAttribute(item[3])
		if not status:GetAttribute(item[2]) and p:GetAttribute("RunCash") >= price then
			stand(camp.Sluice)
			local cash, haul = p:GetAttribute("RunCash"), p:GetAttribute("CrewHaul")
			rs.MachineRequest:FireServer(item[1], status:GetAttribute("RunId"), guid(), price)
			waitFor(function()
				return status:GetAttribute(item[2])
			end, 3, item[1])
			assert(
				p:GetAttribute("RunCash") == cash - price and p:GetAttribute("CrewHaul") == haul,
				"Machine charge mismatch"
			)
			report.coverage[item[2]] = true
			event("funded " .. item[2] .. "; haul unchanged")
		end
		if not status:GetAttribute("SluiceBuilt") then
			break
		end
	end
end
local ok, failure = xpcall(function()
	waitFor(function()
		return status:GetAttribute("Phase") == "running"
	end, 15, "shift start")
	assert(p:GetAttribute("CrewMember") and status:GetAttribute("CrewCount") == 1, "Not solo")
	assert(p:GetAttribute("RunCash") == 0, "Needs fresh run")
	p.PlayerGui.GoldHUD.Root.Guide.Visible = false
	event("fresh solo; scripted travel/timing, real earnings and natural clock")
	while status:GetAttribute("RemainingSeconds") > 35 do
		local night = status:GetAttribute("ShiftPhase") == "night"
		stand(if night then camp.RichBank else camp.Bank)
		for _ = 1, cfg.bucketBatches do
			-- Avoid beginning new rich digs across dawn.
			if night and status:GetAttribute("ShiftPhase") ~= "night" then
				stand(camp.Bank)
				night = false
			end
			digOne()
		end
		if night and not report.coverage.rich then
			report.coverage.rich = true
			event("dug rich-bank dirt during night")
		end
		local useHopper = status:GetAttribute("SluiceHopper") and report.coverage.rich
		if useHopper then
			stand(camp.DirtBin)
			rs.BinRequest:FireServer(
				"deposit",
				status:GetAttribute("RunId"),
				status:GetAttribute("BinRevision"),
				"all"
			)
			waitFor(function()
				return p:GetAttribute("CarriedBatches") == 0
			end, 3, "bin deposit")
			waitFor(function()
				return status:GetAttribute("BinCount") == 0
					and status:GetAttribute("SluiceDirt") == 0
			end, cfg.bucketBatches * cfg.sluiceProcessSeconds + 5, "hopper drain")
			stand(camp.Sluice)
			rs.MachineRequest:FireServer("transfer", status:GetAttribute("RunId"), guid())
			waitFor(function()
				return p:GetAttribute("CompletedFinds") > 0
			end, 3, "machine collection")
			if not report.coverage.hopperFed then
				report.coverage.hopperFed = true
				event("hopper fed bin, processed and collected earned dirt")
			end
		else
			siftAll()
		end
		sell()
		spend()
	end
	-- Keep one earned unsold find to verify the natural bell does not pay it.
	stand(camp.Bank)
	digOne()
	siftAll()
	assert(p:GetAttribute("CompletedFinds") > 0, "No unsold find for bell")
	local before = p:GetAttribute("CrewHaul")
	event("retained unsold find for natural bell; haul=" .. before)
	waitFor(function()
		return status:GetAttribute("Phase") == "results"
	end, cfg.shiftSeconds, "natural bell")
	assert(
		status:GetAttribute("ResultHaul") == before and p:GetAttribute("CrewHaul") == before,
		"Bell paid unsold find"
	)
	local rows = game.HttpService:JSONDecode(status:GetAttribute("ResultCredits"))
	local sold = 0
	for _, row in rows do
		sold += row.sold
	end
	assert(sold == before, "Credit sale total mismatch")
	report.haul, report.rows = before, rows
	event("natural bell: unsold find unpaid; credit sold totals match haul=" .. before)
	local old = status:GetAttribute("RunId")
	rs.RunRequest:FireServer("replay", old)
	waitFor(function()
		return status:GetAttribute("RunId") ~= old
	end, 5, "replay")
	assert(
		p:GetAttribute("RunCash") == 0
			and p:GetAttribute("CarriedBatches") == 0
			and p:GetAttribute("CompletedFinds") == 0,
		"Replay inventory/cash"
	)
	for _, attr in { "ShovelUpgraded", "ShovelTierThree", "PanUpgraded", "PanTierThree" } do
		assert(not p:GetAttribute(attr), "Replay tool " .. attr)
	end
	for _, attr in { "SluiceBuilt", "SluiceTierTwo", "SluiceHopper" } do
		assert(not status:GetAttribute(attr), "Replay machine " .. attr)
	end
	assert(
		status:GetAttribute("BinCount") == 0 and status:GetAttribute("CrewHaul") == 0,
		"Replay bin/haul"
	)
	assert(status:GetAttribute("ShiftPhase") == "day", "Replay phase")
	event("PASS: replay reset cash, inventory, tools, machinery, bin, haul and day phase")
end, debug.traceback)
connection:Disconnect()
phases:Disconnect()
report.state = if ok then "PASS" else "FAIL"
report.failure = if ok then nil else tostring(failure)
if not ok then
	warn(failure)
end
