--!strict
--[[
	AnimationService — server-side animation broadcast. The server never animates joints itself
	(Motor6D.Transform does not replicate); it tells clients which clip starts and when.

	Play(model, clip, opts, except?)  — clients within range start the clip, compensating latency
	Stop(model, clip?, fade?)
	SetState(model, state)            — persistent "AnimState" attribute for late-streaming clients
	                                     (e.g. "Working", "Sitting", "Combat", "Channel")
	SetAnimSet(model, setName)        — "AnimSet" attribute picked up by AnimationController
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Net = require(ReplicatedStorage.Shared.Core.Net)

local BROADCAST_RADIUS = 320

local AnimationService = { Priority = 80 }

export type Options = {
	Speed: number?,
	Duration: number?,
	Hold: boolean?,
	Looped: boolean?,
	FadeIn: number?,
	FadeOut: number?,
	Priority: number?,
}

local function rootPosition(model: Model): Vector3?
	local root = model.PrimaryPart or model:FindFirstChild("HumanoidRootPart") :: BasePart?
	return root and root.Position
end

function AnimationService:Play(model: Model, clip: string, opts: Options?, except: Player?)
	local position = rootPosition(model)
	if not position then
		return
	end
	local payload = { M = model, C = clip, T = Workspace:GetServerTimeNow(), O = opts }
	if except then
		local radiusSq = BROADCAST_RADIUS * BROADCAST_RADIUS
		local list = {}
		for _, player in game:GetService("Players"):GetPlayers() do
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if player ~= except and root then
				local delta = root.Position - position
				if delta:Dot(delta) <= radiusSq then
					table.insert(list, player)
				end
			end
		end
		Net.FireList(list, "Anim", payload)
	else
		Net.FireNear(position, BROADCAST_RADIUS, "Anim", payload)
	end
end

function AnimationService:Stop(model: Model, clip: string?, fade: number?)
	local position = rootPosition(model)
	if position then
		Net.FireNear(position, BROADCAST_RADIUS, "AnimStop", model, clip, fade)
	end
end

function AnimationService:SetState(model: Model, state: string?)
	model:SetAttribute("AnimState", state)
end

function AnimationService:SetAnimSet(model: Model, setName: string)
	model:SetAttribute("AnimSet", setName)
end

function AnimationService:Init()
	Net.DeclareUnreliable("AnimStop")
end

return AnimationService
