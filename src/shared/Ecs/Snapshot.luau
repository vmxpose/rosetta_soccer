--!strict
-- Capture/restore a set of component stores as plain data. One code path serves both
-- replication (server captures networked components) and debug replay (record + scrub),
-- so the two can never diverge.
--
-- Component data must be plain tables of primitives/vectors (vectors are immutable values
-- in Luau, copied by value). Tables are deep-copied.

local Snapshot = {}

export type Captured = {
	entities: { [number]: { [string]: any } },
}

local function deepCopy(value: any): any
	if type(value) ~= "table" then
		return value
	end
	local out = {}
	for k, v in value do
		out[k] = deepCopy(v)
	end
	return out
end

Snapshot.deepCopy = deepCopy

function Snapshot.capture(world: any, componentNames: { string }): Captured
	local entities: { [number]: { [string]: any } } = {}
	for _, name in componentNames do
		for id, data in world:query(name) do
			local entry = entities[id]
			if entry == nil then
				entry = {}
				entities[id] = entry
			end
			entry[name] = deepCopy(data)
		end
	end
	return { entities = entities }
end

-- After restore, the named stores contain exactly what the snapshot holds for them.
function Snapshot.restore(world: any, snap: Captured, componentNames: { string })
	for _, name in componentNames do
		local stale = {}
		for id in world:query(name) do
			table.insert(stale, id)
		end
		for _, id in stale do
			local entry = snap.entities[id]
			if entry == nil or entry[name] == nil then
				world:remove(id, name)
			end
		end
	end
	for id, entry in snap.entities do
		for _, name in componentNames do
			local data = entry[name]
			if data ~= nil then
				world:set(id, name, deepCopy(data))
			end
		end
	end
end

return Snapshot
