--!nonstrict
-- Collision query interface for the ball simulation. BallPhysics never touches Workspace:
-- it is handed a CollisionWorld with one method:
--
--   sweepSphere(from: vector, delta: vector, radius: number) -> Hit?
--   Hit = { position: vector (sphere center at contact), normal: vector, distance: number, instance: Instance? }
--
-- Three implementations:
--   fromPlanes    — analytic half-space sweep. Pure Luau: powers lune tests (FakePitch) and the
--                   deterministic pitch bounds/goal planes in Studio. Same math both runtimes.
--   fromSpherecast — WorldRoot:Spherecast against a RaycastParams whitelist (players, misc geometry).
--                   Roblox-only; all Instance access inside the function.
--   union         — combine worlds, nearest hit wins.

local CollisionWorld = {}

export type Hit = {
	position: vector,
	normal: vector,
	distance: number,
	instance: any?,
}

export type Plane = {
	point: vector,
	normal: vector, -- unit, pointing into the playable volume
	name: string?,
}

export type CollisionWorld = {
	sweepSphere: (from: vector, delta: vector, radius: number) -> Hit?,
}

-- Sweep a sphere against half-space boundaries. A hit is reported when the sphere surface
-- reaches a plane while moving toward it. Starting already in contact reports distance 0.
function CollisionWorld.fromPlanes(planes: { Plane }): CollisionWorld
	local function sweepSphere(from: vector, delta: vector, radius: number): Hit?
		local best: Hit? = nil
		local deltaMag = vector.magnitude(delta)
		for _, plane in planes do
			local d0 = vector.dot(from - plane.point, plane.normal) - radius -- surface clearance
			local dv = vector.dot(delta, plane.normal) -- approach rate along the move
			if dv >= -1e-9 then
				continue -- moving parallel or away
			end
			local t = if d0 <= 0 then 0 else d0 / -dv
			if t <= 1 then
				local distance = t * deltaMag
				if best == nil or distance < best.distance then
					best = {
						position = from + delta * t,
						normal = plane.normal,
						distance = distance,
						instance = nil,
					}
				end
			end
		end
		return best
	end
	return { sweepSphere = sweepSphere }
end

function CollisionWorld.fromSpherecast(raycastParams: any): CollisionWorld
	local function sweepSphere(from: vector, delta: vector, radius: number): Hit?
		local deltaMag = vector.magnitude(delta)
		if deltaMag < 1e-9 then
			return nil
		end
		local result = workspace:Spherecast(from, radius, delta, raycastParams)
		if result == nil then
			return nil
		end
		local t = result.Distance / deltaMag
		return {
			position = from + delta * math.clamp(t, 0, 1),
			normal = result.Normal,
			distance = result.Distance,
			instance = result.Instance,
		}
	end
	return { sweepSphere = sweepSphere }
end

function CollisionWorld.union(...: CollisionWorld): CollisionWorld
	local worlds = { ... }
	local function sweepSphere(from: vector, delta: vector, radius: number): Hit?
		local best: Hit? = nil
		for _, w in worlds do
			local hit = w.sweepSphere(from, delta, radius)
			if hit and (best == nil or hit.distance < best.distance) then
				best = hit
			end
		end
		return best
	end
	return { sweepSphere = sweepSphere }
end

return CollisionWorld
