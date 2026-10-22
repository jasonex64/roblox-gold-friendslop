--!strict
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Run = require(Shared.Pure.Run)
local validate = require(Shared.Pure.ValidateConfig)

local Session = {}

-- Clock and identity are injected by the server, never by a RemoteEvent.
function Session.new(config, clock: () -> number, runId: string)
	validate(config)
	local run = Run.new(runId, clock(), config)
	local session = { run = run }
	function session.advance(ready: boolean)
		Run.advance(run, clock(), ready)
	end
	-- Future production handlers must call this gate with the current server clock.
	function session.accepts(): boolean
		return Run.accepts(run, clock())
	end
	return session
end

return Session
