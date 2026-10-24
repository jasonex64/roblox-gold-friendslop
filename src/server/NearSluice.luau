--!strict
-- Use the pad footprint plus the avatar's physical bounds, not a client distance.
local function near(player, pad)
	local character = player.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	if not root or not humanoid or humanoid.Health <= 0 then
		return false
	end
	local offset = pad.CFrame:PointToObjectSpace(root.Position)
	return math.abs(offset.X) <= (pad.Size.X + root.Size.X) / 2
		and math.abs(offset.Z) <= (pad.Size.Z + root.Size.Z) / 2
		and math.abs(offset.Y) <= character:GetExtentsSize().Y
end
return near
