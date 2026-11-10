--!strict
--[[
	Server entry point. Boots every *Service module under ServerScriptService.Services.
	Services are discovered automatically — adding a service never requires editing this file.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Registry = require(ReplicatedStorage.Shared.Core.Registry)

ReplicatedStorage:SetAttribute("BuildVersion", "0.1.0-slice")
ReplicatedStorage:SetAttribute("WorldReady", false)

Registry.Boot(ServerScriptService.Services, "Service")
