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
	elseif s.station == "Bank" then
		if s.carried >= config.bucketBatches then
			return "none", "Bucket full! Walk to the blue River and sift."
		end
		return "dig", "Dig one batch, then walk to the blue River."
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
	invalid_request = "That action was not accepted. Use the on-screen controls.",
	wrong_phase = "Production is closed. Wait for the next shift.",
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
function Hud.message(code)
	assert(Hud.messages[code], "Hud: missing feedback for " .. tostring(code))
	return Hud.messages[code]
end
return Hud
