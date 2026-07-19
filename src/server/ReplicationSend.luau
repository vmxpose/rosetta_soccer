--!nonstrict
-- Server system: every Nth sim tick, capture networked gameplay state into a Protocol
-- snapshot buffer and broadcast it. Also maintains the "netStats" world resource
-- (payload bytes, sequence) surfaced by debug tooling.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local NetConfig = require(ReplicatedStorage.Config.NetConfig)
local Protocol = require(ReplicatedStorage.Net.Protocol)

local ReplicationSend = {}

function ReplicationSend.new(remotes, sessionId: number)
	local sequence = 0

	local function buildSnapshot(world, serverTick: number)
		local ball = nil
		for _, ballData in world:query("Ball") do
			ball = ballData
			break
		end

		local players = {}
		for id, gameplay in world:query("PlayerGameplay") do
			table.insert(players, {
				entityId = id,
				stamina = gameplay.stamina,
				action = gameplay.action,
				hasBall = gameplay.hasBall,
				sprinting = gameplay.sprinting,
			})
		end

		return {
			protocolVersion = Protocol.VERSION,
			sessionId = sessionId,
			serverTick = serverTick,
			sequence = sequence,
			ball = ball,
			players = players,
		}
	end

	return {
		name = "ReplicationSend",
		step = function(world, _dt)
			local tick = world:resource("tick")
			if tick % NetConfig.SnapshotEveryNTicks ~= 0 then
				return
			end
			sequence += 1
			local snap = buildSnapshot(world, tick)
			local buf = Protocol.encodeSnapshot(snap)
			local bytes = buffer.len(buf)
			if bytes > NetConfig.SnapshotBudgetBytes then
				warn(`[Rosetta] snapshot over budget: {bytes} > {NetConfig.SnapshotBudgetBytes} bytes`)
			end
			world:setResource("netStats", { lastBytes = bytes, sequence = sequence, serverTick = tick })
			remotes.Snapshot:FireAllClients(buf)
		end,
	}
end

return ReplicationSend
