--!strict
-- Presentation decisions use only a server snapshot; no client location or money.
local Hud = {}
function Hud.remaining(run, now)
	if run.phase == "running" then
		assert(run.endsAt, "Hud: running run missing cutoff")
		return math.max(0, math.ceil(run.endsAt - now))
	elseif run.phase == "countdown" then
		assert(run.readyAt, "Hud: countdown missing readyAt")
		return math.max(0, math.ceil(run.readyAt + run.config.readySeconds - now))
	end
	return 0
end
function Hud.nextAction(s, config)
	if s.phase ~= "running" then
		return "none",
			if s.phase == "results"
				then "Shift complete — play again!"
				else "Get ready for a fresh shift!"
	elseif not s.alive then
		return "none", "Respawning at camp..."
	elseif s.sifting then
		return "hit", "Hit the gold or green zone. Cancel discards this dirt."
	elseif s.digging then
		return "cancel", "Digging... stay on the Bank. No extra clicks needed."
	elseif s.station == "DirtBin" then
		return "open_bin", "Open the crew bin to deposit or take dirt."
	elseif s.station == "Sluice" then
		return "open_sluice", "Quick transfer bucket dirt and collect finds, or open sluice stats."
	elseif s.station == "Bank" then
		if s.carried >= config.bucketBatches then
			return "none", "Bucket full! Walk to the blue River and sift."
		end
		return "dig", "Dig one batch, then walk to the blue River."
	elseif s.station == "ClosedBank" then
		return "none",
			"Rich bank closed. Use the ordinary Bank; already dug rich dirt keeps its bonus."
	elseif s.station == "River" then
		if s.outputs >= config.outputCapacity then
			return "none", "Find bag full! Walk to the gold Buyer and sell."
		elseif s.carried == 0 then
			return "none", "No dirt! Walk to the brown Bank and dig."
		end
		return "sift", "Sift dirt here. Hit each zone when the needle reaches it."
	elseif s.station == "Buyer" then
		if s.outputs == 0 then
			return "none", "No finds to sell. Dig at the Bank, then sift at the River."
		end
		return "sell", "Sell all finished finds. Spending cash never lowers Crew Haul."
	elseif s.station == "Camp" and not s.upgraded and s.cash >= config.shovelUpgradePrice then
		return "buy", "Buy the temporary shovel here. It resets after this shift."
	elseif s.outputs >= config.outputCapacity or (s.outputs > 0 and s.carried == 0) then
		return "none", "Walk to the gold Buyer to sell your finished finds."
	elseif s.carried > 0 then
		return "none", "Walk to the blue River to sift your dirt."
	elseif not s.upgraded and s.cash >= config.shovelUpgradePrice then
		return "none", "Walk to Camp for a faster temporary shovel, or dig again."
	end
	return "none", "Walk to the brown Bank to dig your first batch."
