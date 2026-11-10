--!strict
--[[
	Client entry point. Boots every *Controller module under PlayerScripts.Controllers.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")

local Registry = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Core"):WaitForChild("Registry"))

if not game:IsLoaded() then
	game.Loaded:Wait()
end

-- The game draws its own HUD; hide Roblox core bars that duplicate it.
pcall(function()
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Health, false)
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
end)

local playerScripts = Players.LocalPlayer:WaitForChild("PlayerScripts")
Registry.Boot(playerScripts:WaitForChild("Controllers"), "Controller")
