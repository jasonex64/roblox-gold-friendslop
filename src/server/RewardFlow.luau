--!strict
-- Storage integration with injected service/scheduler: never yields in heartbeat.
-- Explicit retry/load/shutdown requests each make one attempt; no retry loops.
local RewardFlow = {}
function RewardFlow.new(service, build, config, schedule, publish)
	local self = { profiles = {}, jobs = {}, busy = {} }
	local function update(id, status, profile)
		self.profiles[id] = { status = status, profile = profile }
		publish(id, self.profiles[id])
	end
	local function applyJob(id, job)
		job.status = "pending"
		publish(id, self.profiles[id])
		local stored = service.store(job.manifest)
		if stored.status == "failed" then
			job.status, job.reason = "failed", stored.reason
			return false
		end
		assert(
			stored.status == "pending" or stored.status == "alreadyApplied",
			"RewardFlow: unexpected store outcome"
		)
		job.durable = true
		local applied = if stored.status == "alreadyApplied"
			then stored
			else service.apply(id, job.manifest.runId)
		if applied.status == "failed" then
			job.status, job.reason = "failed", applied.reason
			return false
		end
		assert(
			applied.status == "saved" or applied.status == "alreadyApplied",
			"RewardFlow: unexpected apply outcome"
		)
		job.status, job.reason = "saved", nil
		update(id, "loaded", applied.profile)
		return true
	end
	function self.recover(id)
		if self.busy[id] then
			return "busy"
		end
		self.busy[id] = true
		update(id, "loading", nil)
		schedule(function()
			local loaded = service.pending(id)
			if loaded.status == "failed" then
				update(id, "failed", nil)
			else
				assert(loaded.status == "loaded", "RewardFlow: unexpected load outcome")
				local profile = loaded.profile
				local ok = true
				for _, manifest in loaded.manifests do
					local applied = service.apply(id, manifest.runId)
					if applied.status == "failed" then
						ok = false
					else
						assert(
							applied.status == "saved" or applied.status == "alreadyApplied",
							"RewardFlow: unexpected recovery outcome"
						)
						profile = applied.profile
					end
				end
				update(id, if ok then "loaded" else "failed", if ok then profile else nil)
				if ok then
					for _, jobs in self.jobs do
						local job = jobs[id]
						if job and job.status ~= "saved" then
							applyJob(id, job)
						end
					end
				end
			end
			self.busy[id] = nil
			publish(id, self.profiles[id])
		end)
		return "requested"
	end
	function self.ready(id)
		local p = self.profiles[id]
		return p ~= nil and p.status == "loaded" and not self.busy[id]
	end
	function self.finish(snapshot)
		if self.jobs[snapshot.runId] then
			return "already_started"
		end
		for runId, previous in self.jobs do
			local complete = true
			for _, job in previous do
				if job.status ~= "saved" then
					complete = false
				end
			end
			if complete then
				self.jobs[runId] = nil
			end
		end
		local jobs = {}
		for id, manifest in build(snapshot, config) do
			jobs[id] = { manifest = manifest, status = "pending", durable = false }
		end
		self.jobs[snapshot.runId] = jobs
		for id in jobs do
			self.recover(id)
		end
		return "started"
	end
	function self.retry(runId)
		local jobs = self.jobs[runId]
		assert(jobs, "RewardFlow: no result to recover")
		for id, job in jobs do
			if job.status ~= "saved" then
				self.recover(id)
			end
		end
		return "requested"
	end
	function self.result(runId, id)
		local jobs = self.jobs[runId]
		return if jobs then jobs[id] else nil
	end
	function self.durable(runId)
		local jobs = self.jobs[runId]
		if not jobs then
			return false
		end
		for _, job in jobs do
			if not job.durable then
				return false
			end
		end
		return true
	end
	function self.shutdown()
		-- One final attempt for retained manifests; never reset a profile on failure.
		for _, jobs in self.jobs do
			for id, job in jobs do
				if job.status ~= "saved" and not self.busy[id] then
					applyJob(id, job)
				end
			end
		end
	end
	return self
end
return RewardFlow