end
Hud.messages = table.freeze({
	rich_bank_closed = "Rich bank closed. New rich digs are allowed only at night.",
	invalid_request = "That action was not accepted. Use the on-screen controls.",
	wrong_phase = "Production is closed. Wait for the next shift.",
	waiting_for_crew = "You are waiting for the next crew shift.",
	replay_waiting = "Ready! The next shift starts when the rest of the crew is ready.",
	crew_sale = "Crew sale! Your share was added to Run Cash.",
	stand_at_sluice = "Move near the Sluice to contribute or transfer items.",
	contributed = "Contribution added to the crew sluice!",
	sluice_built = "Crew sluice built! Load dirt to get it running.",
	sluice_transferred = "Sluice transfer complete!",
	sluice_no_transfer = "Nothing moved. Check Bucket dirt, Backpack space and sluice storage.",
	sluice_loaded = "Dirt loaded! Collect finished sluice finds into your Backpack.",
	insufficient_funds = "Not enough Run Cash for that contribution.",
	already_built = "The crew sluice is already built.",
	not_built = "Finish funding the crew sluice first.",
	lanes_full = "All sluice lanes are busy. Wait for a lane to finish.",
	output_full = "Sluice output full. Collect finds into your Backpack.",
	duplicate_batch = "This dirt has already been loaded.",
	stand_at_bin = "Stand on the Crew Bin pad to share dirt.",
	bin_changed = "The bin just changed. Try your transfer again.",
	bin_quantity_changed = "That much dirt no longer fits or is available. Choose an amount again.",
	bin_full = "Crew bin full. Take some dirt out to make room.",
	bin_empty = "The crew bin is empty.",
	bucket_empty = "Your bucket has no dirt to deposit.",
	deposited = "Dirt added to the crew bin!",
	withdrawn = "Dirt taken from the crew bin!",
	out_of_range = "Stand on the brown Bank to dig.",
	unavailable = "Wait for your character to respawn.",
	equip_pan = "Equip your Pan at the River.",
	stand_at_river = "Stand on the blue River to sift.",
	stand_at_buyer = "Stand on the gold Buyer to sell.",
	stand_at_camp = "Stand at Camp to buy the temporary shovel.",
	full_capacity = "Bucket full! Sift your dirt at the River.",
	full_output = "Find bag full! Sell finished finds at the Buyer.",
	no_dirt = "No dirt to sift. Dig at the Bank first.",
	nothing_to_sell = "No finished finds. Sift your dirt at the River first.",
	unaffordable = "Not enough Run Cash. Sell finished finds to earn more.",
	already_owned = "You already own this shift's shovel upgrade.",
	duplicate_request = "That request was already handled. Nothing was charged twice.",
	busy_sifting = "Finish this sift or cancel it before digging.",
	busy_digging = "Wait for this dig to finish, or cancel it.",
	over_rate = "Your dig is already in progress. Wait for it to finish.",
	stale_check = "That timing check has ended. Watch the current needle.",
	outside_check = "That check is not active. Watch the current needle.",
	already_graded = "Hit recorded. Wait for the next check.",
	stale_run = "That shift already ended. Use the current results screen.",
	started = "Action started!",
	sifting = "Next check — watch the needle!",
	cancelled = "Action cancelled. Incomplete sift dirt is discarded.",
	perfect = "PERFECT!",
	good = "GOOD!",
	miss = "Miss — keep going!",
	expired = "Missed check — keep going!",
	completed = "Find ready! Take it to the Buyer.",
	purchased = "Shovel upgraded! Temporary for this shift.",
	ready = "Ready for a fresh shift!",
	settled = "Shift ended. Unsold finds discarded without payment.",
	idle = "No action in progress.",
	replayed = "Fresh shift! Inventory, cash and upgrades reset.",
	created = "Dirt ready! Take it to the River.",
	sold = "Finished finds sold!",
})
-- One line per contributing player for the results screen; zero totals are left out.
function Hud.credits(rows)
	if #rows == 0 then
		return "No contributions this shift."
	end
	local lines = {}
	for _, row in rows do
		local parts = {}
		if row.dug > 0 then
			table.insert(parts, string.format("dug %d", row.dug))
		end
		if row.processed > 0 then
			table.insert(parts, string.format("sifted %d", row.processed))
		end
		if row.loaded > 0 then
			table.insert(parts, string.format("sluice %d", row.loaded))
		end
		if row.sold > 0 then
			table.insert(parts, string.format("sold $%d", row.sold))
		end
		if row.funded > 0 then
			table.insert(parts, string.format("funded $%d", row.funded))
		end
		assert(#parts > 0, "Hud: credit row without contributions for " .. row.name)
		table.insert(lines, row.name .. ": " .. table.concat(parts, " · "))
	end
	return table.concat(lines, "\n")
end
function Hud.message(code)
	assert(Hud.messages[code], "Hud: missing feedback for " .. tostring(code))
	return Hud.messages[code]
end
function Hud.timeline(phase, bankSeconds, rushSeconds, remaining)
	local function time(seconds)
		assert(type(seconds) == "number" and seconds >= 0, "Hud: invalid timeline countdown")
		return string.format("%02d:%02d", math.floor(seconds / 60), seconds % 60)
	end
	local bank
	if phase == "day" then
		bank = "Rich bank opens in " .. time(bankSeconds)
	elseif phase == "night" then
		bank = "Rich bank OPEN • closes in " .. time(bankSeconds)
	elseif phase == "dawn" or phase == "rush" or phase == "ended" then
		bank = "Rich bank CLOSED • saved rich dirt keeps its bonus"
	else
		error("Hud: unknown timeline phase " .. tostring(phase))
	end
	local rush = if phase == "rush" or phase == "ended"
		then "Rush ends in " .. time(remaining)
		else "Rush in " .. time(rushSeconds)
	return bank
		.. " • "
		.. rush
		.. "\nSell before the bell! Unsold finds and unfinished dirt are discarded without payment."
end
return Hud
