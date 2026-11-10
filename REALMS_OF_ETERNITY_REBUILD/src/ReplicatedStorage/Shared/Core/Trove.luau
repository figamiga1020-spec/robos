--!strict
--[[
	Trove — owns cleanup of instances, connections, threads and callbacks.
	Every temporary object (VFX, telegraphs, encounter state) is registered in a Trove so
	nothing leaks when an encounter, menu or character is torn down.
]]

export type Trove = {
	Add: <T>(self: Trove, item: T) -> T,
	Connect: (self: Trove, signal: RBXScriptSignal, fn: (...any) -> ()) -> RBXScriptConnection,
	Clean: (self: Trove) -> (),
	Destroy: (self: Trove) -> (),
	Extend: (self: Trove) -> Trove,
}

local Trove = {}
Trove.__index = Trove

local function cleanup(item: any)
	local kind = typeof(item)
	if kind == "Instance" then
		item:Destroy()
	elseif kind == "RBXScriptConnection" then
		item:Disconnect()
	elseif kind == "function" then
		item()
	elseif kind == "thread" then
		if coroutine.status(item) ~= "dead" and coroutine.running() ~= item then
			pcall(task.cancel, item)
		end
	elseif kind == "table" then
		if type(item.Destroy) == "function" then
			item:Destroy()
		elseif type(item.Disconnect) == "function" then
			item:Disconnect()
		end
	end
end

function Trove.new(): Trove
	return (setmetatable({ _items = {} :: { any } }, Trove) :: any) :: Trove
end

function Trove:Add(item: any): any
	table.insert(self._items, item)
	return item
end

function Trove:Connect(signal: RBXScriptSignal, fn: (...any) -> ()): RBXScriptConnection
	local connection = signal:Connect(fn)
	table.insert(self._items, connection)
	return connection
end

function Trove:Extend(): Trove
	local child = Trove.new()
	table.insert(self._items, child)
	return child
end

function Trove:Clean()
	local items = self._items
	self._items = {}
	for index = #items, 1, -1 do
		cleanup(items[index])
	end
end

function Trove:Destroy()
	self:Clean()
end

return Trove
