--!strict
-- Execute in the Studio SERVER command context during play. Isolated services use
-- the live avatar/pad context, with fixture inventories; no production state edits.
local player = game:GetService("Players"):GetPlayers()[1]
assert(player, "SIFT fixtures require a player")
local Shared = game:GetService("ReplicatedStorage").Shared
local Batch = require(Shared.Pure.Batch)
local Dig = require(Shared.Pure.Dig)
local config = table.clone(require(Shared.Config))
local attributes = player:GetAttributes()
local running = true
local drawCount = 0
local dig = Dig.new(config, Batch, function()
	drawCount += 1
	return { kind = "Mystery Crate", baseValue = 100, crateValue = 100, sourceMultiplier = 2 }
end)
local captured = {}
local service = require(game:GetService("ServerScriptService").Server.Sifting).new(
	config,
	{
		activity = function() end,
		acceptsPlayer = function()
			return running
		end,
	},
	workspace.RiverCamp,
	{
		get = function()
			return dig
		end,
	},
	{
		FireClient = function(_, _, result, view, find)
			table.insert(captured, { result = result, view = view, find = find })
		end,
	}
)
service.add(player)
local controller = service.get(player)
local function seed(id, now)
	assert(dig.start({
		id = id,
		source = "FixtureBank",
		digger = tostring(player.UserId),
		distance = 0,
		now = now,
	}, "running") == "started")
	assert(dig.step(now + config.digSeconds, 0, "running", "FixtureBank") == "created")
end
player.Character:PivotTo(CFrame.new(workspace.RiverCamp.River.Position + Vector3.new(0, 4, 0)))
player.Character.Humanoid:EquipTool(player.Backpack.Pan)
task.wait(0.5)
assert(service.request(player, "start") == "no_dirt")
seed("fixture-crate", 0)
local original = dig.state.batches["fixture-crate"]
dig.pending = {}
assert(service.request(player, "start") == "busy_digging")
dig.pending = nil
config.outputCapacity = 1
controller.outputs.full = {}
assert(service.request(player, "start") == "full_output")
assert(dig.state.batches[original.id] == original and controller.reserved == 0)
controller.outputs = {}
running = false
assert(service.request(player, "start") == "wrong_phase")
running = true
for _, action in { "complete", "perfect", "sell" } do
	assert(service.request(player, action) == "invalid_request")
end
assert(service.request(player, "start", 1000) == "invalid_request")
controller.upgrades = 1
controller.rate = 2
assert(service.request(player, "start") == "started")
assert(player:GetAttribute("CarriedBatches") == 0, "starting sift must consume its one dirt")
local pending = controller.pending
assert(pending.duration == 1 and pending.checks[1].zoneWidth == 0.3125)
assert(pending.checks[1].perfectWidth == 0.0625 and controller.reserved == 1)
assert(dig.start({}, "running") == "busy_sifting")
controller.rate = 1
controller.upgrades = 0
assert(pending.duration == 1 and pending.checks[1].zoneWidth == 0.3125)
assert(service.request(player, "press", pending.id, 0 / 0) == "invalid_request")
assert(service.request(player, "press", pending.id, 1, "perfect") == "invalid_request")
assert(service.request(player, "press", "forged", 1) == "stale_check")
assert(service.request(player, "press", pending.id, 2) == "stale_check")
print(
	"[SIFT-1] Studio service rejects empty/full/busy/closed; reserves output and snapshots upgraded zones/rate"
)
for index, check in pending.checks do
	local time = check.startedAt + (check.zoneStart + check.zoneWidth / 2) / check.needleSpeed
	assert(controller.press(time, pending.id, index) == "perfect")
	assert(controller.press(time, pending.id, index) == "stale_check")
end
local find = controller.outputs[original.id]
assert(find and math.abs(find.value - 320) < 0.000001)
assert(find.outcome == original.outcome and drawCount == 1)
assert(controller.step(pending.endsAt, true) == "idle")
assert(controller.reserved == 0 and not dig.sifting)
assert(service.request(player, "complete", original.id, 999) == "invalid_request")
assert(controller.outputs[original.id] == find)
print(
	"[SIFT-2/4/5] assigned crate completes once at value=320; forged completion and repeated/stale grades grant nothing"
)
controller.outputs = {}
seed("cutoff", 2)
assert(service.request(player, "start") == "started")
local cancelled = controller.pending.id
running = false
service.step()
assert(controller.pending == nil and controller.reserved == 0 and dig.state.batches.cutoff == nil)
running = true
assert(service.request(player, "press", cancelled, 1) == "stale_check")
assert(next(controller.outputs) == nil and drawCount == 2)
print(
	"[SIFT-3] closed production gate discards active batch and releases reservation; stale input cannot revive it"
)
seed("move", 4)
assert(service.request(player, "start") == "started")
player.Character:PivotTo(CFrame.new(workspace.RiverCamp.Camp.Position + Vector3.new(0, 4, 0)))
service.step()
assert(controller.pending == nil and controller.reserved == 0 and dig.state.batches.move == nil)
print("[SIFT-3] leaving river cancels active sift without output")
service.remove(player)
for key, value in attributes do
	player:SetAttribute(key, value)
end
print("[SIFT fixtures] all assertions passed; live attributes restored")
