--!strict
--[[
	Registry — service/controller locator with a two-phase boot.

	Server: every ModuleScript under ServerScriptService.Services (recursively) whose name ends
	in "Service" is a service. Client: every ModuleScript under StarterPlayerScripts.Controllers
	whose name ends in "Controller" is a controller.

	Lifecycle:
	  1. require() all modules (no cross-module calls at require time!)
	  2. module:Init()  — synchronous, set up state, connect remotes. May call Registry.Get.
	  3. module:Start() — spawned, may yield (world build, data loads, loops).

	Modules use Registry.Get("CombatService") at call time instead of requiring each other,
	which removes circular-require problems between tightly coupled gameplay services.
]]

local Registry = {}

local modules: { [string]: any } = {}
local order: { string } = {}
local started = false

function Registry.Register(name: string, module: any)
	assert(modules[name] == nil, `Registry: duplicate module '{name}'`)
	modules[name] = module
	table.insert(order, name)
end

function Registry.Get(name: string): any
	local module = modules[name]
	if module == nil then
		error(`Registry: module '{name}' is not registered`, 2)
	end
	return module
end

function Registry.Find(name: string): any?
	return modules[name]
end

function Registry.IsStarted(): boolean
	return started
end

local function collect(folder: Instance, suffix: string, out: { ModuleScript })
	for _, child in folder:GetChildren() do
		if child:IsA("ModuleScript") and string.sub(child.Name, -#suffix) == suffix then
			table.insert(out, child)
		elseif child:IsA("Folder") then
			collect(child, suffix, out)
		end
	end
end

-- Boots all modules under `folder` whose names end with `suffix`.
function Registry.Boot(folder: Instance, suffix: string)
	local scripts: { ModuleScript } = {}
	collect(folder, suffix, scripts)
	table.sort(scripts, function(a, b)
		return a.Name < b.Name
	end)

	for _, moduleScript in scripts do
		local ok, result = pcall(require, moduleScript)
		if ok then
			Registry.Register(moduleScript.Name, result)
		else
			warn(`[Registry] failed to require {moduleScript:GetFullName()}: {result}`)
		end
	end

	-- Priority lets foundational services (Data, Combat) initialise before dependants.
	table.sort(order, function(a, b)
		local pa = (type(modules[a]) == "table" and modules[a].Priority) or 0
		local pb = (type(modules[b]) == "table" and modules[b].Priority) or 0
		if pa == pb then
			return a < b
		end
		return pa > pb
	end)

	for _, name in order do
		local module = modules[name]
		if type(module) == "table" and type(module.Init) == "function" then
			local ok, err = pcall(module.Init, module)
			if not ok then
				warn(`[Registry] {name}:Init failed: {err}`)
			end
		end
	end

	started = true

	for _, name in order do
		local module = modules[name]
		if type(module) == "table" and type(module.Start) == "function" then
			task.spawn(function()
				local ok, err = xpcall(module.Start, debug.traceback, module)
				if not ok then
					warn(`[Registry] {name}:Start failed: {err}`)
				end
			end)
		end
	end
end

return Registry
