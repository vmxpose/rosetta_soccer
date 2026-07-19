--!nonstrict
local Clock = require("../../src/shared/Net/Clock")

local DT = 1 / 60

return function(t)
	t.case("unsynced clock reports and passes through local time", function()
		local clock = Clock.new(DT, 0.1)
		t.ok(not clock:isSynced())
		t.eq(clock:serverTimeAt(5), 5)
	end)

	t.case("first observation snaps the offset", function()
		local clock = Clock.new(DT, 0.1)
		clock:observe(600, 0) -- server is 10 s ahead of local clock zero
		t.ok(clock:isSynced())
		t.near(clock:serverTimeAt(0), 10, 1e-9)
		t.eq(clock:serverTickAt(0), 600)
	end)

	t.case("EMA converges toward a shifted offset", function()
		local clock = Clock.new(DT, 0.1)
		clock:observe(600, 0)
		-- Server ticks arrive as if the true offset were 11 s from now on.
		for i = 1, 200 do
			local localTime = i * 0.05
			local serverTick = math.floor((localTime + 11) / DT)
			clock:observe(serverTick, localTime)
		end
		t.near(clock:serverTimeAt(0), 11, 0.05)
	end)

	t.case("tick estimates advance with local time", function()
		local clock = Clock.new(DT, 0.1)
		clock:observe(120, 0)
		t.eq(clock:serverTickAt(1), 180)
	end)
end
