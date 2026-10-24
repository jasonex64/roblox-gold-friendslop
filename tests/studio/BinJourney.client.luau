--!strict
-- Real UI and remotes in a fresh solo Play session, using Studio VirtualInput.
local player = game.Players.LocalPlayer
local rs = game.ReplicatedStorage
local config = require(rs.Shared.Config)
local status = rs.RunStatus
local root = player.PlayerGui.GoldHUD.Root
local input = game:GetService("UserInputService"):CreateVirtualInput()
local function stand(pad)
	player.Character:PivotTo(CFrame.new(pad.Position + Vector3.new(0, 4, 0)))
	task.wait(0.6)
end
local function click(object, fraction)
	local point = object.AbsolutePosition
		+ object.AbsoluteSize * Vector2.new(fraction, 0.5)
		+ game:GetService("GuiService"):GetGuiInset()
	input:SendMousePosition(point)
	task.wait(0.1)
	input:SendMouseButton(point, Enum.UserInputType.MouseButton1, true, 0)
	input:SendMouseButton(point, Enum.UserInputType.MouseButton1, false, 0)
	task.wait(0.3)
end
assert(
	player:GetAttribute("CarriedBatches") == 0 and status:GetAttribute("BinCount") == 0,
	"BIN journey needs empty inventories"
)
stand(workspace.RiverCamp.Bank)
for _ = 1, config.bucketBatches do
	rs.ActionRequest:FireServer("dig")
	task.wait(config.digSeconds + 0.2)
end
assert(player:GetAttribute("CarriedBatches") == config.bucketBatches)
stand(workspace.RiverCamp.DirtBin)
input:SendKey(true, Enum.KeyCode.E, false)
input:SendKey(false, Enum.KeyCode.E, false)
task.wait(0.2)
local panel = root.SharedBin
assert(panel.Visible)
click(panel.deposit.Slider, 0.5)
assert(panel.deposit.Selected.Caption.Text == "Deposit 3", panel.deposit.Selected.Caption.Text)
click(panel.deposit.Selected, 0.5)
assert(status:GetAttribute("BinCount") == 3 and player:GetAttribute("CarriedBatches") == 2)
click(panel.deposit.All, 0.5)
assert(status:GetAttribute("BinCount") == 5 and player:GetAttribute("CarriedBatches") == 0)
click(panel.withdraw.Slider, 0.25)
assert(panel.withdraw.Selected.Caption.Text == "Withdraw 2", panel.withdraw.Selected.Caption.Text)
click(panel.withdraw.Selected, 0.5)
assert(status:GetAttribute("BinCount") == 3 and player:GetAttribute("CarriedBatches") == 2)
click(panel.withdraw.All, 0.5)
assert(status:GetAttribute("BinCount") == 0 and player:GetAttribute("CarriedBatches") == 5)
assert(player:GetAttribute("RunCash") == 0 and player:GetAttribute("CrewHaul") == 0)
print(
	"[BIN live UI] E opens panel; deposit slider 3 + All 2; withdraw slider 2 + All 3; bucket/bin conserve five dirt; no cash generated"
)
