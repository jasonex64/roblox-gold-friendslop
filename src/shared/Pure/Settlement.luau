--!strict
-- Run and the authoritative per-player controllers are injected by the server.
local Settlement = {}
function Settlement.finish(run, entries, Run)
	local result
	for _, step in Run.finish(run) do
		if step == "stop_production" then
			for _, entry in entries do
				entry.dig.cancel()
			end
		elseif step == "sell_completed" then
			for _, entry in entries do
				-- Client sale IDs are GUIDs; this namespace is reserved to settlement.
				entry.economy.sell("settlement/" .. run.id)
			end
		elseif step == "discard_unprocessed" then
			for _, entry in entries do
				entry.sift.cancel()
				local state = table.clone(entry.dig.state)
				local retained = {}
				for id, batch in state.batches do
					if batch.status == "sold" then
						retained[id] = batch
					else
						assert(
							batch.status == "queued" or batch.status == "processing",
							"Settlement: unsold completed batch " .. id
						)
					end
				end
				state.batches = retained
				state.phase = "results"
				entry.dig.state = state
			end
		elseif step == "freeze_result" then
			local haul = 0
			for _, entry in entries do
				haul += entry.economy.ledger.haul
			end
			result = table.freeze({ runId = run.id, haul = haul })
		else
			error("Settlement: unknown step " .. step)
		end
	end
	assert(result, "Settlement: missing result")
	return result
end
return Settlement
