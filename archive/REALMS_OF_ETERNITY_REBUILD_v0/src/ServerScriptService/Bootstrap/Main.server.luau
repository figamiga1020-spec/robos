--!strict
--[[
	REALMS OF ETERNITY REBUILD — Server Bootstrap
	Vertical slice systems only. Continuous world (no region portals).
]]

print("========================================")
print(" REALMS OF ETERNITY REBUILD")
print(" World: Aydra | Capital: Aurenholm")
print("========================================")

local Services = script.Parent.Parent.Services
local Systems = script.Parent.Parent.Systems

require(game.ReplicatedStorage.Remotes.RemoteRegistry)

local DataService = require(Services.DataService)
DataService.Init()

local CharacterService = require(Systems.Character.CharacterService)
CharacterService.Init()

local InventoryService = require(Systems.Inventory.InventoryService)
InventoryService.Init()

local CombatService = require(Systems.Combat.CombatService)
CombatService.Init()

local QuestService = require(Systems.Quest.QuestService)
QuestService.Init()

local PartyService = require(Systems.Party.PartyService)
PartyService.Init()

local EnemyService = require(Systems.Enemy.EnemyService)
EnemyService.Init()

local ForestGuardianService = require(Systems.Boss.ForestGuardianService)
ForestGuardianService.Init()

local WorldService = require(Systems.World.WorldService)
WorldService.Init()

local WorldBuilder = require(Systems.World.WorldBuilder)
WorldBuilder.Init()

local EnvironmentEffects = require(Systems.World.EnvironmentEffects)
EnvironmentEffects.Init()

print("========================================")
print(" Systems online:")
print(" Data | Character | Inventory | Combat")
print(" Quest | Party | Enemy | ForestGuardian | World")
print(" WorldBuilder | EnvironmentFX | Materials | VFX")
print(" Vertical slice path:")
print(" Create → Aurenholm → East Gate walk → Eldoria")
print(" → Quests → Temple → Forest Guardian → Save")
print("========================================")
