--!nonstrict
local CollisionWorld = require("../../src/shared/Sim/CollisionWorld")

-- FakePitch: the deterministic analytic collision world lune tests run the ball sim against.
-- Ground plane at y=0 plus two walls; same implementation Studio uses for pitch bounds.
local function fakePitch()
	return CollisionWorld.fromPlanes({
		{ point = vector.zero, normal = vector.create(0, 1, 0), name = "ground" },
		{ point = vector.create(50, 0, 0), normal = vector.create(-1, 0, 0), name = "east wall" },
		{ point = vector.create(-50, 0, 0), normal = vector.create(1, 0, 0), name = "west wall" },
	})
end

return function(t)
	local RADIUS = 1

	t.case("falling sphere hits the ground when its surface reaches it", function()
		local pitch = fakePitch()
		local hit = pitch.sweepSphere(vector.create(0, 5, 0), vector.create(0, -10, 0), RADIUS)
		t.ok(hit ~= nil)
		t.ok(hit.normal == vector.create(0, 1, 0))
		t.near(hit.position.y, 1, 1e-6, "center stops one radius above the plane")
		t.near(hit.distance, 4, 1e-6)
	end)

	t.case("sphere moving parallel to a plane does not hit it", function()
		local pitch = fakePitch()
		local hit = pitch.sweepSphere(vector.create(0, 5, 0), vector.create(10, 0, 0), RADIUS)
		t.eq(hit, nil)
	end)

	t.case("sphere moving away from a nearby plane does not hit it", function()
		local pitch = fakePitch()
		local hit = pitch.sweepSphere(vector.create(0, 1.01, 0), vector.create(0, 5, 0), RADIUS)
		t.eq(hit, nil)
	end)

	t.case("sphere already in contact and approaching reports distance 0", function()
		local pitch = fakePitch()
		local hit = pitch.sweepSphere(vector.create(0, 0.5, 0), vector.create(0, -1, 0), RADIUS)
		t.ok(hit ~= nil)
		t.eq(hit.distance, 0)
	end)

	t.case("nearest of several planes wins", function()
		local pitch = fakePitch()
		-- Diagonal move toward both ground and east wall; wall clearance 1.5 < ground clearance 2.
		local hit = pitch.sweepSphere(vector.create(47.5, 3, 0), vector.create(10, -10, 0), RADIUS)
		t.ok(hit ~= nil)
		t.ok(hit.normal == vector.create(-1, 0, 0), "east wall should be the first contact")
	end)

	t.case("short move stopping before contact reports no hit", function()
		local pitch = fakePitch()
		local hit = pitch.sweepSphere(vector.create(0, 5, 0), vector.create(0, -1, 0), RADIUS)
		t.eq(hit, nil)
	end)

	t.case("union returns the nearest hit across worlds", function()
		local ground = CollisionWorld.fromPlanes({ { point = vector.zero, normal = vector.create(0, 1, 0) } })
		local ceiling =
			CollisionWorld.fromPlanes({ { point = vector.create(0, 3, 0), normal = vector.create(0, -1, 0) } })
		local both = CollisionWorld.union(ground, ceiling)
		local hit = both.sweepSphere(vector.create(0, 2.5, 0), vector.create(0, 5, 0), 0.25)
		t.ok(hit ~= nil)
		t.ok(hit.normal == vector.create(0, -1, 0), "ceiling is the approached surface")
	end)
end
