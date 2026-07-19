--!nonstrict
-- Contract spec for the Luau native `vector` library: the sim's pure math is written against
-- these exact semantics, which must hold in BOTH lune (this run) and Roblox (where `vector`
-- values are Vector3s). If this spec fails in either runtime, add a Vec shim before writing
-- more math — do not paper over per-runtime differences at call sites.

return function(t)
	t.case("create and component access", function()
		local v = vector.create(1, 2, 3)
		t.eq(v.x, 1)
		t.eq(v.y, 2)
		t.eq(v.z, 3)
	end)

	t.case("value equality", function()
		t.ok(vector.create(1, 2, 3) == vector.create(1, 2, 3))
		t.ok(vector.zero == vector.create(0, 0, 0))
	end)

	t.case("arithmetic", function()
		local v = vector.create(1, 2, 3) + vector.create(10, 20, 30)
		t.ok(v == vector.create(11, 22, 33))
		t.ok(vector.create(1, 2, 3) * 2 == vector.create(2, 4, 6))
		t.ok(vector.create(2, 4, 6) / 2 == vector.create(1, 2, 3))
		t.ok(-vector.create(1, 2, 3) == vector.create(-1, -2, -3))
	end)

	t.case("dot, cross, magnitude, normalize", function()
		t.eq(vector.dot(vector.create(1, 2, 3), vector.create(4, 5, 6)), 32)
		t.ok(vector.cross(vector.create(1, 0, 0), vector.create(0, 1, 0)) == vector.create(0, 0, 1))
		t.eq(vector.magnitude(vector.create(3, 4, 0)), 5)
		t.ok(vector.normalize(vector.create(10, 0, 0)) == vector.create(1, 0, 0))
	end)
end
