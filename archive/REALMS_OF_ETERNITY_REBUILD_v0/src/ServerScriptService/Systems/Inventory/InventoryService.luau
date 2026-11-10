--!strict

local HttpService = game:GetService("HttpService")
local DataService = require(script.Parent.Parent.Parent.Services.DataService)
local ItemsConfig = require(game.ReplicatedStorage.Shared.Config.Items.ItemsConfig)
local RemoteRegistry = require(game.ReplicatedStorage.Remotes.RemoteRegistry)

local InventoryService = {}
local MAX_SLOTS = 40

local function freeSlots(inv): number
	return MAX_SLOTS - #inv
end

function InventoryService.AddItem(player: Player, itemId: string, amount: number): (boolean, string?)
	local profile = DataService.Get(player)
	if not profile then return false, "No profile" end
	local def = ItemsConfig.Get(itemId)
	if not def then return false, "Unknown item" end
	amount = math.max(1, math.floor(amount))

	if def.Stackable then
		local left = amount
		while left > 0 do
			local stack = nil
			for _, it in profile.Inventory do
				if it.ItemId == itemId and it.Amount < def.MaxStack then
					stack = it
					break
				end
			end
			if stack then
				local add = math.min(def.MaxStack - stack.Amount, left)
				stack.Amount += add
				left -= add
			else
				if freeSlots(profile.Inventory) <= 0 then return false, "Full" end
				local add = math.min(def.MaxStack, left)
				table.insert(profile.Inventory, {
					Uid = HttpService:GenerateGUID(false),
					ItemId = itemId,
					Amount = add,
				})
				left -= add
			end
		end
	else
		for _ = 1, amount do
			if freeSlots(profile.Inventory) <= 0 then return false, "Full" end
			table.insert(profile.Inventory, {
				Uid = HttpService:GenerateGUID(false),
				ItemId = itemId,
				Amount = 1,
			})
		end
	end
	InventoryService.Sync(player)
	return true, nil
end

function InventoryService.Remove(player: Player, uid: string, amount: number?): boolean
	local profile = DataService.Get(player)
	if not profile then return false end
	for i, it in profile.Inventory do
		if it.Uid == uid then
			local amt = amount or it.Amount
			if amt >= it.Amount then
				for slot, euid in pairs(profile.Equipment) do
					if euid == uid then profile.Equipment[slot] = nil end
				end
				table.remove(profile.Inventory, i)
			else
				it.Amount -= amt
			end
			InventoryService.Sync(player)
			return true
		end
	end
	return false
end

function InventoryService.Equip(player: Player, uid: string)
	local profile = DataService.Get(player)
	if not profile then return end
	for _, it in profile.Inventory do
		if it.Uid == uid then
			local def = ItemsConfig.Get(it.ItemId)
			if def and def.EquipSlot then
				if def.RequiredLevel and profile.Level < def.RequiredLevel then return end
				profile.Equipment[def.EquipSlot] = uid
				-- Apply armor from item into stats.Armor roughly
				local armor = 0
				for slot, euid in pairs(profile.Equipment) do
					for _, inv in profile.Inventory do
						if inv.Uid == euid then
							local d = ItemsConfig.Get(inv.ItemId)
							if d and d.Stats and d.Stats.Armor then
								armor += d.Stats.Armor
							end
						end
					end
				end
				profile.Stats.Armor = armor
				InventoryService.Sync(player)
				DataService.Sync(player)
			end
			return
		end
	end
end

function InventoryService.Use(player: Player, uid: string)
	local profile = DataService.Get(player)
	if not profile then return end
	for i, it in profile.Inventory do
		if it.Uid == uid then
			local def = ItemsConfig.Get(it.ItemId)
			if not def or def.Type ~= "Consumable" or not def.ConsumeEffect then return end
			local e = def.ConsumeEffect
			if e.Heal then profile.Health = math.min(profile.MaxHealth, profile.Health + e.Heal) end
			if e.Mana then profile.Resource = math.min(profile.MaxResource, profile.Resource + e.Mana) end
			if e.Stamina then profile.Stamina = math.min(profile.MaxStamina, profile.Stamina + e.Stamina) end
			if it.Amount <= 1 then table.remove(profile.Inventory, i) else it.Amount -= 1 end
			InventoryService.Sync(player)
			DataService.Sync(player)
			return
		end
	end
end

function InventoryService.Sync(player: Player)
	local profile = DataService.Get(player)
	if not profile then return end
	local views = {}
	for _, it in profile.Inventory do
		local def = ItemsConfig.Get(it.ItemId)
		table.insert(views, {
			Uid = it.Uid,
			ItemId = it.ItemId,
			Amount = it.Amount,
			DisplayName = def and def.DisplayName or it.ItemId,
			Rarity = def and def.Rarity or "Common",
			Type = def and def.Type,
			Stats = def and def.Stats,
			EquipSlot = def and def.EquipSlot,
			Description = def and def.Description,
		})
	end
	RemoteRegistry.RE_InventorySync:FireClient(player, {
		Items = views,
		Equipment = profile.Equipment,
		Currency = profile.Currency,
		Slots = { Used = #profile.Inventory, Max = MAX_SLOTS },
	})
end

function InventoryService.Init()
	RemoteRegistry.RE_InventoryAction.OnServerEvent:Connect(function(player, action, data)
		if action == "Equip" and typeof(data) == "string" then InventoryService.Equip(player, data)
		elseif action == "Use" and typeof(data) == "string" then InventoryService.Use(player, data)
		elseif action == "Drop" and typeof(data) == "string" then InventoryService.Remove(player, data)
		elseif action == "Sync" then InventoryService.Sync(player)
		end
	end)
	print("[InventoryService] Ready")
end

return InventoryService
