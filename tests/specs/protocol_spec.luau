--!nonstrict
local NetConfig = require("../../src/shared/Config/NetConfig")
local Protocol = require("../../src/shared/Net/Protocol")

local function fullMatchSnapshot()
	local players = {}
	for i = 1, 22 do
		table.insert(players, {
			entityId = i + 1,
			stamina = (i % 10) / 10,
			action = i % 5,
			hasBall = i == 7,
			sprinting = i % 3 == 0,
		})
	end
	return {
		protocolVersion = Protocol.VERSION,
		sessionId = 123456789,
		serverTick = 987654,
		sequence = 4242,
		ball = {
			position = vector.create(10.5, 1.25, -33.75),
			velocity = vector.create(-4, 12, 0.5),
			spin = vector.create(0, 6.5, 0),
			lifecycle = 0,
			motion = 1,
			controlledBy = 0,
			lastToucher = 8,
			lastTouchTick = 987600,
		},
		players = players,
	}
end

return function(t)
	t.case("snapshot roundtrip preserves header and ball exactly (f32 fields)", function()
		local snap = fullMatchSnapshot()
		local decoded = Protocol.decodeSnapshot(Protocol.encodeSnapshot(snap))
		t.eq(decoded.protocolVersion, Protocol.VERSION)
		t.eq(decoded.sessionId, snap.sessionId)
		t.eq(decoded.serverTick, snap.serverTick)
		t.eq(decoded.sequence, snap.sequence)
		-- Chosen fixture values are exactly representable in f32.
		t.ok(decoded.ball.position == snap.ball.position, "ball position")
		t.ok(decoded.ball.velocity == snap.ball.velocity, "ball velocity")
		t.ok(decoded.ball.spin == snap.ball.spin, "ball spin")
		t.eq(decoded.ball.motion, snap.ball.motion)
		t.eq(decoded.ball.controlledBy, snap.ball.controlledBy)
		t.eq(decoded.ball.lastToucher, snap.ball.lastToucher)
		t.eq(decoded.ball.lastTouchTick, snap.ball.lastTouchTick)
	end)

	t.case("player records roundtrip (stamina within quantization step)", function()
		local snap = fullMatchSnapshot()
		local decoded = Protocol.decodeSnapshot(Protocol.encodeSnapshot(snap))
		t.eq(#decoded.players, 22)
		for i, p in decoded.players do
			t.eq(p.entityId, snap.players[i].entityId)
			t.eq(p.action, snap.players[i].action)
			t.eq(p.hasBall, snap.players[i].hasBall)
			t.eq(p.sprinting, snap.players[i].sprinting)
			t.near(p.stamina, snap.players[i].stamina, 1 / 255)
		end
	end)

	t.case("ball-less snapshot roundtrips", function()
		local snap = fullMatchSnapshot()
		snap.ball = nil
		local decoded = Protocol.decodeSnapshot(Protocol.encodeSnapshot(snap))
		t.eq(decoded.ball, nil)
		t.eq(#decoded.players, 22)
	end)

	t.case("full-match snapshot fits the byte budget with headroom", function()
		local buf = Protocol.encodeSnapshot(fullMatchSnapshot())
		t.ok(
			buffer.len(buf) <= NetConfig.SnapshotBudgetBytes,
			`snapshot is {buffer.len(buf)} bytes, budget {NetConfig.SnapshotBudgetBytes}`
		)
	end)

	t.case("size formula matches encoded size", function()
		local snap = fullMatchSnapshot()
		t.eq(buffer.len(Protocol.encodeSnapshot(snap)), Protocol.snapshotSize(#snap.players, true))
	end)

	t.case("decode rejects version mismatch", function()
		local buf = Protocol.encodeSnapshot(fullMatchSnapshot())
		buffer.writeu8(buf, 0, Protocol.VERSION + 1)
		t.fails(function()
			Protocol.decodeSnapshot(buf)
		end)
	end)
end
