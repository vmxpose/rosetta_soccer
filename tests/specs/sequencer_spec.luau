--!nonstrict
local Sequencer = require("../../src/shared/Net/Sequencer")

return function(t)
	t.case("client sequences increase monotonically from 1", function()
		local seq = Sequencer.client()
		t.eq(seq:next(), 1)
		t.eq(seq:next(), 2)
		t.eq(seq:next(), 3)
	end)

	t.case("server accepts ascending, rejects duplicate and stale", function()
		local seq = Sequencer.server()
		t.ok(seq:accept("player1", 1))
		t.ok(seq:accept("player1", 2))
		t.ok(not seq:accept("player1", 2), "duplicate must be rejected")
		t.ok(not seq:accept("player1", 1), "stale must be rejected")
		t.ok(seq:accept("player1", 5), "gaps are fine (unreliable path)")
		t.ok(not seq:accept("player1", 4), "arrivals behind the high-water mark are stale")
	end)

	t.case("senders are tracked independently and can be forgotten", function()
		local seq = Sequencer.server()
		t.ok(seq:accept("a", 3))
		t.ok(seq:accept("b", 1), "per-sender tracking")
		seq:forget("a")
		t.ok(seq:accept("a", 1), "forgotten sender starts fresh")
	end)
end
