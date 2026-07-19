--!strict
-- Client-side estimate of the server's sim clock. The server stamps its tick on every
-- snapshot; the client smooths (EMA) the offset between server time and its local clock.
-- All timestamped input (kick charge starts, tempo taps) maps through this. Pure Luau.

local Clock = {}
Clock.__index = Clock

export type Clock = typeof(setmetatable(
	{} :: {
		simDt: number,
		smoothing: number,
		_offset: number?, -- serverTime - localTime, seconds
	},
	Clock
))

function Clock.new(simDt: number, smoothing: number): Clock
	return setmetatable({
		simDt = simDt,
		smoothing = smoothing,
		_offset = nil,
	}, Clock)
end

function Clock.observe(self: Clock, serverTick: number, localTime: number)
	local offset = serverTick * self.simDt - localTime
	local current = self._offset
	if current == nil then
		self._offset = offset
	else
		self._offset = current + self.smoothing * (offset - current)
	end
end

function Clock.isSynced(self: Clock): boolean
	return self._offset ~= nil
end

function Clock.serverTimeAt(self: Clock, localTime: number): number
	return localTime + (self._offset or 0)
end

function Clock.serverTickAt(self: Clock, localTime: number): number
	return math.floor(self:serverTimeAt(localTime) / self.simDt + 0.5)
end

return Clock
