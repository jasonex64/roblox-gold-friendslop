--!strict
-- Roblox adapter for the Progression store boundary. Roblox documents that data
-- store requests can fail and should be wrapped in pcall; each call returns
-- (ok, value | error message) so Progression reports an explicit failure. Getting
-- the data store is inside the pcall too: it errors when data stores are
-- unavailable (for example, an unpublished place or Studio API access off).
-- No retries here (AGENTS.md); see server/Progression for the recovery policy.
local DataStoreService = game:GetService("DataStoreService")

return function(name: string)
	return {
		read = function(key: string): (boolean, any)
			return pcall(function()
				-- GetAsync returns (value, DataStoreKeyInfo); value is nil for a missing key.
				local value = DataStoreService:GetDataStore(name):GetAsync(key)
				return value
			end)
		end,
		update = function(key: string, transform: (any) -> any): (boolean, any)
			return pcall(function()
				-- The transform must not yield; returning nil cancels the write.
				local value = DataStoreService:GetDataStore(name):UpdateAsync(key, function(current)
					return transform(current)
				end)
				return value
			end)
		end,
	}
end
