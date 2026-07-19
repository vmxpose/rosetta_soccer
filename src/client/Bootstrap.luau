--!nonstrict
-- Client bootstrap: mirrors the world for prediction/interpolation, receives snapshots,
-- estimates the server clock, and renders the debug overlay. Client-local entities
-- (VFX, UI markers) allocate ids from CLIENT_ID_BASE so server ids never collide.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Clock = require(ReplicatedStorage.Net.Clock)
local DebugOverlay = require(ReplicatedStorage.Debug.DebugOverlay)
local NetConfig = require(ReplicatedStorage.Config.NetConfig)
local Protocol = require(ReplicatedStorage.Net.Protocol)
local Remotes = require(ReplicatedStorage.Net.Remotes)
local Scheduler = require(ReplicatedStorage.Ecs.Scheduler)
local Tuning = require(ReplicatedStorage.Config.Tuning)
local World = require(ReplicatedStorage.Ecs.World)

local CLIENT_ID_BASE = 1_000_000

local Bootstrap = {}

function Bootstrap.start()
	local world = World.new("client", { idBase = CLIENT_ID_BASE })
	local scheduler = Scheduler.new({
		simDt = Tuning.Sim.DT,
		maxCatchUpSteps = Tuning.Sim.MaxCatchUpSteps,
	})
	local clock = Clock.new(Tuning.Sim.DT, NetConfig.ClockSmoothing)
	local remotes = Remotes.client()

	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local overlay = DebugOverlay.new(playerGui)

	local net = {
		lastSnapshot = nil,
		lastSequence = 0,
		lastBytes = 0,
		receivedAt = 0,
		received = 0,
		outOfOrder = 0,
	}
	world:setResource("net", net)

	remotes.Snapshot.OnClientEvent:Connect(function(buf: buffer)
		local snap = Protocol.decodeSnapshot(buf)
		net.received += 1
		if snap.sequence <= net.lastSequence then
			net.outOfOrder += 1
			return -- stale; interpolation must never rewind
		end
		net.lastSequence = snap.sequence
		net.lastSnapshot = snap
		net.lastBytes = buffer.len(buf)
		net.receivedAt = os.clock()
		clock:observe(snap.serverTick, os.clock())
	end)

	-- === Render systems, in execution order ===
	scheduler:addRenderSystem({
		name = "OverlayRender",
		step = function(w, _dt, _alpha)
			local now = os.clock()
			overlay:set("client tick", scheduler.tick)
			overlay:set("snapshot bytes", net.lastBytes)
			overlay:set("snapshots rx", net.received)
			overlay:set("out of order", net.outOfOrder)
			if net.lastSnapshot then
				overlay:set("server tick", net.lastSnapshot.serverTick)
				overlay:set("snapshot age ms", (now - net.receivedAt) * 1000)
			end
			if clock:isSynced() then
				overlay:set("est server tick", clock:serverTickAt(now))
			end
			overlay:render()
		end,
	})

	RunService.Heartbeat:Connect(function(dt)
		scheduler:heartbeat(world, dt)
	end)
	RunService.RenderStepped:Connect(function(dt)
		scheduler:render(world, dt)
	end)

	print("[Rosetta] client world up")
	return world, scheduler
end

return Bootstrap
