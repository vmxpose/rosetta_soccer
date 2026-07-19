--!nonstrict
-- Protocol v1: buffer encode/decode for everything that crosses the network, plus size
-- instrumentation. Pure Luau (buffer + vector only) — lune-testable, no Roblox APIs.
--
-- Snapshots ride an UnreliableRemoteEvent, which drops payloads over ~1000 bytes, so the
-- snapshot is compact-binary from day one and every encode reports its size. State-changing
-- events (goals, acks) use the reliable channel and are NOT encoded here in v1 (plain tables
-- on a reliable RemoteEvent are fine; they have no size cliff).
--
-- Layout (little-endian, offsets in bytes):
--   Header: u8 version | u32 sessionId | u32 serverTick | u32 sequence | u8 playerCount | u8 hasBall
--   Ball (if hasBall): f32x3 position | f32x3 velocity | f32x3 spin
--                      | u8 lifecycle | u8 motion | u32 controlledBy | u32 lastToucher | u32 lastTouchTick
--   Player x playerCount: u32 entityId | u8 stamina (0..255 quantized) | u8 action | u8 flags
--     flags: bit0 = hasBall, bit1 = sprinting

local Protocol = {}

Protocol.VERSION = 1

local HEADER_SIZE = 1 + 4 + 4 + 4 + 1 + 1
local BALL_SIZE = 12 + 12 + 12 + 1 + 1 + 4 + 4 + 4
local PLAYER_SIZE = 4 + 1 + 1 + 1

export type PlayerRecord = {
	entityId: number,
	stamina: number, -- 0..1
	action: number,
	hasBall: boolean,
	sprinting: boolean,
}

export type BallRecord = {
	position: vector,
	velocity: vector,
	spin: vector,
	lifecycle: number,
	motion: number,
	controlledBy: number,
	lastToucher: number,
	lastTouchTick: number,
}

export type Snapshot = {
	protocolVersion: number,
	sessionId: number,
	serverTick: number,
	sequence: number,
	ball: BallRecord?,
	players: { PlayerRecord },
}

local function writeVector(buf: buffer, offset: number, v: vector): number
	buffer.writef32(buf, offset, v.x)
	buffer.writef32(buf, offset + 4, v.y)
	buffer.writef32(buf, offset + 8, v.z)
	return offset + 12
end

local function readVector(buf: buffer, offset: number): (vector, number)
	local v =
		vector.create(buffer.readf32(buf, offset), buffer.readf32(buf, offset + 4), buffer.readf32(buf, offset + 8))
	return v, offset + 12
end

function Protocol.snapshotSize(playerCount: number, hasBall: boolean): number
	return HEADER_SIZE + (if hasBall then BALL_SIZE else 0) + playerCount * PLAYER_SIZE
end

function Protocol.encodeSnapshot(snap: Snapshot): buffer
	local playerCount = #snap.players
	assert(playerCount <= 255, "too many player records")
	local buf = buffer.create(Protocol.snapshotSize(playerCount, snap.ball ~= nil))

	buffer.writeu8(buf, 0, Protocol.VERSION)
	buffer.writeu32(buf, 1, snap.sessionId)
	buffer.writeu32(buf, 5, snap.serverTick)
	buffer.writeu32(buf, 9, snap.sequence)
	buffer.writeu8(buf, 13, playerCount)
	buffer.writeu8(buf, 14, if snap.ball then 1 else 0)

	local offset = HEADER_SIZE
	local ball = snap.ball
	if ball then
		offset = writeVector(buf, offset, ball.position)
		offset = writeVector(buf, offset, ball.velocity)
		offset = writeVector(buf, offset, ball.spin)
		buffer.writeu8(buf, offset, ball.lifecycle)
		buffer.writeu8(buf, offset + 1, ball.motion)
		buffer.writeu32(buf, offset + 2, ball.controlledBy)
		buffer.writeu32(buf, offset + 6, ball.lastToucher)
		buffer.writeu32(buf, offset + 10, ball.lastTouchTick)
		offset += 14
	end

	for _, p in snap.players do
		buffer.writeu32(buf, offset, p.entityId)
		buffer.writeu8(buf, offset + 4, math.clamp(math.floor(p.stamina * 255 + 0.5), 0, 255))
		buffer.writeu8(buf, offset + 5, p.action)
		local flags = (if p.hasBall then 1 else 0) + (if p.sprinting then 2 else 0)
		buffer.writeu8(buf, offset + 6, flags)
		offset += PLAYER_SIZE
	end

	return buf
end

function Protocol.decodeSnapshot(buf: buffer): Snapshot
	local version = buffer.readu8(buf, 0)
	assert(version == Protocol.VERSION, `protocol version mismatch: got {version}, expected {Protocol.VERSION}`)

	local snap: Snapshot = {
		protocolVersion = version,
		sessionId = buffer.readu32(buf, 1),
		serverTick = buffer.readu32(buf, 5),
		sequence = buffer.readu32(buf, 9),
		ball = nil,
		players = {},
	}
	local playerCount = buffer.readu8(buf, 13)
	local hasBall = buffer.readu8(buf, 14) == 1

	local offset = HEADER_SIZE
	if hasBall then
		local position, velocity, spin
		position, offset = readVector(buf, offset)
		velocity, offset = readVector(buf, offset)
		spin, offset = readVector(buf, offset)
		snap.ball = {
			position = position,
			velocity = velocity,
			spin = spin,
			lifecycle = buffer.readu8(buf, offset),
			motion = buffer.readu8(buf, offset + 1),
			controlledBy = buffer.readu32(buf, offset + 2),
			lastToucher = buffer.readu32(buf, offset + 6),
			lastTouchTick = buffer.readu32(buf, offset + 10),
		}
		offset += 14
	end

	for _ = 1, playerCount do
		local flags = buffer.readu8(buf, offset + 6)
		table.insert(snap.players, {
			entityId = buffer.readu32(buf, offset),
			stamina = buffer.readu8(buf, offset + 4) / 255,
			action = buffer.readu8(buf, offset + 5),
			hasBall = flags % 2 == 1,
			sprinting = math.floor(flags / 2) % 2 == 1,
		})
		offset += PLAYER_SIZE
	end

	return snap
end

return Protocol
