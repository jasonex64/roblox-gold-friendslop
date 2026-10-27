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
	-- After the build, each add-on has its own fund button (D-043, D-044).
	local fundTier = Theme.button(panel, "FundTierTwo", "Fund tier two", Theme.gold)
	local fundHopper = Theme.button(panel, "FundHopper", "Fund hopper", Theme.cyan)
	local upgrades = Theme.text(panel, "Upgrades", "", 18, true)
	local hopperLine = Theme.text(panel, "Hopper", "", 18, true)
	upgrades.Visible, hopperLine.Visible = false, false
	fundTier.Visible, fundHopper.Visible = false, false

	local note = Theme.text(panel, "Note", "", 15, false)
	local cash, remaining = 0, { contribute = 0, upgrade = 0, hopper = 0 }
	local size, mode = nil, nil
	local function arrange()
		if not size then
			return
		end
		local width, height = math.min(size.X - 24, 510), math.min(size.Y - 20, 380)
		panel.Size = UDim2.fromOffset(width, height)
		panel.Position = UDim2.fromOffset((size.X - width) / 2, (size.Y - height) / 2)
		title.Position, title.Size = UDim2.fromOffset(12, 8), UDim2.new(1, -70, 0, 32)
		close.Position, close.Size = UDim2.new(1, -48, 0, 8), UDim2.fromOffset(36, 32)
		details.Position, details.Size = UDim2.fromOffset(14, 48), UDim2.new(1, -28, 0, 60)
		names.Position, names.Size = UDim2.fromOffset(14, 106), UDim2.new(1, -28, 0, 28)
		local y = 138
		if upgrades.Visible then
			upgrades.Position, upgrades.Size = UDim2.fromOffset(14, y), UDim2.new(1, -28, 0, 28)
			hopperLine.Position, hopperLine.Size =
				UDim2.fromOffset(14, y + 34), UDim2.new(1, -28, 0, 28)
			y += 68
		end
		if amount.Visible then
			amount.Position, amount.Size = UDim2.fromOffset(16, y), UDim2.new(1, -32, 0, 34)
			for _, button in { contribute, fundTier } do
				button.Position, button.Size =
					UDim2.fromOffset(14, y + 42), UDim2.new(0.5, -20, 0, 44)
			end
			for _, button in { all, fundHopper } do
				button.Position, button.Size =
					UDim2.new(0.5, 6, 0, y + 42), UDim2.new(0.5, -20, 0, 44)
			end
			y += 94
		end
		note.Position, note.Size = UDim2.fromOffset(14, y), UDim2.new(1, -28, 1, -(y + 8))
	end
	-- Sends the typed whole-dollar amount, or everything the player can put toward action.
	local function give(action, typed)
		if typed then
			local value = tonumber(amount.Text)
			if value and value > 0 and value % 1 == 0 and value < math.huge then
				send(action, value)
			else
				note.Text = "Enter a positive whole-dollar amount."
			end
			return
		end
		local value = math.min(cash, remaining[action])
		if value > 0 then
			send(action, value)
		else
			note.Text = "Sell finds to earn Run Cash first."
		end
	end
	contribute.Activated:Connect(function()
		give("contribute", true)
	end)
	all.Activated:Connect(function()
		give("contribute", false)
	end)
	fundTier.Activated:Connect(function()
		give("upgrade", amount.Text ~= "")
	end)
	fundHopper.Activated:Connect(function()
		give("hopper", amount.Text ~= "")
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
		local built = status:GetAttribute("SluiceBuilt")
		local tierTwo = status:GetAttribute("SluiceTierTwo")
		local tierFunded, tierPrice =
			status:GetAttribute("SluiceTierTwoFunded"), status:GetAttribute("SluiceTierTwoPrice")
		local hopper = status:GetAttribute("SluiceHopper")
		local hopperFunded, hopperPrice =
			status:GetAttribute("SluiceHopperFunded"), status:GetAttribute("SluiceHopperPrice")
		if
			tierTwo == nil
			or tierFunded == nil
			or tierPrice == nil
			or hopper == nil
			or hopperFunded == nil
			or hopperPrice == nil
		then
			return
		end
		cash = wallet
		remaining = {
			contribute = price - funded,
			upgrade = tierPrice - tierFunded,
			hopper = hopperPrice - hopperFunded,
		}
		local seconds = if tierTwo then config.sluiceTierTwoSeconds else config.sluiceProcessSeconds
		local lanes, busy = status:GetAttribute("SluiceLanes"), status:GetAttribute("SluiceBusy")
		local output, capacity =
			status:GetAttribute("SluiceOutput"), status:GetAttribute("SluiceOutputCapacity")
		if lanes ~= nil and busy ~= nil and output ~= nil and capacity ~= nil then
			details.Text = if built
				then string.format(
					"%d / %d lanes busy • %gs per dirt\nDirt: %d / %d • Finished finds: %d / %d",
					busy,
					lanes,
					seconds,
					status:GetAttribute("SluiceDirt"),
					config.sluiceDirtCapacity,
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
		local addons = built and not (tierTwo and hopper)
		contribute.Visible, all.Visible = not built, not built
		amount.Visible = not built or addons
		amount.PlaceholderText = if built
			then "Whole dollars, or leave blank for all you can"
			else "Enter whole dollars"
		fundTier.Visible, fundHopper.Visible = built and not tierTwo, built and not hopper
		upgrades.Visible, hopperLine.Visible = built, built
		upgrades.Text = if tierTwo
			then string.format("Tier two built • %gs per dirt", config.sluiceTierTwoSeconds)
			else string.format(
				"Tier two: $%d / $%d • %gs per dirt",
				tierFunded,
				tierPrice,
				config.sluiceTierTwoSeconds
			)
		hopperLine.Text = if hopper
			then "Hopper built • feeds crew bin dirt into free lanes"
			else string.format(
				"Hopper: $%d / $%d • feeds crew bin dirt",
				hopperFunded,
				hopperPrice
			)
		note.Text = if not built
			then "Voluntary contributions use your cash. No refunds. Funding resets at the bell."
			elseif
				addons
			then "Add-ons are voluntary, no refunds, and reset at the bell. Tier two speeds up dirt loaded after it; the hopper feeds crew bin dirt automatically."
			else "Use Quick Transfer nearby: Bucket dirt in, Backpack finds out. Lanes run 25% faster in the final rush. Unsold items disappear at the bell."
		local nextMode = if not built then "build" elseif addons then "addons" else "done"
		if nextMode ~= mode then
			mode = nextMode
			arrange()
		end
	end
	function self.layout(w, h)
		size = Vector2.new(w, h)
		arrange()
	end
	return self
end
return SluicePanel
