--!nonstrict
local Scheduler = require("../../src/shared/Ecs/Scheduler")
local World = require("../../src/shared/Ecs/World")

local DT = 1 / 60

local function makeScheduler(maxCatchUp: number?)
	return Scheduler.new({ simDt = DT, maxCatchUpSteps = maxCatchUp or 4 })
end

return function(t)
	t.case("accumulates fractional frames into fixed steps", function()
		local scheduler = makeScheduler()
		local world = World.new("test")
		local steps = 0
		scheduler:addSimSystem({
			name = "count",
			step = function()
				steps += 1
			end,
		})

		t.eq(scheduler:heartbeat(world, DT / 2), 0) -- not enough time yet
		t.eq(scheduler:heartbeat(world, DT / 2), 1) -- now exactly one step
		t.eq(steps, 1)
		t.eq(scheduler.tick, 1)
		t.eq(world:resource("tick"), 1)
	end)

	t.case("runs multiple catch-up steps for a long frame", function()
		local scheduler = makeScheduler()
		local world = World.new("test")
		scheduler:addSimSystem({ name = "noop", step = function() end })
		t.eq(scheduler:heartbeat(world, DT * 3), 3)
		t.eq(scheduler.tick, 3)
	end)

	t.case("clamps catch-up and drops excess time (no death spiral)", function()
		local scheduler = makeScheduler(4)
		local world = World.new("test")
		scheduler:addSimSystem({ name = "noop", step = function() end })
		t.eq(scheduler:heartbeat(world, DT * 100), 4)
		t.ok(scheduler:alpha() < 1, "leftover accumulator must be under one step")
		-- Dropped time stays dropped: next normal frame runs a normal number of steps.
		t.ok(scheduler:heartbeat(world, DT) <= 2)
	end)

	t.case("systems run in registration order", function()
		local scheduler = makeScheduler()
		local world = World.new("test")
		local order = {}
		for _, name in { "first", "second", "third" } do
			scheduler:addSimSystem({
				name = name,
				step = function()
					table.insert(order, name)
				end,
			})
		end
		scheduler:heartbeat(world, DT)
		t.eq(order, { "first", "second", "third" })
	end)

	t.case("render passes alpha in [0,1) and does not tick", function()
		local scheduler = makeScheduler()
		local world = World.new("test")
		local gotAlpha
		scheduler:addRenderSystem({
			name = "render",
			step = function(_w, _dt, alpha)
				gotAlpha = alpha
			end,
		})
		scheduler:heartbeat(world, DT * 1.5)
		scheduler:render(world, 0.016)
		t.near(gotAlpha, 0.5, 1e-9)
		t.eq(scheduler.tick, 1)
	end)

	t.case("per-system timings are recorded", function()
		local scheduler = makeScheduler()
		local world = World.new("test")
		scheduler:addSimSystem({ name = "work", step = function() end })
		scheduler:heartbeat(world, DT)
		t.ok(scheduler:timings().work.lastMs >= 0)
	end)
end
