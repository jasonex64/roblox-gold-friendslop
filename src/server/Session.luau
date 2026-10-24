--!strict
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Run = require(Shared.Pure.Run)
local Settlement = require(Shared.Pure.Settlement)
local Hud = require(Shared.Pure.Hud)
local validate = require(Shared.Pure.ValidateConfig)
local Crew = require(Shared.Pure.Crew)
local Bin = require(Shared.Pure.Bin)
local Machine = require(Shared.Pure.Machine)
local Sluice = require(Shared.Pure.Sluice)
local Batch = require(Shared.Pure.Batch)
local Contributions = require(Shared.Pure.Contributions)

local Session = {}

-- Clock and identity are injected by the server, never by a RemoteEvent.
function Session.new(config, clock: () -> number, runId: string)
	validate(config)
	local session = { run = Run.new(runId, clock(), config), crew = Crew.new(config) }
	session.bin = Bin.new(config, session.crew)
	session.machine = Machine.new(config, Sluice, Batch)
	session.credit = Contributions.new()
	-- Display names are kept so players who leave still appear on the results screen.
	session.creditNames = {}
	function session.record(player, kind: string, amount: number, eventId: string)
		local id = tostring(player.UserId)
		local credit, reason = Contributions.record(session.credit, id, kind, amount, eventId)
		assert(reason == nil, "Session: duplicate credit event " .. eventId)
		session.credit = credit
		session.creditNames[id] = player.DisplayName
	end
	function session.creditRows()
		local rows = {}
		for _, row in Contributions.summary(session.credit) do
			local name = session.creditNames[row.player]
			assert(name, "Session: credit name missing for " .. row.player)
			local totals = row.totals
			table.insert(rows, {
				name = name,
				dug = totals.dug,
				processed = totals.processed,
				loaded = totals.loaded,
				sold = totals.sold,
				funded = totals.funded,
			})
		end
		return rows
	end
	function session.advance(ready: boolean)
		Run.advance(session.run, clock(), ready)
		if session.run.startedAt and not session.crew.locked then
			session.crew.start(session.run.startedAt)
			session.bin.start(session.run.id, #session.crew.members())
			session.machine.start(#session.crew.members())
		end
	end
	-- Future production handlers must call this gate with the current server clock.
	function session.accepts(): boolean
		return Run.accepts(session.run, clock())
	end
	function session.acceptsPlayer(player): boolean
		return session.accepts() and session.crew.admitted[tostring(player.UserId)] == true
	end
	function session.activity(player)
		session.crew.activity(tostring(player.UserId), clock())
	end
	function session.now()
		return clock()
	end
	function session.finish(entries)
		session.machine.clear()
		session.bin.clear()
		return Settlement.finish(session.run, entries, Run, session.crew.haul)
	end
	function session.reset()
		session.machine.clear()
		session.bin.reset()
		session.crew.reset()
		session.credit = Contributions.new()
		session.creditNames = {}
		session.run = Run.reset(session.run)
	end
	function session.remaining()
		return Hud.remaining(session.run, clock())
	end
	return session
end

return Session
