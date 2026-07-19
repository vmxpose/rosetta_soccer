--!nonstrict
-- Dev-only local file server so Studio can pull the src tree over HTTP
-- (used by the MCP sync flow when the Rojo plugin isn't connected).
-- Run: lune run tools/studio_sync_server   then fetch http://127.0.0.1:8747/manifest

local fs = require("@lune/fs")
local net = require("@lune/net")
local serde = require("@lune/serde")

local PORT = 8747

local function walk(dir: string, list: { string })
	for _, name in fs.readDir(dir) do
		local path = `{dir}/{name}`
		if fs.isDir(path) then
			walk(path, list)
		elseif name:match("%.luau$") then
			table.insert(list, path)
		end
	end
end

-- NOTE: lune 0.10 responds 500 unless `status` is set explicitly on table responses.
local function handle(request)
	if request.path == "/manifest" then
		local list = {}
		walk("src", list)
		table.sort(list)
		return { status = 200, headers = { ["Content-Type"] = "application/json" }, body = serde.encode("json", list) }
	end
	local rel = request.path:sub(2)
	if rel:match("^src/") and not rel:match("%.%.") and fs.isFile(rel) then
		return { status = 200, body = fs.readFile(rel) }
	end
	return { status = 404, body = "not found" }
end

net.serve(PORT, function(request)
	local ok, result = pcall(handle, request)
	if ok then
		return result
	end
	print(`[sync-server] handler error: {tostring(result)}`)
	return { status = 500, body = tostring(result) }
end)

print(`[sync-server] serving ./src on http://127.0.0.1:{PORT}`)
