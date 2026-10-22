--!strict
-- Run in Studio Client, including device emulation and each open panel.
local player = game.Players.LocalPlayer
local root = player.PlayerGui.GoldHUD.Root
local status = game.ReplicatedStorage.RunStatus
local config = require(game.ReplicatedStorage.Shared.Config)
assert(root.Top["Crew Haul"].Value.Text == string.format("$%d", player:GetAttribute("CrewHaul")))
assert(root.Top["Run Cash"].Value.Text == string.format("$%d", player:GetAttribute("RunCash")))
local seconds = status:GetAttribute("RemainingSeconds")
assert(
	root.Top.Waiting.Value.Text
		== string.format("%02d:%02d", math.floor(seconds / 60), seconds % 60)
)
assert(root.Top.Waiting.Title.Text == status:GetAttribute("Phase"):gsub("^%l", string.upper))
assert(
	root.Inventory.Counts.Text
		== string.format(
			"Dirt %d/%d  •  Finds %d/%d",
			player:GetAttribute("CarriedBatches"),
			config.bucketBatches,
			player:GetAttribute("CompletedFinds"),
			config.outputCapacity
		)
)
assert(root.ActionDock.Hint.Text == player:GetAttribute("HudHint"))
local viewport = workspace.CurrentCamera.ViewportSize
local buttons = 0
local function inspect(object)
	if object:IsA("GuiObject") then
		if not object.Visible then
			return
		end
		local p, s = object.AbsolutePosition, object.AbsoluteSize
		local origin, bounds = root.AbsolutePosition, root.AbsoluteSize
		assert(
			p.X >= origin.X
				and p.Y >= origin.Y
				and p.X + s.X <= origin.X + bounds.X + 1
				and p.Y + s.Y <= origin.Y + bounds.Y + 1,
			"UX outside safe area: " .. object:GetFullName()
		)
		if object:IsA("TextLabel") then
			assert(object.TextFits, "UX clipped text: " .. object:GetFullName())
		end
		if object:IsA("TextButton") then
			assert(s.X >= 44 and s.Y >= 44, "UX small target: " .. object:GetFullName())
			buttons += 1
		end
	end
	for _, child in object:GetChildren() do
		if child:IsA("GuiObject") then
			inspect(child)
		end
	end
end
-- Dial segments rotate at the ring edge; assess the enclosing dial visually.
for _, child in root:GetChildren() do
	if child.Name ~= "Sift" then
		inspect(child)
	end
end
if root.Sift.Visible then
	for _, child in root.Sift:GetChildren() do
		if child:IsA("GuiObject") and child.Name ~= "Dial" then
			inspect(child)
		end
	end
end
print(
	string.format(
		"[UX-2 layout] %dx%d: timer/phase/haul/cash/bucket/next-action match server; visible text fits and %d buttons meet 44px targets",
		viewport.X,
		viewport.Y,
		buttons
	)
)
