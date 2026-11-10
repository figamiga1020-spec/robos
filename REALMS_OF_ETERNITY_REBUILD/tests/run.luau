--[[
	Lune test harness for REALMS OF ETERNITY.
	Emulates Roblox's `script` / `require(instance)` resolution over the src/ tree so pure
	modules (Logic, Config, Core types) can be unit-tested outside Studio.
	Run from the project root:  lune run tests/run.luau
]]

local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")
local roblox = require("@lune/roblox")
local task = require("@lune/task")

local ROOT = "src"

-- Map DataModel-style paths onto the filesystem (mirrors default.project.json).
local MOUNTS = {
	ReplicatedStorage = { Shared = "src/ReplicatedStorage/Shared" },
	ServerScriptService = "src/ServerScriptService",
	StarterPlayer = { StarterPlayerScripts = "src/StarterPlayer/StarterPlayerScripts" },
}

local cache = {}
local nodeMeta = {}

-- Pre-index the tree: Lune fs calls may yield, which is illegal inside __index metamethods.
local files: { [string]: string } = {} -- path -> source
local dirs: { [string]: boolean } = {}
local function index(path)
	dirs[path] = true
	for _, entry in fs.readDir(path) do
		local full = `{path}/{entry}`
		if fs.isDir(full) then
			index(full)
		elseif string.match(entry, "%.luau?$") then
			files[full] = fs.readFile(full)
		end
	end
end
index(ROOT)

local function makeNode(path, name, parent)
	return setmetatable({ __path = path, Name = name, __parent = parent }, nodeMeta)
end

local function resolveChild(node, key)
	local path = node.__path
	if type(path) == "table" then
		local mapped = path[key]
		if mapped == nil then
			return nil
		end
		return makeNode(mapped, key, node)
	end
	if path == nil then
		return nil
	end
	for _, candidate in { `{path}/{key}.luau`, `{path}/{key}.lua` } do
		if files[candidate] then
			return makeNode(candidate, key, node)
		end
	end
	if dirs[`{path}/{key}`] then
		return makeNode(`{path}/{key}`, key, node)
	end
	return nil
end

nodeMeta.__index = function(node, key)
	if key == "Parent" then
		return rawget(node, "__parent")
	end
	if key == "FindFirstChild" or key == "WaitForChild" then
		return function(self, name)
			return resolveChild(self, name)
		end
	end
	if key == "GetChildren" or key == "GetDescendants" then
		return function()
			return {}
		end
	end
	if key == "IsA" then
		return function()
			return false
		end
	end
	local child = resolveChild(node, key)
	if child == nil then
		error(`{key} is not a valid member of {rawget(node, "__path")}`, 2)
	end
	return child
end

local gameNode = makeNode(MOUNTS, "game", nil)
local services = {
	RunService = {
		IsServer = function()
			return true
		end,
		IsClient = function()
			return false
		end,
		IsStudio = function()
			return true
		end,
	},
}
rawset(gameNode, "GetService", function(_, name)
	local mount = MOUNTS[name]
	if mount then
		return makeNode(mount, name, gameNode)
	end
	return services[name] or setmetatable({}, {
		__index = function()
			return function() end
		end,
	})
end)

local requireModule

local function loadFile(node)
	local path = rawget(node, "__path")
	if cache[path] ~= nil then
		return cache[path]
	end
	local source = files[path]
	-- strip luau-only type-cast generics Lune already supports; nothing to transform
	local env = {
		script = node,
		game = gameNode,
		require = requireModule,
		warn = function(...)
			print("[warn]", ...)
		end,
		task = task,
		Vector3 = roblox.Vector3,
		Vector2 = roblox.Vector2,
		CFrame = roblox.CFrame,
		Color3 = roblox.Color3,
		UDim = roblox.UDim,
		UDim2 = roblox.UDim2,
		NumberSequence = roblox.NumberSequence,
		ColorSequence = roblox.ColorSequence,
		Enum = roblox.Enum,
		Random = roblox.Random,
		Instance = roblox.Instance,
		typeof = roblox.typeof or typeof,
	}
	local chunk = luau.load(source, { debugName = path, environment = env })
	local result = chunk()
	cache[path] = result
	return result
end

function requireModule(target)
	if type(target) == "string" then
		return require(target)
	end
	return loadFile(target)
end

-- ── Tiny test framework ───────────────────────────────────────────────────────
local passed, failed = 0, 0
local failures = {}
local currentSuite = ""

local T = {}

function T.describe(name, fn)
	currentSuite = name
	fn()
end

function T.it(name, fn)
	local ok, err = pcall(fn)
	if ok then
		passed += 1
	else
		failed += 1
		table.insert(failures, `{currentSuite} › {name}\n    {err}`)
	end
end

local function fmt(value)
	return tostring(value)
end

function T.expect(actual)
	return {
		toBe = function(expected)
			if actual ~= expected then
				error(`expected {fmt(expected)}, got {fmt(actual)}`, 2)
			end
		end,
		toBeNear = function(expected, epsilon)
			if math.abs(actual - expected) > (epsilon or 1e-6) then
				error(`expected ≈{fmt(expected)}, got {fmt(actual)}`, 2)
			end
		end,
		toBeTruthy = function()
			if not actual then
				error(`expected truthy, got {fmt(actual)}`, 2)
			end
		end,
		toBeFalsy = function()
			if actual then
				error(`expected falsy, got {fmt(actual)}`, 2)
			end
		end,
		toBeGreaterThan = function(expected)
			if not (actual > expected) then
				error(`expected > {fmt(expected)}, got {fmt(actual)}`, 2)
			end
		end,
		toBeLessThan = function(expected)
			if not (actual < expected) then
				error(`expected < {fmt(expected)}, got {fmt(actual)}`, 2)
			end
		end,
	}
end

-- Loads a module by DataModel-style path, e.g. T.load("ReplicatedStorage/Shared/Logic/Formulas")
function T.load(path)
	local node = gameNode
	for part in string.gmatch(path, "[^/]+") do
		node = node[part]
	end
	return loadFile(node)
end

T.roblox = roblox

-- ── Run every spec ────────────────────────────────────────────────────────────
local specs = fs.readDir("tests/specs")
table.sort(specs)
for _, file in specs do
	if string.match(file, "%.luau$") then
		local source = fs.readFile(`tests/specs/{file}`)
		local chunk = luau.load(source, {
			debugName = file,
			environment = {
				T = T,
				Vector3 = roblox.Vector3,
				Vector2 = roblox.Vector2,
				CFrame = roblox.CFrame,
				Color3 = roblox.Color3,
				task = task,
			},
		})
		local ok, err = pcall(chunk)
		if not ok then
			failed += 1
			table.insert(failures, `{file} (load)\n    {err}`)
		end
	end
end

print(`\nTests: {passed} passed, {failed} failed`)
for _, failure in failures do
	print("  ✗ " .. failure)
end
local _ = ROOT
process.exit(if failed == 0 then 0 else 1)
