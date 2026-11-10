--!strict
--[[
	PlayerState — client cache of server-replicated state sections.
	Sections arrive through the "StateSection" remote (DataService.MarkDirty / PushSection).

	PlayerState.Get("Inventory")            -> latest data or nil
	PlayerState.Changed("Inventory"):Connect(function(data) ... end)
	PlayerState.Observe("Character", fn)    -> calls fn now (if present) and on every change
	PlayerState.Sync()                      -> full resync (RequestState)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Core.Net)
local Signal = require(ReplicatedStorage.Shared.Core.Signal)

local PlayerState = {}

local data: { [string]: any } = {}
local signals: { [string]: Signal.Signal<any> } = {}
local started = false

local function signalFor(section: string): Signal.Signal<any>
	local signal = signals[section]
	if not signal then
		signal = Signal.new()
		signals[section] = signal
	end
	return signal
end

local function apply(section: string, value: any)
	data[section] = value
	signalFor(section):Fire(value)
end

function PlayerState.Get(section: string): any
	return data[section]
end

function PlayerState.Changed(section: string): Signal.Signal<any>
	return signalFor(section)
end

function PlayerState.Observe(section: string, fn: (any) -> ()): Signal.Connection
	if data[section] ~= nil then
		task.spawn(fn, data[section])
	end
	return signalFor(section):Connect(fn)
end

function PlayerState.Sync()
	local result = Net.Invoke("RequestState")
	if type(result) == "table" then
		for section, value in result do
			apply(section, value)
		end
	end
end

function PlayerState.Start()
	if started then
		return
	end
	started = true
	Net.On("StateSection", function(section: string, value: any)
		apply(section, value)
	end)
	task.spawn(PlayerState.Sync)
end

PlayerState.Start()

return PlayerState
