--!strict
local Hud = require("../../src/shared/Pure/Hud")
local Config = require("../../src/shared/Config")
local function state(station)
	return {
		phase = "running",
		alive = true,
		station = station,
		carried = 0,
		outputs = 0,
		cash = 0,
		upgraded = false,
		digging = false,
		sifting = false,
	}
end
return {
	["UX-2 timer follows configured countdown and exclusive cutoff"] = function(t)
		local run = { phase = "waiting", config = Config }
		t.equal(Hud.remaining(run, 100), 0)
		run.phase, run.readyAt = "countdown", 100
		t.equal(Hud.remaining(run, 100), Config.readySeconds)
		t.equal(Hud.remaining(run, 100 + Config.readySeconds), 0)
		run.phase, run.endsAt = "running", 700
		t.equal(Hud.remaining(run, 100), 600)
		t.equal(Hud.remaining(run, 699.1), 1)
		t.equal(Hud.remaining(run, 700), 0)
		t.equal(Hud.remaining(run, 705), 0)
		run.phase = "results"
		t.equal(Hud.remaining(run, 705), 0)
	end,
	["UX-1/2 stations and capacities produce useful contextual actions"] = function(t)
		local s = state("Bank")
		t.equal(Hud.nextAction(s, Config), "dig")
		s.carried = Config.bucketBatches
		local action, hint = Hud.nextAction(s, Config)
		t.equal(action, "none")
		t.equal(string.find(hint, "Bucket full", 1, true) ~= nil, true)
		s.station = "River"
		t.equal(Hud.nextAction(s, Config), "sift")
		s.outputs = Config.outputCapacity
		t.equal(Hud.nextAction(s, Config), "none")
		s.station = "Buyer"
		t.equal(Hud.nextAction(s, Config), "sell")
		s.outputs, s.carried = 0, 0
		t.equal(Hud.nextAction(s, Config), "none")
		s.station = "Camp"
		s.cash = Config.shovelUpgradePrice - 1
		t.equal(Hud.nextAction(s, Config), "none")
		s.cash = Config.shovelUpgradePrice
		t.equal(Hud.nextAction(s, Config), "buy")
		s.upgraded = true
		t.equal(Hud.nextAction(s, Config), "none")
	end,
	["UX-1 busy actions, death and closed phases take priority over location"] = function(t)
		local s = state("Bank")
		s.digging = true
		t.equal(Hud.nextAction(s, Config), "cancel")
		s.sifting = true
		t.equal(Hud.nextAction(s, Config), "hit")
		s.alive = false
		t.equal(Hud.nextAction(s, Config), "none")
		s.alive = true
		for _, phase in { "waiting", "countdown", "ended", "results" } do
			s.phase = phase
			t.equal(Hud.nextAction(s, Config), "none")
		end
	end,
	["UX-3 away guidance follows dirt, completed finds and affordable upgrade"] = function(t)
		local s = state("Away")
		for _, expected in { "Bank", "River", "Buyer", "Camp" } do
			local _, hint = Hud.nextAction(s, Config)
			t.equal(string.find(hint, expected, 1, true) ~= nil, true)
			if expected == "Bank" then
				s.carried = 1
			elseif expected == "River" then
				s.carried, s.outputs = 0, 1
			elseif expected == "Buyer" then
				s.outputs, s.cash = 0, Config.shovelUpgradePrice
			end
		end
	end,
	["UX-1 feedback explains rejections and unknown codes fail loudly"] = function(t)
		for _, code in
			{
				"full_capacity",
				"full_output",
				"unaffordable",
				"wrong_phase",
				"stand_at_river",
				"stand_at_buyer",
				"stand_at_camp",
				"stale_check",
				"invalid_request",
				"cancelled",
				"sifting",
			}
		do
			t.equal(#Hud.message(code) > 10, true)
		end
		t.errors(function()
			Hud.message("unhandled")
		end)
	end,
	["RESULT-1 credit lines list each contributor and leave out zero totals"] = function(t)
		local text = Hud.credits({
			{ name = "Ana", dug = 12, processed = 8, loaded = 0, sold = 240, funded = 0 },
			{ name = "Ben", dug = 0, processed = 0, loaded = 3, sold = 0, funded = 200 },
		})
		t.equal(text, "Ana: dug 12 · sifted 8 · sold $240\nBen: sluice 3 · funded $200")
		t.errors(function()
			Hud.credits({
				{ name = "Cat", dug = 0, processed = 0, loaded = 0, sold = 0, funded = 0 },
			})
		end)
	end,
	["RESULT-2 an empty shift says so instead of showing a blank list"] = function(t)
		t.equal(Hud.credits({}), "No contributions this shift.")
	end,
	["SLUICE-UI-1 the sluice's main action is funding until it is built"] = function(t)
		local s = state("Sluice")
		s.sluiceBuilt = false
		local action, hint = Hud.nextAction(s, Config)
		t.equal(action, "fund_sluice")
		t.equal(string.find(hint, "Run Cash", 1, true) ~= nil, true)
		s.sluiceBuilt = true
		t.equal(Hud.nextAction(s, Config), "open_sluice")
	end,
}
