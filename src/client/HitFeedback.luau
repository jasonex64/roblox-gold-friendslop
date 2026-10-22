--!strict
-- Presentation-only motion; never delays or changes server skill checks.
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local HitFeedback = {}
function HitFeedback.new(root, panel, title, theme)
	local layer = Instance.new("Frame")
	layer.Name = "HitFeedback"
	layer.BackgroundTransparency = 1
	layer.AnchorPoint = Vector2.new(0.5, 0.5)
	layer.Size = UDim2.fromOffset(230, 40)
	layer.ZIndex = 6
	layer.Visible = false
	layer.Parent = root
	local label = theme.text(layer, "Grade", "", 30, true)
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Position = UDim2.fromScale(0.5, 0.5)
	label.Size = UDim2.fromScale(1, 1)
	local scale = Instance.new("UIScale")
	scale.Parent = label
	local stroke = label:FindFirstChildOfClass("UIStroke")
	assert(stroke, "HitFeedback: outlined label needs stroke")
	local sparks = {}
	for index = 1, 12 do
		local spark = Instance.new("Frame")
		spark.Name = "Spark" .. index
		spark.AnchorPoint = Vector2.new(0.5, 0.5)
		spark.Size = UDim2.fromOffset(7, 7)
		spark.BorderSizePixel = 0
		spark.ZIndex = 1
		spark.Parent = layer
		sparks[index] = spark
	end
	label.ZIndex = 2
	local elapsed = nil
	local perfect = false
	local self = {}
	function self.clear()
		elapsed = nil
		layer.Visible = false
		title.Visible = true
	end
	local function render()
		assert(elapsed, "HitFeedback: render requires active effect")
		layer.Position = UDim2.fromOffset(
			panel.AbsolutePosition.X - root.AbsolutePosition.X + panel.AbsoluteSize.X / 2,
			panel.AbsolutePosition.Y - root.AbsolutePosition.Y + 22
		)
		local pop = TweenService:GetValue(
			math.min(elapsed / 0.32, 1),
			Enum.EasingStyle.Back,
			Enum.EasingDirection.Out
		)
		scale.Scale = (0.45 + 0.55 * pop) * (if perfect then 1.12 else 1)
		label.Rotation = -9 * (1 - pop)
		local fade = math.clamp((elapsed - 0.42) / 0.24, 0, 1)
		label.TextTransparency = fade
		stroke.Transparency = fade
		for index, spark in sparks do
			local angle = index / #sparks * math.pi * 2
			local spread = math.min(elapsed / 0.45, 1)
			spark.Position = UDim2.fromOffset(
				115 + math.cos(angle) * (65 + spread * 42),
				20 + math.sin(angle) * (8 + spread * 12)
			)
			spark.Rotation = 45 + spread * 100
			spark.BackgroundTransparency = math.clamp(elapsed / 0.58, 0, 1)
		end
	end
	function self.play(grade)
		assert(grade == "good" or grade == "perfect", "HitFeedback: unsupported grade")
		perfect = grade == "perfect"
		label.Text = if perfect then "PERFECT!" else "GOOD!"
		label.TextColor3 = if perfect then theme.gold else theme.green
		for index, spark in sparks do
			spark.Visible = perfect or index % 2 == 0
			spark.BackgroundColor3 = if index % 2 == 0 then label.TextColor3 else theme.white
		end
		elapsed = 0
		layer.Visible = true
		title.Visible = false
		render()
	end
	RunService.RenderStepped:Connect(function(dt)
		if elapsed then
			elapsed += dt
			if elapsed >= 0.66 then
				self.clear()
			else
				render()
			end
		end
	end)
	return self
end
return HitFeedback
