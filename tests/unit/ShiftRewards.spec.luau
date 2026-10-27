--!strict
-- Execute the actual server modules and shared Studio fixture with injected services.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local serde = require("@lune/serde")
local pure = {}
pure.Run = require("../../src/shared/Pure/Run")
pure.Settlement = require("../../src/shared/Pure/Settlement")
pure.Hud = require("../../src/shared/Pure/Hud")
pure.ValidateConfig = require("../../src/shared/Pure/ValidateConfig")
pure.Crew = require("../../src/shared/Pure/Crew")
pure.Bin = require("../../src/shared/Pure/Bin")
pure.Machine = require("../../src/shared/Pure/Machine")
pure.Sluice = require("../../src/shared/Pure/Sluice")
pure.Batch = require("../../src/shared/Pure/Batch")
pure.Contributions = require("../../src/shared/Pure/Contributions")
pure.Timeline = require("../../src/shared/Pure/Timeline")
pure.Participation = require("../../src/shared/Pure/Participation")
pure.Profile = require("../../src/shared/Pure/Profile")
pure.RunRewards = require("../../src/shared/Pure/RunRewards")
local shared = { Pure = pure, Config = require("../../src/shared/Config") }
local http = {
	JSONEncode = function(_, value)
		return serde.encode("json", value)
	end,
	JSONDecode = function(_, value)
		return serde.decode("json", value)
	end,
}
local game = { ReplicatedStorage = { Shared = shared }, ServerScriptService = { Server = {} } }
function game:GetService(name)
	if name == "ReplicatedStorage" then
		return {
			WaitForChild = function()
				return shared
			end,
		}
	end
	if name == "HttpService" then
		return http
	end
	assert(name == "Players", "unexpected service " .. name)
	return {
		GetPlayers = function()
			return {}
		end,
	}
end
local function loadServer(name)
	return luau.load(fs.readFile("src/server/" .. name .. ".luau"), {
		debugName = name,
		environment = {
			game = game,
			require = function(module)
				return module
			end,
		},
		injectGlobals = true,
	})()
end
local function module(value)
	return {
		Clone = function()
			return value
		end,
	}
end
local server = game.ServerScriptService.Server
server.Session = module(loadServer("Session"))
server.Shift = module(loadServer("Shift"))
server.RewardFlow = module(require("../../src/server/RewardFlow"))
server.Progression = module(require("../../src/server/Progression"))
-- Fixture clones these pure modules too. Destroy is only fixture cleanup.
for _, value in
	{
		pure.Profile,
		pure.RunRewards,
		server.Session:Clone(),
		server.Shift:Clone(),
		server.RewardFlow:Clone(),
		server.Progression:Clone(),
	}
do
	value.Destroy = function() end
end
pure.Profile = module(pure.Profile)
pure.RunRewards = module(pure.RunRewards)
return {
	["SHIFT actual Session and Shift retain offline rewards, block failed replay and reset safely"] = function(
		t
	)
		local result = luau.load(fs.readFile("tests/studio/GateDRewards.luau"), {
			debugName = "GateDRewards",
			injectGlobals = true,
			environment = {
				game = game,
				require = function(value)
					return value
				end,
				Instance = {
					new = function()
						local attrs = {}
						return {
							SetAttribute = function(_, key, value)
								attrs[key] = value
							end,
							GetAttribute = function(_, key)
								return attrs[key]
							end,
							Destroy = function() end,
						}
					end,
				},
			},
		})()
		t.equal(string.find(result, "PASS") ~= nil, true)
	end,
}
