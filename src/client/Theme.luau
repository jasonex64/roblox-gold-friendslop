--!strict
-- D-019: glossy simulator theme. Numbers here are presentation geometry/colors.
local Theme = {}
Theme.ink = Color3.fromRGB(22, 26, 37)
Theme.gold = Color3.fromRGB(255, 204, 18)
Theme.green = Color3.fromRGB(134, 240, 18)
Theme.cyan = Color3.fromRGB(34, 208, 244)
Theme.purple = Color3.fromRGB(185, 100, 250)
Theme.white = Color3.fromRGB(255, 255, 255)
function Theme.border(object, thickness)
	local stroke = Instance.new("UIStroke")
	stroke.Color = Theme.ink
	stroke.Thickness = thickness
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = object
end
function Theme.surface(parent, name, color)
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.BackgroundColor3 = color
	frame.BorderSizePixel = 0
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 14)
	corner.Parent = frame
	Theme.border(frame, 3)
	frame.Parent = parent
	return frame
end
function Theme.gloss(object, color)
	object.BackgroundColor3 = Theme.white
	local gradient = Instance.new("UIGradient")
	gradient.Rotation = 90
	gradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, color:Lerp(Theme.white, 0.55)),
		ColorSequenceKeypoint.new(0.48, color),
		ColorSequenceKeypoint.new(1, color:Lerp(Theme.ink, 0.12)),
	})
	gradient.Parent = object
end
function Theme.text(parent, name, text, size, outlined)
	local label = Instance.new("TextLabel")
	label.Name = name
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.Text = text
	label.TextSize = size
	label.TextScaled = true
	label.TextWrapped = true
	label.TextColor3 = if outlined then Theme.white else Theme.ink
	local constraint = Instance.new("UITextSizeConstraint")
	constraint.MinTextSize = 12
	constraint.MaxTextSize = size
	constraint.Parent = label
	if outlined then
		local stroke = Instance.new("UIStroke")
		stroke.Color = Theme.ink
		stroke.Thickness = 2
		stroke.Parent = label
	end
	label.Parent = parent
	return label
end
function Theme.button(parent, name, text, color)
	local button = Instance.new("TextButton")
	button.Name = name
	button.Text = ""
	button.BorderSizePixel = 0
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = button
	Theme.border(button, 3)
	Theme.gloss(button, color)
	local caption = Theme.text(button, "Caption", text, 22, true)
	caption.Size = UDim2.new(1, -16, 1, -8)
	caption.Position = UDim2.fromOffset(8, 4)
	button.Parent = parent
	return button
end
return Theme
