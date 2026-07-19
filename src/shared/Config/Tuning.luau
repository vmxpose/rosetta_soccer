--!strict
-- THE feel file. Every gameplay constant lives here, grouped by system.
-- Nothing else in the codebase may hold a magic gameplay number.
-- Units: studs, seconds, radians unless noted.

local Tuning = {
	Sim = {
		DT = 1 / 60, -- fixed simulation timestep
		MaxCatchUpSteps = 4, -- per frame; time beyond this is dropped
	},

	Ball = {
		Radius = 0.9,
		Gravity = 65, -- studs/s^2 (tuned for feel, not realism — iterate in M1)
		AirDragK = 0.008, -- quadratic drag coefficient
		MagnusK = 0.35, -- spin-to-curve coefficient
		Restitution = 0.62, -- bounce energy retention (default surface)
		BounceStopSpeed = 6, -- vertical speed below which a bounce becomes rolling
		RollFriction = 8, -- studs/s^2 decel while rolling
		RestSpeed = 0.75, -- speed below which a rolling ball comes to rest
		SpinDecayPerSecond = 0.45, -- fraction of spin lost per second
	},
}

return Tuning
