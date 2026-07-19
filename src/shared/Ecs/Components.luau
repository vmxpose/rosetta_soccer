--!nonstrict
-- Component catalog: the single registry of component names, their default constructors,
-- and whether they ride network snapshots. Components are pure data tables — no methods.
-- Enum-like fields are numeric constants (protocol-friendly), named here.

local Components = {}

-- Ball state is three orthogonal dimensions, not one FSM:
-- Lifecycle is owned by match rules, Control by possession, Motion derived by the integrator.
Components.Lifecycle = {
	Live = 0,
	Dead = 1,
}

Components.Motion = {
	Airborne = 0,
	Bouncing = 1,
	Rolling = 2,
	Resting = 3,
}

-- Control is represented as `controlledBy: entityId`, 0 = Free.
Components.FREE = 0

Components.Action = {
	Idle = 0,
	ChargingKick = 1,
	Kicking = 2,
	Tackling = 3,
	Stunned = 4,
}

Components.catalog = {
	Ball = {
		networked = true,
		defaults = function()
			return {
				position = vector.create(0, 5, 0),
				velocity = vector.zero,
				spin = vector.zero, -- axis * rad/s
				lifecycle = Components.Lifecycle.Live,
				motion = Components.Motion.Airborne,
				controlledBy = Components.FREE,
				lastToucher = 0, -- entity id, 0 = none
				lastTouchTick = 0,
			}
		end,
	},

	PlayerGameplay = {
		networked = true,
		defaults = function()
			return {
				stamina = 1, -- 0..1
				action = Components.Action.Idle,
				hasBall = false,
				sprinting = false,
			}
		end,
	},
}

function Components.networkedNames(): { string }
	local names = {}
	for name, def in Components.catalog do
		if def.networked then
			table.insert(names, name)
		end
	end
	table.sort(names)
	return names
end

return Components
