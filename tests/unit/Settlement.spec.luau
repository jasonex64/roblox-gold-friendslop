--!strict
local Settlement = require("../../src/shared/Pure/Settlement")
local Run = require("../../src/shared/Pure/Run")
local Dig = require("../../src/shared/Pure/Dig")
local Sift = require("../../src/shared/Pure/Sift")
local Economy = require("../../src/shared/Pure/Economy")
local Batch = require("../../src/shared/Pure/Batch")
local Ledger = require("../../src/shared/Pure/Ledger")
local SkillCheck = require("../../src/shared/Pure/SkillCheck")
local Config = require("../../src/shared/Config")
local function setup()
	local dig = Dig.new(Config, Batch, function()
		return { kind = "Gold", baseValue = 12, sourceMultiplier = 1 }
	end)
	local sift = Sift.new(Config, dig, Batch, SkillCheck, function()
		return 0.5
	end)
	local economy = Economy.new(Config, dig, sift, Batch, Ledger)
	local run = Run.new("shift", 0, Config)
	Run.advance(run, 0, true)
	Run.advance(run, Config.readySeconds, true)
	return run, { dig = dig, sift = sift, economy = economy }
end
local function completed(entry, id, value)
	entry.dig.state.batches[id] = { id = id, status = "completed", active = false }
	entry.sift.outputs[id] = { id = id, value = value }
end
return {
	["END-1 cutoff discards unsold output without payment and preserves sold audit records"] = function(
		t
	)
		local run, entry = setup()
		completed(entry, "earlier", 60)
		entry.economy.sell("prior-sale")
		entry.economy.buy("prior-buy")
		completed(entry, "finished", 19)
		entry.dig.state.batches.raw = { id = "raw", status = "queued" }
		entry.dig.state.batches.processing =
			{ id = "processing", status = "processing", active = true }
		entry.sift.pending = { batchId = "processing" }
		entry.sift.reserved = 1
		entry.dig.sifting = true
		entry.dig.openingCount = 4
		Run.advance(run, run.endsAt, true)
		t.equal(Run.accepts(run, run.endsAt), false)
		local result = Settlement.finish(run, { entry }, Run)
		t.equal(result.haul, 60)
		t.equal(entry.economy.ledger.wallet, 10)
		t.equal(entry.dig.state.batches.finished, nil)
		t.equal(entry.dig.state.batches.earlier.status, "sold")
		t.equal(entry.dig.state.batches.raw, nil)
		t.equal(entry.dig.state.batches.processing, nil)
		t.equal(entry.sift.pending, nil)
		t.equal(entry.sift.reserved, 0)
		t.equal(entry.dig.sifting, false)
		t.equal(next(entry.sift.outputs), nil)
		t.errors(function()
			Settlement.finish(run, { entry }, Run)
		end)
		t.equal(entry.economy.ledger.requests["settlement/" .. run.id], nil)
		t.equal(entry.economy.sell("later-sale"), "nothing_to_sell")
		t.equal(entry.economy.ledger.haul, result.haul)
		t.errors(function()
			result.haul = 0
		end)
	end,
	["END-1 pending dig at cutoff cannot create a batch"] = function(t)
		local run, entry = setup()
		entry.dig.start({
			id = "too-late",
			source = "Bank",
			digger = "alice",
			now = run.endsAt - Config.digSeconds,
			distance = 0,
		}, "running")
		Run.advance(run, run.endsAt, true)
		Settlement.finish(run, { entry }, Run)
		t.equal(entry.dig.pending, nil)
		t.equal(entry.dig.step(run.endsAt, 0, "closed", "Bank"), "idle")
		t.equal(next(entry.dig.state.batches), nil)
		t.equal(entry.dig.openingCount, 0)
	end,
	["END-2 empty and purchased runs report ledger haul without reward claims"] = function(t)
		local run, entry = setup()
		Run.advance(run, run.endsAt, true)
		local result = Settlement.finish(run, { entry }, Run)
		t.equal(result.haul, 0)
		t.equal(result.runId, run.id)
		t.equal(result.saved, nil)
		t.equal(result.rewards, nil)
	end,
	["END-1 early settlement errors before selling or discarding"] = function(t)
		local run, entry = setup()
		completed(entry, "keep", 19)
		t.errors(function()
			Settlement.finish(run, { entry }, Run)
		end)
		t.equal(entry.sift.outputs.keep.value, 19)
		t.equal(entry.economy.ledger.haul, 0)
	end,
}
