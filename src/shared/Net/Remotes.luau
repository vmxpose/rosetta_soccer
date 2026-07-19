--!nonstrict
-- Every network channel, declared in one place. The instances are Rojo-managed
-- (defined in default.project.json under ReplicatedStorage.RosettaRemotes) — NOT created at
-- runtime, so live-sync tooling never removes them as unknown instances. This module just
-- resolves and validates them. Roblox-only (not lune-tested); Instance access stays in functions.

local CHANNELS: { [string]: string } = {
	Snapshot = "UnreliableRemoteEvent", -- server -> client, 20 Hz buffer-encoded world state
	Intent = "RemoteEvent", -- client -> server, sequence-numbered gameplay intents
	Reliable = "RemoteEvent", -- server -> client, intent acks + match events (must not drop)
}

local FOLDER_NAME = "RosettaRemotes"

local Remotes = {}

export type Channels = { [string]: any }

local function resolve(): Channels
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local folder = ReplicatedStorage:WaitForChild(FOLDER_NAME)
	local channels = {}
	for name, className in CHANNELS do
		local remote = folder:WaitForChild(name)
		assert(remote.ClassName == className, `remote {name} is {remote.ClassName}, expected {className}`)
		channels[name] = remote
	end
	return channels
end

Remotes.server = resolve
Remotes.client = resolve

return Remotes
