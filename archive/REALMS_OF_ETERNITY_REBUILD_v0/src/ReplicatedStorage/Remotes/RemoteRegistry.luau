--!strict
--[[
	Central remote registry. All networking goes through here.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local folder = ReplicatedStorage:FindFirstChild("ROE_Remotes")
if not folder then
	folder = Instance.new("Folder")
	folder.Name = "ROE_Remotes"
	folder.Parent = ReplicatedStorage
end

local function ensure(name: string, className: "RemoteEvent" | "RemoteFunction")
	local existing = folder:FindFirstChild(name)
	if existing then
		return existing
	end
	local r = Instance.new(className)
	r.Name = name
	r.Parent = folder
	return r
end

local RemoteRegistry = {
	-- Character
	RE_CreateCharacter = ensure("RE_CreateCharacter", "RemoteEvent") :: RemoteEvent,
	RE_CreateCharacterResult = ensure("RE_CreateCharacterResult", "RemoteEvent") :: RemoteEvent,
	RE_ProfileSync = ensure("RE_ProfileSync", "RemoteEvent") :: RemoteEvent,

	-- Combat / Skills
	RE_CombatIntent = ensure("RE_CombatIntent", "RemoteEvent") :: RemoteEvent,
	RE_CombatResult = ensure("RE_CombatResult", "RemoteEvent") :: RemoteEvent,
	RE_CastSkill = ensure("RE_CastSkill", "RemoteEvent") :: RemoteEvent,
	RE_SkillResult = ensure("RE_SkillResult", "RemoteEvent") :: RemoteEvent,

	-- Inventory
	RE_InventoryAction = ensure("RE_InventoryAction", "RemoteEvent") :: RemoteEvent,
	RE_InventorySync = ensure("RE_InventorySync", "RemoteEvent") :: RemoteEvent,

	-- Quests / NPC
	RE_QuestAction = ensure("RE_QuestAction", "RemoteEvent") :: RemoteEvent,
	RE_QuestSync = ensure("RE_QuestSync", "RemoteEvent") :: RemoteEvent,
	RE_NPCInteract = ensure("RE_NPCInteract", "RemoteEvent") :: RemoteEvent,
	RE_Dialogue = ensure("RE_Dialogue", "RemoteEvent") :: RemoteEvent,

	-- Party
	RE_PartyAction = ensure("RE_PartyAction", "RemoteEvent") :: RemoteEvent,
	RE_PartySync = ensure("RE_PartySync", "RemoteEvent") :: RemoteEvent,

	-- World / Death
	RE_RequestRespawn = ensure("RE_RequestRespawn", "RemoteEvent") :: RemoteEvent,
	RE_WorldMessage = ensure("RE_WorldMessage", "RemoteEvent") :: RemoteEvent,

	-- Dungeon / Boss
	RE_DungeonAction = ensure("RE_DungeonAction", "RemoteEvent") :: RemoteEvent,
	RE_BossEvent = ensure("RE_BossEvent", "RemoteEvent") :: RemoteEvent,
}

return RemoteRegistry
