--!strict
--[[
	Party system for 1 / 2 / 3 / 5 players with scaling helpers.
]]

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local DataService = require(script.Parent.Parent.Parent.Services.DataService)
local RemoteRegistry = require(game.ReplicatedStorage.Remotes.RemoteRegistry)

local PartyService = {}

local MAX = 5
local parties: { [string]: any } = {}
local memberOf: { [number]: string } = {}

-- Scaling table from design prompt
PartyService.Scale = {
	[1] = { Health = 1.00, Difficulty = 1.00 },
	[2] = { Health = 1.45, Difficulty = 1.20 },
	[3] = { Health = 1.90, Difficulty = 1.40 },
	[5] = { Health = 2.80, Difficulty = 1.75 },
}

local function snapshot(userId: number, isLeader: boolean)
	local p = Players:GetPlayerByUserId(userId)
	local profile = p and DataService.Get(p)
	return {
		UserId = userId,
		Name = p and p.DisplayName or "?",
		Level = profile and profile.Level or 1,
		Class = profile and profile.Class or "Knight",
		Health = profile and profile.Health or 0,
		MaxHealth = profile and profile.MaxHealth or 1,
		IsLeader = isLeader,
	}
end

local function broadcast(party: any)
	local members = {}
	for _, uid in party.Members do
		table.insert(members, snapshot(uid, uid == party.LeaderId))
	end
	for _, uid in party.Members do
		local plr = Players:GetPlayerByUserId(uid)
		if plr then
			RemoteRegistry.RE_PartySync:FireClient(plr, {
				PartyId = party.Id,
				LeaderId = party.LeaderId,
				Members = members,
				Size = #party.Members,
				Scale = PartyService.GetScale(#party.Members),
			})
		end
	end
end

function PartyService.GetScale(size: number)
	if size >= 5 then return PartyService.Scale[5] end
	if size >= 3 then return PartyService.Scale[3] end
	if size >= 2 then return PartyService.Scale[2] end
	return PartyService.Scale[1]
end

function PartyService.GetPartySizeForPlayer(player: Player): number
	local id = memberOf[player.UserId]
	if not id or not parties[id] then return 1 end
	return #parties[id].Members
end

function PartyService.GetMembers(player: Player): { Player }
	local id = memberOf[player.UserId]
	if not id or not parties[id] then return { player } end
	local list = {}
	for _, uid in parties[id].Members do
		local p = Players:GetPlayerByUserId(uid)
		if p then table.insert(list, p) end
	end
	return list
end

function PartyService.Create(player: Player)
	if memberOf[player.UserId] then return end
	local id = HttpService:GenerateGUID(false)
	parties[id] = { Id = id, LeaderId = player.UserId, Members = { player.UserId } }
	memberOf[player.UserId] = id
	broadcast(parties[id])
end

function PartyService.Invite(leader: Player, targetUserId: number)
	local id = memberOf[leader.UserId]
	local party = id and parties[id]
	if not party or party.LeaderId ~= leader.UserId then return end
	if #party.Members >= MAX then return end
	if memberOf[targetUserId] then return end
	local target = Players:GetPlayerByUserId(targetUserId)
	if not target then return end
	RemoteRegistry.RE_PartySync:FireClient(target, {
		Type = "Invite",
		From = leader.UserId,
		FromName = leader.DisplayName,
		PartyId = id,
	})
end

function PartyService.Accept(player: Player, partyId: string)
	if memberOf[player.UserId] then return end
	local party = parties[partyId]
	if not party or #party.Members >= MAX then return end
	table.insert(party.Members, player.UserId)
	memberOf[player.UserId] = partyId
	broadcast(party)
end

function PartyService.Leave(player: Player)
	local id = memberOf[player.UserId]
	if not id then return end
	local party = parties[id]
	if not party then memberOf[player.UserId] = nil return end
	for i, uid in party.Members do
		if uid == player.UserId then
			table.remove(party.Members, i)
			break
		end
	end
	memberOf[player.UserId] = nil
	if #party.Members == 0 then
		parties[id] = nil
	else
		if party.LeaderId == player.UserId then
			party.LeaderId = party.Members[1]
		end
		broadcast(party)
	end
	RemoteRegistry.RE_PartySync:FireClient(player, { Type = "Left" })
end

function PartyService.Init()
	RemoteRegistry.RE_PartyAction.OnServerEvent:Connect(function(player, data)
		if typeof(data) ~= "table" then return end
		if data.Action == "Create" then PartyService.Create(player)
		elseif data.Action == "Invite" then PartyService.Invite(player, data.TargetUserId)
		elseif data.Action == "Accept" then PartyService.Accept(player, data.PartyId)
		elseif data.Action == "Leave" then PartyService.Leave(player)
		elseif data.Action == "Request" then
			local id = memberOf[player.UserId]
			if id and parties[id] then broadcast(parties[id]) end
		end
	end)
	Players.PlayerRemoving:Connect(function(p)
		PartyService.Leave(p)
	end)
	print("[PartyService] Ready")
end

return PartyService
