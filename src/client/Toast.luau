--!strict
-- Presentation-only timing and geometry; never delays gameplay or server requests.
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Toast = {}
function Toast.new(root, theme)
	local layer = Instance.new("Frame")
	layer.Name = "Feedback"
	layer.AnchorPoint = Vector2.new(0.5, 0)
	layer.BackgroundTransparency = 1
	layer.ZIndex = 6
	layer.Visible = false
	layer.Parent = root
	local label = theme.text(layer, "Message", "", 24, true)
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Position = UDim2.fromScale(0.5, 0.5)
	label.Size = UDim2.fromScale(1, 1)
	label.ZIndex = 2
	local scale = Instance.new("UIScale")
	scale.Parent = label
	local stroke = label:FindFirstChildOfClass("UIStroke")
	assert(stroke, "Toast: message needs an outline")
	local sparks = {}
	for index = 1, 8 do
		local spark = Instance.new("Frame")
		spark.Name = "Spark" .. index
		spark.AnchorPoint = Vector2.new(0.5, 0.5)
		spark.Size = UDim2.fromOffset(5, 5)
		spark.BorderSizePixel = 0
		spark.BackgroundColor3 = if index % 2 == 0 then theme.gold else theme.white
		spark.Parent = layer
		sparks[index] = spark
	end
	local elapsed = nil
	local self = {}
	function self.clear()
		elapsed = nil
		layer.Visible = false
	end
	function self.layout(width, cell)
		-- Keep the toast centered in the gap between the persistent HUD cards.
		local available = width - 2 * (12 + cell * 2 + 8) - 16
		local narrow = available < 100
		layer.Position = UDim2.new(0.5, 0, 0, if narrow then 116 else 8)
		layer.Size = UDim2.fromOffset(if narrow then width - 32 else math.min(360, available), 88)
	end
	local function render()
		assert(elapsed, "Toast: render requires an active message")
		local pop = TweenService:GetValue(
			math.min(elapsed / 0.35, 1),
			Enum.EasingStyle.Back,
			Enum.EasingDirection.Out
		)
		local fade = math.clamp((elapsed - 2.6) / 0.4, 0, 1)
		scale.Scale = 0.65 + 0.35 * pop
		label.Rotation = -5 * (1 - pop)
		label.Position = UDim2.new(0.5, 0, 0.5, -8 * fade)
		label.TextTransparency = fade
		stroke.Transparency = fade
		for index, spark in sparks do
			local angle = index / #sparks * math.pi * 2
			local spread = math.min(elapsed / 0.6, 1)
			spark.Position = UDim2.fromScale(
				0.5 + math.cos(angle) * spread * 0.45,
				0.5 + math.sin(angle) * spread * 0.4
			)
			spark.Rotation = 45 + spread * 120
			spark.BackgroundTransparency = spread
		end
	end
	function self.show(message, celebrate)
		label.Text = message
		label.TextColor3 = if celebrate then theme.gold else theme.white
		for _, spark in sparks do
			spark.Visible = celebrate
		end
		elapsed = 0
		layer.Visible = true
		render()
	end
	RunService.RenderStepped:Connect(function(dt)
		if elapsed then
			elapsed += dt
			if elapsed >= 3 then
				self.clear()
			else
				render()
			end
		end
	end)
	return self
end
return Toast
