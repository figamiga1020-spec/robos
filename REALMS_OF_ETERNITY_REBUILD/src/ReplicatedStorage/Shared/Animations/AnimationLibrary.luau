--!strict
--[[
	AnimationLibrary — loads every AnimSet module under Shared/Animations/Sets
	and resolves inheritance (e.g. Knight → Humanoid). Lookups walk the chain, so a class set
	only defines what differs from the base humanoid set.

	REQUIRED CLIPS per set chain (the client controller and CombatService rely on these names):
	  Locomotion: Idle, Walk, Run   (optional: Sprint, CombatIdle, Jump, Fall, Land, Swim)
	  Reactions : HitLight, HitHeavy, Stagger, Knockdown, Death
	Humanoid player sets additionally provide every ActionDef.Clip in Config/Classes, the shared
	Dodge_Roll / Dodge_Blink / Dodge_Dash, BlockLoop clips and ambient NPC clips listed in the docs.
]]

local Anim = require(script.Parent.Anim)

type AnimSet = Anim.AnimSet
type Clip = Anim.Clip

local AnimationLibrary = {}

local sets: { [string]: AnimSet } = {}
local loaded = false

local function load()
	if loaded then
		return
	end
	loaded = true
	local folder = script.Parent:FindFirstChild("Sets")
	if not folder then
		return
	end
	for _, child in folder:GetDescendants() do
		if child:IsA("ModuleScript") then
			local ok, result = pcall(require, child)
			if ok and type(result) == "table" and type(result.Name) == "string" and type(result.Clips) == "table" then
				if sets[result.Name] then
					-- merge additional modules contributing to the same set
					for name, clip in result.Clips do
						sets[result.Name].Clips[name] = clip
					end
				else
					sets[result.Name] = result
				end
			elseif not ok then
				warn(`[AnimationLibrary] failed to load {child:GetFullName()}: {result}`)
			end
		end
	end
end

function AnimationLibrary.GetSet(name: string): AnimSet?
	load()
	return sets[name]
end

function AnimationLibrary.GetClip(setName: string, clipName: string): Clip?
	load()
	local current: AnimSet? = sets[setName]
	local guard = 0
	while current and guard < 8 do
		local clip = current.Clips[clipName]
		if clip then
			return clip
		end
		current = if current.Inherit then sets[current.Inherit] else nil
		guard += 1
	end
	return nil
end

-- First non-nil field along the inheritance chain (Locomotion, Procedural ...).
function AnimationLibrary.GetField(setName: string, field: string): any
	load()
	local current: AnimSet? = sets[setName]
	local guard = 0
	while current and guard < 8 do
		local value = (current :: any)[field]
		if value ~= nil then
			return value
		end
		current = if current.Inherit then sets[current.Inherit] else nil
		guard += 1
	end
	return nil
end

function AnimationLibrary.AllSets(): { [string]: AnimSet }
	load()
	return sets
end

return AnimationLibrary
