--!strict
--[[
	Net — the single networking layer. All remotes live in ReplicatedStorage.Remotes and are
	created by the server on first use. Server handlers are always validated + rate limited.

	Server:
	  Net.Handle(name, { Args = {Validate...}, Rate = {capacity, perSecond} }, function(player, ...) end)
	  Net.HandleInvoke(name, spec, function(player, ...) return ... end)
	  Net.FireClient(player, name, ...) / FireAll / FireAllExcept / FireList / FireNear(pos, radius, ...)
	  Net.DeclareUnreliable(name)   -- cosmetic high-frequency events (damage numbers, shakes)
	Client:
	  Net.Fire(name, ...) / Net.Invoke(name, ...) / Net.On(name, fn)

	Rejected calls are counted per player; SecurityService may inspect Net.GetViolations().
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Validate = require(script.Parent.Parent.Logic.Validate)
local RateLimiter = require(script.Parent.Parent.Logic.RateLimiter)

export type HandlerSpec = {
	Args: { Validate.Checker }?,
	Rate: { number }?, -- { capacity, refillPerSecond }
}

local IS_SERVER = RunService:IsServer()
local FOLDER_NAME = "Remotes"
local INVOKE_TIMEOUT = 15

local Net = {}

local folder: Folder
local unreliable: { [string]: boolean } = {}
local violations: { [number]: number } = {}
local limiters: { [string]: RateLimiter.RateLimiter } = {}

if IS_SERVER then
	local existing = ReplicatedStorage:FindFirstChild(FOLDER_NAME)
	if existing and existing:IsA("Folder") then
		folder = existing
	else
		folder = Instance.new("Folder")
		folder.Name = FOLDER_NAME
		folder.Parent = ReplicatedStorage
	end
else
	folder = ReplicatedStorage:WaitForChild(FOLDER_NAME) :: Folder
end

local function getRemote(name: string, className: string): Instance
	local remote = folder:FindFirstChild(name)
	if remote then
		return remote
	end
	assert(IS_SERVER, "client cannot create remotes")
	local created = Instance.new(className)
	created.Name = name
	created.Parent = folder
	return created
end

local function eventRemote(name: string): RemoteEvent
	local className = if unreliable[name] then "UnreliableRemoteEvent" else "RemoteEvent"
	return getRemote(name, className) :: any
end

local function recordViolation(player: Player, name: string, reason: string?)
	violations[player.UserId] = (violations[player.UserId] or 0) + 1
	if RunService:IsStudio() then
		warn(`[Net] rejected {name} from {player.Name}: {reason or "?"}`)
	end
end

local function limiterFor(name: string, rate: { number }?): RateLimiter.RateLimiter
	local limiter = limiters[name]
	if not limiter then
		local capacity = rate and rate[1] or 20
		local refill = rate and rate[2] or 10
		limiter = RateLimiter.new(capacity, refill)
		limiters[name] = limiter
	end
	return limiter
end

local function admit(player: Player, name: string, spec: HandlerSpec, args: { any }, count: number): boolean
	local limiter = limiterFor(name, spec.Rate)
	if not limiter:Allow(tostring(player.UserId)) then
		recordViolation(player, name, "rate limited")
		return false
	end
	local ok, reason = Validate.Args(spec.Args or {}, args, count)
	if not ok then
		recordViolation(player, name, reason)
		return false
	end
	return true
end

-- ── Server ─────────────────────────────────────────────────────────────────────

function Net.DeclareUnreliable(name: string)
	assert(IS_SERVER, "server only")
	unreliable[name] = true
	getRemote(name, "UnreliableRemoteEvent")
end

function Net.Handle(name: string, spec: HandlerSpec, handler: (Player, ...any) -> ())
	assert(IS_SERVER, "server only")
	local remote = eventRemote(name);
	(remote :: RemoteEvent).OnServerEvent:Connect(function(player: Player, ...)
		local count = select("#", ...)
		local args = { ... }
		if not admit(player, name, spec, args, count) then
			return
		end
		local ok, err: any = pcall(function()
			handler(player, table.unpack(args, 1, count))
		end)
		if not ok then
			warn(`[Net] handler {name} errored: {err}`)
		end
	end)
end

function Net.HandleInvoke(name: string, spec: HandlerSpec, handler: (Player, ...any) -> ...any)
	assert(IS_SERVER, "server only")
	local remote = getRemote(name, "RemoteFunction") :: RemoteFunction
	remote.OnServerInvoke = function(player: Player, ...): ...any
		local count = select("#", ...)
		local args = { ... }
		if not admit(player, name, spec, args, count) then
			return false, "rejected"
		end
		local results = table.pack(pcall(handler, player, table.unpack(args, 1, count)))
		if not results[1] then
			warn(`[Net] invoke {name} errored: {results[2]}`)
			return false, "server error"
		end
		return table.unpack(results, 2, results.n)
	end
end

function Net.FireClient(player: Player, name: string, ...: any)
	eventRemote(name):FireClient(player, ...)
end

function Net.FireAll(name: string, ...: any)
	eventRemote(name):FireAllClients(...)
end

function Net.FireList(players: { Player }, name: string, ...: any)
	local remote = eventRemote(name)
	for _, player in players do
		remote:FireClient(player, ...)
	end
end

function Net.FireAllExcept(except: Player?, name: string, ...: any)
	local remote = eventRemote(name)
	for _, player in Players:GetPlayers() do
		if player ~= except then
			remote:FireClient(player, ...)
		end
	end
end

-- Fires to players whose character is within `radius` studs of `position`.
function Net.FireNear(position: Vector3, radius: number, name: string, ...: any)
	local remote = eventRemote(name)
	local radiusSq = radius * radius
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root then
			local delta = root.Position - position
			if delta:Dot(delta) <= radiusSq then
				remote:FireClient(player, ...)
			end
		end
	end
end

function Net.GetViolations(player: Player): number
	return violations[player.UserId] or 0
end

if IS_SERVER then
	Players.PlayerRemoving:Connect(function(player)
		violations[player.UserId] = nil
		local key = tostring(player.UserId)
		for _, limiter in limiters do
			limiter:Reset(key)
		end
	end)
end

-- ── Client ─────────────────────────────────────────────────────────────────────

local function waitRemote(name: string, timeout: number?): Instance?
	return folder:WaitForChild(name, timeout or 60)
end

function Net.Fire(name: string, ...: any)
	assert(not IS_SERVER, "client only")
	local remote = waitRemote(name)
	if remote then
		(remote :: RemoteEvent):FireServer(...)
	end
end

function Net.Invoke(name: string, ...: any): ...any
	assert(not IS_SERVER, "client only")
	local remote = waitRemote(name) :: RemoteFunction?
	if not remote then
		return false, "missing remote"
	end
	local args = table.pack(...)
	local result: { any }? = nil
	local thread = coroutine.running()
	local finished = false
	task.spawn(function()
		local packed = table.pack(pcall(remote.InvokeServer, remote, table.unpack(args, 1, args.n)))
		if finished then
			return
		end
		finished = true
		result = packed
		task.spawn(thread)
	end)
	task.delay(INVOKE_TIMEOUT, function()
		if finished then
			return
		end
		finished = true
		task.spawn(thread)
	end)
	coroutine.yield()
	local packed = result :: any
	if not packed then
		return false, "timeout"
	end
	if not packed[1] then
		return false, tostring(packed[2])
	end
	return table.unpack(packed, 2, packed.n)
end

-- Connects as soon as the remote exists (does not block the caller).
function Net.On(name: string, handler: (...any) -> ()): { Disconnect: () -> () }
	assert(not IS_SERVER, "client only")
	local connection: RBXScriptConnection? = nil
	local cancelled = false
	task.spawn(function()
		local remote = waitRemote(name, math.huge)
		if cancelled or not remote then
			return
		end
		connection = (remote :: RemoteEvent).OnClientEvent:Connect(handler)
	end)
	return {
		Disconnect = function()
			cancelled = true
			if connection then
				connection:Disconnect()
			end
		end,
	}
end

return Net
