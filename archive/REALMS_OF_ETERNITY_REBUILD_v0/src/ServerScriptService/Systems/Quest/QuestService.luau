--!strict

local DataService = require(script.Parent.Parent.Parent.Services.DataService)
local InventoryService = require(script.Parent.Parent.Inventory.InventoryService)
local StarterCampaign = require(game.ReplicatedStorage.Shared.Config.Quests.StarterCampaign)
local RemoteRegistry = require(game.ReplicatedStorage.Remotes.RemoteRegistry)

local QuestService = {}

local function completed(profile: any, id: string): boolean
	for _, q in profile.CompletedQuests do
		if q == id then return true end
	end
	return false
end

local function canAccept(profile: any, quest: any): boolean
	if profile.Level < (quest.Level or 1) then return false end
	if profile.Quests[quest.Id] then return false end
	if completed(profile, quest.Id) then return false end
	for _, pre in quest.Prerequisites or {} do
		if not completed(profile, pre) then return false end
	end
	return true
end

local function sync(player: Player)
	local profile = DataService.Get(player)
	if not profile then return end
	local active = {}
	for id, state in pairs(profile.Quests) do
		local def = StarterCampaign.Get(id)
		if def then
			table.insert(active, {
				Id = id,
				DisplayName = def.DisplayName,
				Description = def.Description,
				Objectives = def.Objectives,
				Progress = state.Objectives,
				Completed = state.Completed,
			})
		end
	end
	RemoteRegistry.RE_QuestSync:FireClient(player, {
		Type = "Sync",
		Active = active,
		Completed = profile.CompletedQuests,
	})
end

function QuestService.Accept(player: Player, questId: string)
	local profile = DataService.Get(player)
	local quest = StarterCampaign.Get(questId)
	if not profile or not quest then return end
	if not canAccept(profile, quest) then
		RemoteRegistry.RE_QuestSync:FireClient(player, { Type = "Error", Message = "Cannot accept" })
		return
	end
	local objectives = {}
	for _, obj in quest.Objectives do
		objectives[obj.Id] = 0
	end
	profile.Quests[questId] = {
		QuestId = questId,
		Objectives = objectives,
		Completed = false,
		TurnedIn = false,
	}
	DataService.Save(player)
	sync(player)
	RemoteRegistry.RE_QuestSync:FireClient(player, { Type = "Accepted", QuestId = questId, Name = quest.DisplayName })
end

function QuestService.AddProgress(player: Player, objType: string, targetId: string, amount: number?)
	local profile = DataService.Get(player)
	if not profile then return end
	amount = amount or 1
	local changed = false
	for questId, state in pairs(profile.Quests) do
		if state.Completed or state.TurnedIn then continue end
		local quest = StarterCampaign.Get(questId)
		if not quest then continue end
		for _, obj in quest.Objectives do
			if obj.Type == objType and obj.TargetId == targetId then
				local cur = state.Objectives[obj.Id] or 0
				if cur < obj.Count then
					state.Objectives[obj.Id] = math.min(obj.Count, cur + amount)
					changed = true
				end
			end
		end
		if changed then
			local done = true
			for _, obj in quest.Objectives do
				if (state.Objectives[obj.Id] or 0) < obj.Count then
					done = false
					break
				end
			end
			if done then
				state.Completed = true
				RemoteRegistry.RE_QuestSync:FireClient(player, {
					Type = "ObjectivesComplete",
					QuestId = questId,
					Name = quest.DisplayName,
				})
			end
		end
	end
	if changed then
		DataService.Save(player)
		sync(player)
	end
end

function QuestService.TurnIn(player: Player, questId: string)
	local profile = DataService.Get(player)
	local quest = StarterCampaign.Get(questId)
	local state = profile and profile.Quests[questId]
	if not profile or not quest or not state or not state.Completed or state.TurnedIn then return end

	profile.Experience += quest.Rewards.Experience or 0
	profile.Currency.Gold += quest.Rewards.Gold or 0
	local need = profile.Level * 100
	while profile.Experience >= need do
		profile.Experience -= need
		profile.Level += 1
		need = profile.Level * 100
	end
	if quest.Rewards.Items then
		for _, it in quest.Rewards.Items do
			InventoryService.AddItem(player, it.ItemId, it.Amount)
		end
	end

	state.TurnedIn = true
	table.insert(profile.CompletedQuests, questId)
	profile.Quests[questId] = nil

	-- Auto-offer next in chain if possible
	if quest.Next then
		local nextQ = StarterCampaign.Get(quest.Next)
		if nextQ and canAccept(profile, nextQ) then
			-- do not auto-accept; notify client
			RemoteRegistry.RE_QuestSync:FireClient(player, {
				Type = "NextAvailable",
				QuestId = quest.Next,
				Name = nextQ.DisplayName,
			})
		end
	end

	DataService.Save(player)
	DataService.Sync(player)
	sync(player)
	RemoteRegistry.RE_QuestSync:FireClient(player, {
		Type = "TurnedIn",
		QuestId = questId,
		Rewards = quest.Rewards,
	})
end

function QuestService.OnKill(player: Player, enemyId: string)
	QuestService.AddProgress(player, "Kill", enemyId, 1)
end

function QuestService.OnTalk(player: Player, npcId: string)
	QuestService.AddProgress(player, "Talk", npcId, 1)
end

function QuestService.OnReach(player: Player, zoneId: string)
	QuestService.AddProgress(player, "Reach", zoneId, 1)
end

function QuestService.Init()
	RemoteRegistry.RE_QuestAction.OnServerEvent:Connect(function(player, data)
		if typeof(data) ~= "table" then return end
		if data.Action == "Accept" then QuestService.Accept(player, data.QuestId)
		elseif data.Action == "TurnIn" then QuestService.TurnIn(player, data.QuestId)
		elseif data.Action == "Talk" then QuestService.OnTalk(player, data.NPCId)
		elseif data.Action == "Sync" then sync(player)
		end
	end)
	RemoteRegistry.RE_NPCInteract.OnServerEvent:Connect(function(player, npcId)
		if typeof(npcId) ~= "string" then return end
		QuestService.OnTalk(player, npcId)
		-- Offer available quests from this NPC
		local profile = DataService.Get(player)
		local offers = {}
		if profile then
			for _, q in StarterCampaign.GetOrdered() do
				if q.Giver == npcId and canAccept(profile, q) then
					table.insert(offers, { Id = q.Id, Name = q.DisplayName, Description = q.Description })
				end
				local st = profile.Quests[q.Id]
				if st and st.Completed and not st.TurnedIn and q.TurnIn == npcId then
					table.insert(offers, { Id = q.Id, Name = q.DisplayName, ReadyToTurnIn = true })
				end
			end
		end
		RemoteRegistry.RE_Dialogue:FireClient(player, { NPCId = npcId, Offers = offers })
	end)
	print("[QuestService] Ready")
end

return QuestService
