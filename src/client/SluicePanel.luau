--!strict
local SluicePanel = {}
function SluicePanel.new(root, Theme, config, send)
	local panel = Theme.surface(root, "SluicePanel", Theme.white)
	panel.Visible = false
	panel.ZIndex = 6
	local title = Theme.text(panel, "Title", "Crew sluice", 25, true)
	local close = Theme.button(panel, "Close", "X", Theme.purple)
	close.Activated:Connect(function()
		panel.Visible = false
	end)
	local details = Theme.text(panel, "Details", "", 18, false)
	local names = Theme.text(panel, "Contributors", "", 15, false)
	local amount = Instance.new("TextBox")
	amount.Name = "Amount"
	amount.Text = ""
	amount.PlaceholderText = "Enter whole dollars"
	amount.ClearTextOnFocus = false
	amount.TextSize = 18
	amount.Font = Enum.Font.FredokaOne
	amount.TextColor3 = Theme.ink
	amount.BackgroundColor3 = Color3.fromRGB(230, 238, 240)
	amount.Parent = panel
	Theme.border(amount, 2)
	local contribute = Theme.button(panel, "Contribute", "Contribute", Theme.gold)
	local all = Theme.button(panel, "ContributeAll", "All I can", Theme.green)
	local bucket = Theme.button(panel, "LoadBucket", "Load from bucket", Theme.gold)
	local bin = Theme.button(panel, "LoadBin", "Load from bin", Theme.cyan)
	local note = Theme.text(panel, "Note", "", 15, false)
	local cash, remaining = 0, 0
	contribute.Activated:Connect(function()
		local value = tonumber(amount.Text)
		if value and value > 0 and value % 1 == 0 and value < math.huge then
			send("contribute", value)
		else
			note.Text = "Enter a positive whole-dollar amount."
		end
	end)
	all.Activated:Connect(function()
		local value = math.min(cash, remaining)
		if value > 0 then
			send("contribute", value)
		else
			note.Text = "Sell finds to earn Run Cash first."
		end
	end)
	bucket.Activated:Connect(function()
		send("load", "bucket")
	end)
	bin.Activated:Connect(function()
		send("load", "bin")
	end)
	local self = {}
	function self.open()
		panel.Visible = true
	end
	function self.update(eligible, status, wallet)
		if not eligible then
			panel.Visible = false
		end
		local price, funded =
			status:GetAttribute("SluicePrice"), status:GetAttribute("SluiceFunded")
		if price == nil or funded == nil or wallet == nil then
			return
		end
		cash, remaining = wallet, price - funded
		local built = status:GetAttribute("SluiceBuilt")
		local lanes, busy = status:GetAttribute("SluiceLanes"), status:GetAttribute("SluiceBusy")
		local output, capacity =
			status:GetAttribute("SluiceOutput"), status:GetAttribute("SluiceOutputCapacity")
		if lanes ~= nil and busy ~= nil and output ~= nil and capacity ~= nil then
			details.Text = if built
				then string.format(
					"Built! %d / %d lanes busy • %.0fs per dirt\nShared finds: %d / %d",
					busy,
					lanes,
					config.sluiceProcessSeconds,
					output,
					capacity
				)
				else string.format(
					"Funded $%d / $%d • Your cash: $%d\nBuilds %d lanes • %.0fs per dirt • %d find storage",
					funded,
					price,
					wallet,
					lanes,
					config.sluiceProcessSeconds,
					capacity
				)
		end
		local contributors = status:GetAttribute("SluiceContributors")
		if contributors ~= nil then
			names.Text = if contributors == "" then "No contributions yet" else contributors
		end
		amount.Visible, contribute.Visible, all.Visible = not built, not built, not built
		bucket.Visible, bin.Visible = built, built
		note.Text = if built
			then "Load one dirt per click. Anyone can sell shared finds at the Buyer. Unsold finds disappear at the bell."
			else "Voluntary contributions use your cash. No refunds. Funding resets at the bell."
	end
	function self.layout(w, h)
		local width, height = math.min(w - 24, 510), math.min(h - 20, 340)
		panel.Size = UDim2.fromOffset(width, height)
		panel.Position = UDim2.fromOffset((w - width) / 2, (h - height) / 2)
		title.Position, title.Size = UDim2.fromOffset(12, 8), UDim2.new(1, -70, 0, 32)
		close.Position, close.Size = UDim2.new(1, -48, 0, 8), UDim2.fromOffset(36, 32)
		details.Position, details.Size = UDim2.fromOffset(14, 48), UDim2.new(1, -28, 0, 60)
		names.Position, names.Size = UDim2.fromOffset(14, 106), UDim2.new(1, -28, 0, 28)
		amount.Position, amount.Size = UDim2.fromOffset(16, 138), UDim2.new(1, -32, 0, 34)
		for _, button in { contribute, bucket } do
			button.Position, button.Size = UDim2.fromOffset(14, 180), UDim2.new(0.5, -20, 0, 44)
		end
		for _, button in { all, bin } do
			button.Position, button.Size = UDim2.new(0.5, 6, 0, 180), UDim2.new(0.5, -20, 0, 44)
		end
		note.Position, note.Size = UDim2.fromOffset(14, 232), UDim2.new(1, -28, 1, -240)
	end
	return self
end
return SluicePanel
