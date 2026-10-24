--!strict
-- Run through the client connector on a fresh solo Play run. Uses real remotes;
-- no test inventory injection or clock changes. Presentation/pacing waits are test-only.
local player = game.Players.LocalPlayer
local replicated = game.ReplicatedStorage
local config = require(replicated.Shared.Config)
local status = replicated.RunStatus
local remote = replicated.ActionRequest
local deadline = os.clock() + 15
while status:GetAttribute("Phase") ~= "running" do
	assert(os.clock() < deadline, "CREW journey: shift did not start")
	task.wait()
end
assert(player:GetAttribute("CrewMember"), "CREW journey: player not admitted")
assert(player:GetAttribute("RunCash") == 0, "CREW journey needs a fresh run")
player.PlayerGui.GoldHUD.Root.Guide.Visible = false
local function stand(pad)
	player.Character:PivotTo(CFrame.new(pad.Position + Vector3.new(0, 4, 0)))
	task.wait(0.5)
end
stand(workspace.RiverCamp.Bank)
remote:FireServer("dig")
task.wait(config.digSeconds + 0.5)
assert(player:GetAttribute("CarriedBatches") == 1, "CREW journey: dirt not created")
stand(workspace.RiverCamp.River)
remote:FireServer("sift")
task.wait(config.siftSeconds + 0.5)
assert(player:GetAttribute("CompletedFinds") == 1, "CREW journey: find not completed")
stand(workspace.RiverCamp.Buyer)
local receipt
local connection = replicated.EconomyRequest.OnClientEvent:Connect(function(code, share, total)
	if code == "sold" then
		receipt = { share = share, total = total }
	end
end)
remote:FireServer("sell")
task.wait(0.25)
connection:Disconnect()
assert(
	receipt and receipt.total > 0 and receipt.share == receipt.total,
	"CREW journey: invalid solo receipt"
)
assert(player:GetAttribute("RunCash") == receipt.share, "CREW journey: wrong wallet")
assert(player:GetAttribute("CrewHaul") == receipt.total, "CREW journey: wrong haul")
assert(player:GetAttribute("CompletedFinds") == 0, "CREW journey: find not consumed")
assert(player:GetAttribute("CashShareStatus") == "active", "CREW journey: sale did not activate")
print(
	"[CREW live client] dig -> sift -> shop via real remotes; sale=$"
		.. receipt.total
		.. "; personal share=$"
		.. receipt.share
		.. "; find consumed once; active cash shares"
)
return "CREW live client PASS"
