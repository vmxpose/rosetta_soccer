--!strict
-- Fixed-timestep system scheduler. Pure Luau: the host (Bootstrap) feeds it Heartbeat/RenderStepped
-- deltas, so the same scheduler drives the authoritative server sim and the client's prediction sim,
-- and lune tests can step it synthetically.
--
-- Simulation stage: fixed SIM_DT steps via accumulator, with a catch-up limit — time beyond
-- maxCatchUpSteps per frame is dropped (never spiral). Render stage: once per frame with
-- alpha = accumulator remainder / simDt for interpolation.
--
-- Systems are plain tables { name, step } registered in an explicit ordered array:
-- the registration site documents execution order. No priorities, no sorting.

export type System = {
	name: string,
	step: (world: any, dt: number, alpha: number?) -> (),
}

export type Timing = { name: string, lastMs: number, avgMs: number }

local Scheduler = {}
Scheduler.__index = Scheduler

export type Scheduler = typeof(setmetatable(
	{} :: {
		simDt: number,
		maxCatchUpSteps: number,
		tick: number,
		_accumulator: number,
		_simSystems: { System },
		_renderSystems: { System },
		_timings: { [string]: Timing },
	},
	Scheduler
))

local profileBegin = (debug :: any) and (debug :: any).profilebegin or nil
local profileEnd = (debug :: any) and (debug :: any).profileend or nil

function Scheduler.new(opts: { simDt: number, maxCatchUpSteps: number }): Scheduler
	assert(opts.simDt > 0, "simDt must be positive")
	return setmetatable({
		simDt = opts.simDt,
		maxCatchUpSteps = opts.maxCatchUpSteps,
		tick = 0,
		_accumulator = 0,
		_simSystems = {},
		_renderSystems = {},
		_timings = {},
	}, Scheduler)
end

function Scheduler.addSimSystem(self: Scheduler, system: System)
	table.insert(self._simSystems, system)
	self._timings[system.name] = { name = system.name, lastMs = 0, avgMs = 0 }
end

function Scheduler.addRenderSystem(self: Scheduler, system: System)
	table.insert(self._renderSystems, system)
	self._timings[system.name] = { name = system.name, lastMs = 0, avgMs = 0 }
end

local function runSystem(self: Scheduler, system: System, world: any, dt: number, alpha: number?)
	local timing = self._timings[system.name]
	if profileBegin then
		profileBegin(system.name)
	end
	local t0 = os.clock()
	system.step(world, dt, alpha)
	local ms = (os.clock() - t0) * 1000
	if profileEnd then
		profileEnd()
	end
	timing.lastMs = ms
	timing.avgMs = timing.avgMs + 0.05 * (ms - timing.avgMs)
end

-- Feed a frame delta; runs 0..maxCatchUpSteps fixed sim steps. Returns steps run.
function Scheduler.heartbeat(self: Scheduler, world: any, dt: number): number
	self._accumulator += dt
	local steps = 0
	while self._accumulator >= self.simDt do
		if steps >= self.maxCatchUpSteps then
			-- Drop time we cannot catch up on; keep only the sub-step remainder.
			self._accumulator = self._accumulator % self.simDt
			break
		end
		self._accumulator -= self.simDt
		self.tick += 1
		world:setResource("tick", self.tick)
		for _, system in self._simSystems do
			runSystem(self, system, world, self.simDt)
		end
		steps += 1
	end
	return steps
end

function Scheduler.render(self: Scheduler, world: any, dt: number)
	local alpha = self._accumulator / self.simDt
	for _, system in self._renderSystems do
		runSystem(self, system, world, dt, alpha)
	end
end

function Scheduler.alpha(self: Scheduler): number
	return self._accumulator / self.simDt
end

function Scheduler.timings(self: Scheduler): { [string]: Timing }
	return self._timings
end

return Scheduler
