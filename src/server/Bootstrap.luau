--!nonstrict
-- Server bootstrap: builds the authoritative world, registers systems in explicit order,
-- and drives the scheduler from Heartbeat. The ONLY server file that touches service
-- singletons at startup. System registration order below is the documentation of
-- execution order — keep it explicit.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Components = require(ReplicatedStorage.Ecs.Components)
local NetConfig = require(ReplicatedStorage.Config.NetConfig)
local Protocol = require(ReplicatedStorage.Net.Protocol)
local Remotes = require(ReplicatedStorage.Net.Remotes)
local ReplicationSend = require(script.Parent.ReplicationSend)
local Scheduler = require(ReplicatedStorage.Ecs.Scheduler)
local Tuning = require(ReplicatedStorage.Config.Tuning)
local World = require(ReplicatedStorage.Ecs.World)

local Bootstrap = {}

-- M0 gate: measure the worst-case v1 snapshot (full 22-player match) against the budget.
local function logSnapshotBudget(sessionId: number)
	local players = table.create(22)
	for i = 1, 22 do
		players[i] = { entityId = i + 1, stamina = 1, action = 0, hasBall = false, sprinting = false }
	end
	local buf = Protocol.encodeSnapshot({
		protocolVersion = Protocol.VERSION,
		sessionId = sessionId,
		serverTick = 0,
		sequence = 0,
		ball = Components.catalog.Ball.defaults(),
		players = players,
	})
	local bytes = buffer.len(buf)
	print(
		`[Rosetta] Protocol v{Protocol.VERSION}: full-match snapshot = {bytes} bytes`
			.. ` (budget {NetConfig.SnapshotBudgetBytes})`
	)
end

function Bootstrap.start()
	math.randomseed(os.clock() * 1e6)
	local sessionId = math.random(1, 2 ^ 31 - 1)

	local world = World.new("server")
	local scheduler = Scheduler.new({
		simDt = Tuning.Sim.DT,
		maxCatchUpSteps = Tuning.Sim.MaxCatchUpSteps,
	})
	local remotes = Remotes.server()

	-- The one match ball. Placeholder motion until the M1 integrator lands.
	world:spawn({ Ball = Components.catalog.Ball.defaults() })

	-- === Simulation systems, in execution order ===
	scheduler:addSimSystem(ReplicationSend.new(remotes, sessionId))

	RunService.Heartbeat:Connect(function(dt)
		scheduler:heartbeat(world, dt)
	end)

	logSnapshotBudget(sessionId)
	print(`[Rosetta] server world up — session {sessionId}, sim {1 // Tuning.Sim.DT} Hz`)

	-- Periodic heartbeat log until the client overlay exists on this side of the wire.
	task.spawn(function()
		while true do
			task.wait(5)
			local netStats = world:resource("netStats")
			print(
				`[Rosetta] server tick {scheduler.tick}`
					.. if netStats then ` | snapshot #{netStats.sequence} {netStats.lastBytes}B` else ""
			)
		end
	end)

	return world, scheduler
end

return Bootstrap
