--!nonstrict
-- Text overlay for live sim/net stats. You cannot tune what you cannot see: this exists
-- from M0 onward. Roblox-only (creates GUI instances); all Instance access inside functions.
--
-- Usage: local overlay = DebugOverlay.new(playerGui)
--        overlay:set("tick", 1234)  -- rendered sorted by key each :render()

local DebugOverlay = {}
DebugOverlay.__index = DebugOverlay

function DebugOverlay.new(parent: Instance)
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "RosettaDebugOverlay"
	screenGui.ResetOnSpawn = false
	screenGui.DisplayOrder = 1000

	local label = Instance.new("TextLabel")
	label.Name = "Stats"
	label.BackgroundColor3 = Color3.new(0, 0, 0)
	label.BackgroundTransparency = 0.35
	label.TextColor3 = Color3.new(1, 1, 1)
	label.Font = Enum.Font.Code
	label.TextSize = 14
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextYAlignment = Enum.TextYAlignment.Top
	label.AnchorPoint = Vector2.new(0, 0)
	label.Position = UDim2.new(0, 8, 0, 8)
	label.Size = UDim2.new(0, 340, 0, 220)
	label.AutomaticSize = Enum.AutomaticSize.Y
	label.Text = ""
	label.Parent = screenGui

	screenGui.Parent = parent

	return setmetatable({
		_gui = screenGui,
		_label = label,
		_stats = {},
	}, DebugOverlay)
end

function DebugOverlay:set(key: string, value: any)
	self._stats[key] = value
end

function DebugOverlay:setVisible(visible: boolean)
	self._gui.Enabled = visible
end

function DebugOverlay:render()
	local keys = {}
	for key in self._stats do
		table.insert(keys, key)
	end
	table.sort(keys)
	local lines = table.create(#keys)
	for _, key in keys do
		local value = self._stats[key]
		if type(value) == "number" and value % 1 ~= 0 then
			value = string.format("%.2f", value)
		end
		table.insert(lines, `{key}: {tostring(value)}`)
	end
	self._label.Text = table.concat(lines, "\n")
end

return DebugOverlay
