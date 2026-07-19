--!strict
-- Minimal in-house signal. Fire is synchronous and in connection order. Pure Luau.

local Signal = {}
Signal.__index = Signal

export type Connection = { Disconnect: (self: Connection) -> () }
export type Signal<T...> = typeof(setmetatable({} :: { _handlers: { (T...) -> () } }, Signal))

function Signal.new<T...>(): Signal<T...>
	return setmetatable({ _handlers = {} }, Signal)
end

function Signal.Connect<T...>(self: Signal<T...>, handler: (T...) -> ()): Connection
	table.insert(self._handlers, handler)
	local connection = {}
	function connection.Disconnect(_self: Connection)
		local index = table.find(self._handlers, handler)
		if index then
			table.remove(self._handlers, index)
		end
	end
	return connection :: Connection
end

function Signal.Once<T...>(self: Signal<T...>, handler: (T...) -> ()): Connection
	local connection: Connection
	connection = self:Connect(function(...)
		connection:Disconnect()
		handler(...)
	end)
	return connection
end

function Signal.Fire<T...>(self: Signal<T...>, ...: T...)
	for _, handler in table.clone(self._handlers) do
		handler(...)
	end
end

return Signal
