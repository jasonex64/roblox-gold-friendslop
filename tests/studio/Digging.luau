--!strict
-- Server service regression with isolated inventory; production state is untouched.
local player = game.Players:GetPlayers()[1]
local config = require(game.ReplicatedStorage.Shared.Config)
local attributes, pivot = player:GetAttributes(), player.Character:GetPivot()
local running = true
local service = require(game.ServerScriptService.Server.Digging).new(config, {
	run = { startedAt = workspace:GetServerTimeNow() },
	now = function()
		return workspace:GetServerTimeNow()
	end,
	activity = function() end,
	-- T-027 contribution credit; this fixture does not check credit.
	record = function() end,
	acceptsPlayer = function()
		return running
	end,
}, workspace.RiverCamp)
service.add(player)
local controller = service.get(player)
local camp = workspace.RiverCamp
local function stand(pad)
	player.Character:PivotTo(CFrame.new(pad.Position + Vector3.new(0, 4, 0)))
	task.wait(0.5)
end
player.Character.Humanoid:EquipTool(player.Backpack.Shovel)
assert(service.request(player, "complete") == "invalid_request")
assert(service.request(player, "start", 999) == "invalid_request")
stand(camp.Camp)
assert(service.request(player, "start") == "out_of_range")
stand(camp.Bank)
running = false
assert(service.request(player, "start") == "wrong_phase")
running = true
assert(next(controller.state.batches) == nil and controller.openingCount == 0)
assert(service.request(player, "start") == "started")
assert(service.request(player, "start") == "over_rate")
service.step()
assert(next(controller.state.batches) == nil)
service.cancel(player)
task.wait(config.digSeconds)
service.step()
assert(next(controller.state.batches) == nil and controller.openingCount == 0)
for _ = 1, config.bucketBatches do
	assert(service.request(player, "start") == "started")
	task.wait(config.digSeconds + 0.05)
	service.step()
end
local saved = controller.state.batches
assert(controller.openingCount == config.bucketBatches)
assert(service.request(player, "start") == "full_capacity")
for id, batch in saved do
	assert(batch.id == id and batch.source == "Bank" and batch.digger == tostring(player.UserId))
	assert(batch.outcome.kind == "Gold Flakes" and batch.outcome.baseValue == config.openingValue)
end
stand(camp.Camp)
service.cancel(player)
service.step()
assert(controller.state.batches == saved, "movement/cancel changed retained batches")
-- Fixture-only space lets the source/quality test pass the guaranteed opening boundary.
local removed = next(saved)
local remaining = table.clone(saved)
remaining[removed] = nil
controller.state = table.clone(controller.state)
controller.state.batches = remaining
local pad = Instance.new("Part")
pad.Name = "T011QualityBank"
pad.Anchored = true
pad.Size = camp.Bank.Size
pad.Position = camp.Bank.Position + Vector3.new(-24, 0, 0)
pad:SetAttribute("DigSource", "T011QualityBank")
pad:SetAttribute("DirtMultiplier", 2)
pad.Parent = camp
stand(pad)
assert(service.request(player, "start") == "started")
task.wait(config.digSeconds + 0.05)
service.step()
assert(controller.openingCount == config.bucketBatches + 1)
local found = false
for id, batch in controller.state.batches do
	if not remaining[id] then
		assert(batch.source == "T011QualityBank" and batch.outcome.sourceMultiplier == 2)
		found = true
	else
		assert(batch == remaining[id], "new dig replaced a retained batch")
	end
end
assert(found)
service.remove(player)
pad:Destroy()
for key, value in attributes do
	player:SetAttribute(key, value)
end
player.Character:PivotTo(pivot)
print(
	"[T011 DIG-1/2/3] forged/rate/range/phase/full requests reject; duration/cancel correct; five immutable opening batches; sixth fixture batch retains distinct source/quality; production inventory untouched"
)
return "Digging regression passed"
