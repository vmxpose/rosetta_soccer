--!strict
-- Networking constants: rates, budgets, buffers. Gameplay feel lives in Tuning, not here.

local NetConfig = {
	SnapshotEveryNTicks = 3, -- 60 Hz sim / 3 = 20 Hz snapshots
	SnapshotBudgetBytes = 700, -- gate; UnreliableRemoteEvent drops payloads over ~1000 bytes
	InterpDelaySeconds = 0.120, -- client renders this far behind estimated server time
	SnapshotBufferSize = 32, -- client ring buffer entries
	MaxRewindSeconds = 0.200, -- lag-compensation clamp for validating client intents
	ClockSmoothing = 0.1, -- EMA factor for server-clock offset estimation
}

return NetConfig
