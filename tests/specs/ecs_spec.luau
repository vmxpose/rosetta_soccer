--!nonstrict
local Snapshot = require("../../src/shared/Ecs/Snapshot")
local World = require("../../src/shared/Ecs/World")

return function(t)
	t.case("spawn assigns ascending ids and stores components", function()
		local world = World.new("test")
		local a = world:spawn({ Position = { x = 1 } })
		local b = world:spawn({ Position = { x = 2 }, Tag = { name = "b" } })
		t.eq(a, 1)
		t.eq(b, 2)
		t.eq(world:get(b, "Position").x, 2)
		t.eq(world:get(a, "Tag"), nil)
		t.ok(world:has(b, "Position", "Tag"))
		t.ok(not world:has(a, "Tag"))
	end)

	t.case("client id base keeps local entities out of server range", function()
		local world = World.new("client", { idBase = 1_000_000 })
		t.eq(world:spawn({}), 1_000_000)
		world:spawnWithId(7, { Mirrored = true })
		t.ok(world:isAlive(7))
		t.fails(function()
			world:spawnWithId(7, {})
		end, "duplicate spawnWithId must error")
	end)

	t.case("despawn clears all components and counts", function()
		local world = World.new("test")
		local id = world:spawn({ A = { v = 1 }, B = { v = 2 } })
		t.eq(world:count("A"), 1)
		world:despawn(id)
		t.eq(world:count("A"), 0)
		t.eq(world:get(id, "A"), nil)
		t.ok(not world:isAlive(id))
	end)

	t.case("query iterates matching entities in ascending id order", function()
		local world = World.new("test")
		for i = 1, 5 do
			world:spawn(if i % 2 == 1 then { A = { i = i }, B = { i = i } } else { A = { i = i } })
		end
		local seen = {}
		for id, a, b in world:query("A", "B") do
			table.insert(seen, id)
			t.eq(a.i, id)
			t.eq(b.i, id)
		end
		t.eq(seen, { 1, 3, 5 })
	end)

	t.case("query result unaffected by argument order", function()
		local world = World.new("test")
		world:spawn({ A = {}, B = {} })
		world:spawn({ B = {} })
		local count = 0
		for _ in world:query("B", "A") do
			count += 1
		end
		t.eq(count, 1)
	end)

	t.case("resources are world singletons", function()
		local world = World.new("test")
		t.eq(world:resource("tick"), nil)
		world:setResource("tick", 42)
		t.eq(world:resource("tick"), 42)
	end)

	t.case("snapshot capture/restore roundtrip", function()
		local world = World.new("test")
		local id = world:spawn({ Ball = { pos = { x = 1, y = 2 }, motion = 0 } })
		local snap = Snapshot.capture(world, { "Ball" })

		world:get(id, "Ball").pos.x = 99 -- captured copy must be isolated
		t.eq(snap.entities[id].Ball.pos.x, 1)

		world:spawn({ Ball = { pos = { x = 5, y = 5 }, motion = 1 } }) -- stale entity
		Snapshot.restore(world, snap, { "Ball" })
		t.eq(world:count("Ball"), 1)
		t.eq(world:get(id, "Ball").pos.x, 1)
	end)
end
