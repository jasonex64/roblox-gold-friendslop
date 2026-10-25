--!strict
-- Placeholder visual geometry, not interaction distances or production tuning.
local Camp = {}

function Camp.build(config)
	assert(not workspace:FindFirstChild("RiverCamp"), "RiverCamp already exists")
	local model = Instance.new("Model")
	model.Name = "RiverCamp"
	local function part(name, size, position, color)
		local p = Instance.new("Part")
		p.Name = name
		p.Anchored = true
		p.Size = size
		p.Position = position
		p.Color = color
		p.Material = Enum.Material.SmoothPlastic
		p.Parent = model
		return p
	end
	part("Ground", Vector3.new(160, 2, 120), Vector3.new(0, -1, 0), Color3.fromRGB(100, 133, 83))
	local function station(name, position, color, text)
		local p = part(name, Vector3.new(18, 0.2, 18), position, color)
		local sign = Instance.new("BillboardGui")
		sign.Size = UDim2.fromOffset(220, 60)
		sign.StudsOffset = Vector3.new(0, 5, 0)
		sign.AlwaysOnTop = true
		sign.Parent = p
		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.TextColor3 = Color3.new(1, 1, 1)
		label.TextStrokeTransparency = 0
		label.TextScaled = true
		label.Text = text
		label.Parent = sign
	end
	station("Camp", Vector3.new(0, 0.1, 24), Color3.fromRGB(180, 151, 101), "CAMP • START")
	station("Bank", Vector3.new(-32, 0.1, -16), Color3.fromRGB(165, 111, 62), "BANK • DIG")
	model.Bank:SetAttribute("DigSource", "Bank")
	model.Bank:SetAttribute("DirtMultiplier", config.ordinaryMultiplier)
	station(
		config.richSource,
		Vector3.new(0, 0.1, 24 - config.richBankDistance),
		Color3.fromRGB(123, 75, 165),
		"RICH BANK • CLOSED"
	)
	model[config.richSource]:SetAttribute("DigSource", config.richSource)
	model[config.richSource]:SetAttribute("DirtMultiplier", config.richMultiplier)
	-- Walkable route to the farther bank; width/thickness are placeholder geometry.
	part(
		"RichBankPath",
		Vector3.new(24, 2, config.richBankDistance),
		Vector3.new(0, -1, 24 - config.richBankDistance / 2),
		Color3.fromRGB(100, 133, 83)
	)
	station("River", Vector3.new(0, 0.1, -24), Color3.fromRGB(61, 158, 191), "RIVER • SIFT")
	station("Buyer", Vector3.new(32, 0.1, -16), Color3.fromRGB(207, 167, 60), "BUYER • SELL")
	station(
		"DirtBin",
		Vector3.new(-24, 0.1, 18),
		Color3.fromRGB(139, 100, 72),
		"CREW BIN • SHARE DIRT"
	)
	local spawn = Instance.new("SpawnLocation")
	station(
		"Sluice",
		Vector3.new(24, 0.1, 18),
		Color3.fromRGB(110, 170, 155),
		"SLUICE • CREW FUNDING"
	)
	part(
		"SluiceTrough",
		Vector3.new(12, 1, 4),
		Vector3.new(24, 2, 26),
		Color3.fromRGB(64, 155, 196)
	)
	spawn.Name = "CampSpawn"
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Size = Vector3.new(6, 0.2, 6)
	spawn.Position = Vector3.new(0, 0.3, 24)
	spawn.Transparency = 1
	spawn.Parent = model
	model.Parent = workspace
	return spawn
end

return Camp
