--!strict
local UserInputService = game:GetService("UserInputService")
local BinPanel = {}
function BinPanel.new(root, Theme, send)
	local panel = Theme.surface(root, "SharedBin", Theme.white)
	panel.Visible = false
	panel.ZIndex = 6
	local title = Theme.text(panel, "Title", "Crew dirt bin", 24, true)
	local close = Theme.button(panel, "Close", "X", Theme.purple)
	close.Activated:Connect(function()
		panel.Visible = false
	end)
	local rows = {}
	local dragging, touch = nil, nil
	for _, action in { "deposit", "withdraw" } do
		local frame = Instance.new("Frame")
		frame.Name = action
		frame.BackgroundTransparency = 1
		frame.Parent = panel
		local row = { frame = frame, amount = 0, maximum = 0 }
		row.label = Theme.text(frame, "Quantity", "", 18, false)
		row.track = Instance.new("TextButton")
		row.track.Name = "Slider"
		row.track.Text = ""
		row.track.BackgroundColor3 = Theme.cyan
		row.track.BorderSizePixel = 0
		row.track.Parent = frame
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(1, 0)
		corner.Parent = row.track
		row.thumb = Instance.new("Frame")
		row.thumb.Name = "Thumb"
		row.thumb.AnchorPoint = Vector2.new(0.5, 0.5)
		row.thumb.Size = UDim2.fromOffset(16, 28)
		row.thumb.BackgroundColor3 = Theme.gold
		Theme.border(row.thumb, 2)
		row.thumb.Parent = row.track
		row.choose = Theme.button(frame, "Selected", "", Theme.green)
		row.all = Theme.button(
			frame,
			"All",
			if action == "deposit" then "Deposit All" else "Withdraw All",
			Theme.gold
		)
		local verb = if action == "deposit" then "Deposit" else "Withdraw"
		function row.render()
			row.label.Text = string.format("%s: %d dirt (up to %d)", verb, row.amount, row.maximum)
			row.choose.Caption.Text = string.format("%s %d", verb, row.amount)
			row.thumb.Position = UDim2.fromScale(
				if row.maximum > 1 then (row.amount - 1) / (row.maximum - 1) else 0,
				0.5
			)
			row.choose.Active = row.maximum > 0
			row.all.Active = row.maximum > 0
		end
		function row.select(x)
			if row.maximum == 0 then
				return
			end
			local fraction =
				math.clamp((x - row.track.AbsolutePosition.X) / row.track.AbsoluteSize.X, 0, 1)
			row.amount = 1 + math.round(fraction * (row.maximum - 1))
			row.render()
		end
		row.track.InputBegan:Connect(function(input)
			if
				input.UserInputType == Enum.UserInputType.MouseButton1
				or input.UserInputType == Enum.UserInputType.Touch
			then
				dragging = row
				touch = if input.UserInputType == Enum.UserInputType.Touch then input else nil
				row.select(input.Position.X)
			end
		end)
		row.choose.Activated:Connect(function()
			if row.amount > 0 then
				send(action, row.amount)
			end
		end)
		row.all.Activated:Connect(function()
			if row.maximum > 0 then
				send(action, "all")
			end
		end)
		rows[action] = row
	end
	UserInputService.InputChanged:Connect(function(input)
		if
			panel.Visible
			and dragging
			and (
				input == touch
				or (touch == nil and input.UserInputType == Enum.UserInputType.MouseMovement)
			)
		then
			dragging.select(input.Position.X)
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if
			input == touch
			or (touch == nil and input.UserInputType == Enum.UserInputType.MouseButton1)
		then
			dragging, touch = nil, nil
		end
	end)
	local self = {}
	function self.open()
		panel.Visible = true
	end
	function self.update(eligible, count, capacity, carried, bucketCapacity)
		if not eligible then
			panel.Visible = false
		end
		title.Text = string.format("Crew bin: %d / %d dirt", count, capacity)
		for action, row in rows do
			row.maximum = math.max(
				0,
				if action == "deposit"
					then math.min(carried, capacity - count)
					else math.min(count, bucketCapacity - carried)
			)
			row.amount = if row.maximum == 0 then 0 else math.clamp(row.amount, 1, row.maximum)
			row.render()
		end
	end
	function self.layout(w, h)
		local width, height = math.min(w - 24, 480), math.min(h - 20, 350)
		panel.Size = UDim2.fromOffset(width, height)
		panel.Position = UDim2.fromOffset((w - width) / 2, (h - height) / 2)
		title.Position = UDim2.fromOffset(12, 8)
		title.Size = UDim2.new(1, -70, 0, 34)
		close.Position = UDim2.new(1, -50, 0, 8)
		close.Size = UDim2.fromOffset(38, 34)
		local rowHeight = (height - 54) / 2
		for index, action in { "deposit", "withdraw" } do
			local row = rows[action]
			row.frame.Position = UDim2.fromOffset(14, 46 + (index - 1) * rowHeight)
			row.frame.Size = UDim2.fromOffset(width - 28, rowHeight)
			row.label.Size = UDim2.new(1, 0, 0, 24)
			row.track.Position = UDim2.fromOffset(10, 32)
			row.track.Size = UDim2.new(1, -20, 0, 22)
			row.choose.Position = UDim2.new(0, 0, 1, -52)
			row.choose.Size = UDim2.new(0.5, -5, 0, 42)
			row.all.Position = UDim2.new(0.5, 5, 1, -52)
			row.all.Size = UDim2.new(0.5, -5, 0, 42)
		end
	end
	return self
end
return BinPanel
