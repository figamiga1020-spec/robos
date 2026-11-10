--!strict
--[[
	Signal — lightweight, allocation-friendly event object used across server and client.
	Handlers run in fresh threads so a yielding handler never blocks the firing code.
]]

export type Connection = {
	Connected: boolean,
	Disconnect: (self: Connection) -> (),
}

export type Signal<T...> = {
	Connect: (self: Signal<T...>, fn: (T...) -> ()) -> Connection,
	Once: (self: Signal<T...>, fn: (T...) -> ()) -> Connection,
	Fire: (self: Signal<T...>, T...) -> (),
	Wait: (self: Signal<T...>) -> T...,
	DisconnectAll: (self: Signal<T...>) -> (),
}

type Handler = {
	fn: (...any) -> (),
	connected: boolean,
	once: boolean,
}

local Signal = {}
Signal.__index = Signal

function Signal.new<T...>(): Signal<T...>
	local self = setmetatable({ _handlers = {} :: { Handler } }, Signal)
	return (self :: any) :: Signal<T...>
end

function Signal:Connect(fn: (...any) -> ()): Connection
	local handler: Handler = { fn = fn, connected = true, once = false }
	table.insert(self._handlers, handler)
	local handlers = self._handlers
	local connection = {
		Connected = true,
	}
	function connection.Disconnect(conn: any)
		if not handler.connected then
			return
		end
		handler.connected = false
		conn.Connected = false
		local index = table.find(handlers, handler)
		if index then
			table.remove(handlers, index)
		end
	end
	return (connection :: any) :: Connection
end

function Signal:Once(fn: (...any) -> ()): Connection
	local connection: Connection
	connection = self:Connect(function(...)
		connection:Disconnect()
		fn(...)
	end)
	return connection
end

function Signal:Fire(...: any)
	-- Snapshot so handlers that disconnect during iteration do not skip neighbours.
	local snapshot: { Handler } = table.clone(self._handlers)
	for _, handler in snapshot do
		if handler.connected then
			task.spawn(handler.fn, ...)
		end
	end
end

function Signal:Wait(): ...any
	local thread = coroutine.running()
	self:Once(function(...)
		task.spawn(thread, ...)
	end)
	return coroutine.yield()
end

function Signal:DisconnectAll()
	for _, handler in self._handlers do
		handler.connected = false
	end
	table.clear(self._handlers)
end

return Signal
