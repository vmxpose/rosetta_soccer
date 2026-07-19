--!strict
-- Intent sequence numbers. Client side hands out monotonically increasing sequence ids;
-- server side rejects duplicates and stale arrivals per sender. Pure Luau.

local Sequencer = {}

local ClientSeq = {}
ClientSeq.__index = ClientSeq

export type ClientSeq = typeof(setmetatable({} :: { _next: number }, ClientSeq))

function Sequencer.client(): ClientSeq
	return setmetatable({ _next = 1 }, ClientSeq)
end

function ClientSeq.next(self: ClientSeq): number
	local seq = self._next
	self._next += 1
	return seq
end

local ServerSeq = {}
ServerSeq.__index = ServerSeq

export type ServerSeq = typeof(setmetatable({} :: { _lastProcessed: { [any]: number } }, ServerSeq))

function Sequencer.server(): ServerSeq
	return setmetatable({ _lastProcessed = {} }, ServerSeq)
end

-- Returns true exactly once per (sender, seq), and only for ascending seq.
function ServerSeq.accept(self: ServerSeq, sender: any, seq: number): boolean
	local last = self._lastProcessed[sender] or 0
	if seq <= last then
		return false
	end
	self._lastProcessed[sender] = seq
	return true
end

function ServerSeq.forget(self: ServerSeq, sender: any)
	self._lastProcessed[sender] = nil
end

return Sequencer
