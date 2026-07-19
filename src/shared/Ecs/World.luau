--!strict
-- Entity/component registry. Sparse per-component storage ({ [entityId]: data }),
-- sized for this game's entity count (~25): optimized for debuggability, not iteration speed.
-- Pure Luau — no Roblox APIs — so it runs identically on server, client, and in lune tests.

export type Id = number

local World = {}
World.__index = World

export type World = typeof(setmetatable(
	{} :: {
		name: string,
		_nextId: Id,
		_alive: { [Id]: true },
		_aliveCount: number,
		_stores: { [string]: { [Id]: any } },
		_counts: { [string]: number },
		_resources: { [string]: any },
	},
	World
))

function World.new(name: string, opts: { idBase: Id }?): World
	return setmetatable({
		name = name,
		_nextId = if opts then opts.idBase else 1,
		_alive = {},
		_aliveCount = 0,
		_stores = {},
		_counts = {},
		_resources = {},
	}, World)
end

function World.spawn(self: World, components: { [string]: any }): Id
	local id = self._nextId
	self._nextId += 1
	self._alive[id] = true
	self._aliveCount += 1
	for name, data in components do
		self:set(id, name, data)
	end
	return id
end

-- Mirror an entity whose id was allocated elsewhere (e.g. client mirroring server ids).
function World.spawnWithId(self: World, id: Id, components: { [string]: any })
	assert(self._alive[id] == nil, `entity {id} already exists in world "{self.name}"`)
	self._alive[id] = true
	self._aliveCount += 1
	for name, data in components do
		self:set(id, name, data)
	end
end

function World.despawn(self: World, id: Id)
	if self._alive[id] == nil then
		return
	end
	for name, store in self._stores do
		if store[id] ~= nil then
			store[id] = nil
			self._counts[name] -= 1
		end
	end
	self._alive[id] = nil
	self._aliveCount -= 1
end

function World.isAlive(self: World, id: Id): boolean
	return self._alive[id] == true
end

function World.get(self: World, id: Id, name: string): any
	local store = self._stores[name]
	return if store then store[id] else nil
end

function World.set(self: World, id: Id, name: string, data: any)
	assert(data ~= nil, `set(nil) for component "{name}" — use remove()`)
	local store = self._stores[name]
	if store == nil then
		store = {}
		self._stores[name] = store
		self._counts[name] = 0
	end
	if store[id] == nil then
		self._counts[name] += 1
	end
	store[id] = data
	if self._alive[id] == nil then
		self._alive[id] = true
		self._aliveCount += 1
	end
end

function World.remove(self: World, id: Id, name: string)
	local store = self._stores[name]
	if store and store[id] ~= nil then
		store[id] = nil
		self._counts[name] -= 1
	end
end

function World.has(self: World, id: Id, ...: string): boolean
	for i = 1, select("#", ...) do
		local name = select(i, ...)
		local store = self._stores[name]
		if store == nil or store[id] == nil then
			return false
		end
	end
	return true
end

function World.count(self: World, name: string?): number
	if name == nil then
		return self._aliveCount
	end
	return self._counts[name] or 0
end

-- Iterate entities having ALL named components, ascending entity id (deterministic).
-- Usage: for id, a, b in world:query("A", "B") do ... end
function World.query(self: World, ...: string): () -> (Id?, ...any)
	local names = { ... }
	assert(#names > 0, "query() needs at least one component name")
	local smallestName = names[1]
	for _, n in names do
		if (self._counts[n] or 0) < (self._counts[smallestName] or 0) then
			smallestName = n
		end
	end
	local base = self._stores[smallestName] or {}
	local ids: { Id } = {}
	for id in base do
		table.insert(ids, id)
	end
	table.sort(ids)

	local i = 0
	local n = #names
	return function(): (Id?, ...any)
		while true do
			i += 1
			local id = ids[i]
			if id == nil then
				return nil
			end
			local results = table.create(n)
			local ok = true
			for j, name in names do
				local store = self._stores[name]
				local data = if store then store[id] else nil
				if data == nil then
					ok = false
					break
				end
				results[j] = data
			end
			if ok then
				return id, table.unpack(results, 1, n)
			end
		end
	end
end

-- Singletons (match state, clocks, net stats). Explicit resources instead of fake entities.
function World.resource(self: World, name: string): any
	return self._resources[name]
end

function World.setResource(self: World, name: string, value: any)
	self._resources[name] = value
end

return World
