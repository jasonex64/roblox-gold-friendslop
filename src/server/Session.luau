--!strict
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Run = require(Shared.Pure.Run)
local Settlement = require(Shared.Pure.Settlement)
local Hud = require(Shared.Pure.Hud)
local validate = require(Shared.Pure.ValidateConfig)
local Crew = require(Shared.Pure.Crew)
local Bin = require(Shared.Pure.Bin)

local Session = {}

-- Clock and identity are injected by the server, never by a RemoteEvent.
function Session.new(config, clock: () -> number, runId: string)
	validate(config)
	local session = { run = Run.new(runId, clock(), config), crew = Crew.new(config) }
	session.bin = Bin.new(config, session.crew)
	function session.advance(ready: boolean)
		Run.advance(session.run, clock(), ready)
		if session.run.startedAt and not session.crew.locked then
			session.crew.start(session.run.startedAt)
			session.bin.start(session.run.id, #session.crew.members())
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
		session.bin.clear()
		return Settlement.finish(session.run, entries, Run, session.crew.haul)
	end
	function session.reset()
		session.bin.reset()
		session.crew.reset()
		session.run = Run.reset(session.run)
	end
	function session.remaining()
		return Hud.remaining(session.run, clock())
	end
	return session
end

return Session
