--!strict

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local gui = player:WaitForChild("PlayerGui")
local RemoteRegistry = require(ReplicatedStorage.Remotes.RemoteRegistry)
local ClassesConfig = require(ReplicatedStorage.Shared.Config.Classes.ClassesConfig)

local stats = {
	Health = 100, MaxHealth = 100,
	Resource = 50, MaxResource = 50,
	Stamina = 100, MaxStamina = 100,
	Level = 1, Class = "Knight", Race = "Human", Name = "",
}
local skillBar = {}

local screen = Instance.new("ScreenGui")
screen.Name = "ROE_MainHUD"
screen.ResetOnSpawn = false
screen.Parent = gui

local bars = Instance.new("Frame")
bars.Size = UDim2.new(0, 260, 0, 80)
bars.Position = UDim2.new(0, 16, 1, -110)
bars.BackgroundTransparency = 1
bars.Parent = screen

local function bar(name, color, y)
	local bg = Instance.new("Frame")
	bg.Size = UDim2.new(1, 0, 0, 18)
	bg.Position = UDim2.new(0, 0, 0, y)
	bg.BackgroundColor3 = Color3.fromRGB(20, 18, 24)
	bg.BorderSizePixel = 0
	bg.Parent = bars
	Instance.new("UICorner", bg).CornerRadius = UDim.new(0, 4)
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.new(1, 0, 1, 0)
	fill.BackgroundColor3 = color
	fill.BorderSizePixel = 0
	fill.Parent = bg
	Instance.new("UICorner", fill).CornerRadius = UDim.new(0, 4)
	local lab = Instance.new("TextLabel")
	lab.Name = "Label"
	lab.Size = UDim2.new(1, 0, 1, 0)
	lab.BackgroundTransparency = 1
	lab.Text = name
	lab.TextColor3 = Color3.fromRGB(240, 240, 240)
	lab.Font = Enum.Font.GothamBold
	lab.TextSize = 11
	lab.Parent = bg
	return fill, lab
end

local hpF, hpL = bar("HP", Color3.fromRGB(170, 45, 45), 0)
local rpF, rpL = bar("RES", Color3.fromRGB(55, 90, 190), 24)
local spF, spL = bar("STA", Color3.fromRGB(50, 150, 70), 48)

local levelL = Instance.new("TextLabel")
levelL.Size = UDim2.new(0, 300, 0, 22)
levelL.Position = UDim2.new(0, 16, 1, -135)
levelL.BackgroundTransparency = 1
levelL.TextColor3 = Color3.fromRGB(220, 195, 140)
levelL.Font = Enum.Font.GothamBold
levelL.TextSize = 14
levelL.TextXAlignment = Enum.TextXAlignment.Left
levelL.Parent = screen

local zoneL = Instance.new("TextLabel")
zoneL.Size = UDim2.new(0, 400, 0, 24)
zoneL.Position = UDim2.new(0.5, -200, 0, 16)
zoneL.BackgroundTransparency = 1
zoneL.Text = "Aurenholm — Capital of Aydra"
zoneL.TextColor3 = Color3.fromRGB(200, 185, 150)
zoneL.Font = Enum.Font.GothamMedium
zoneL.TextSize = 16
zoneL.Parent = screen

local questL = Instance.new("TextLabel")
questL.Size = UDim2.new(0, 320, 0, 80)
questL.Position = UDim2.new(1, -340, 0, 50)
questL.BackgroundColor3 = Color3.fromRGB(14, 12, 18)
questL.BackgroundTransparency = 0.25
questL.TextColor3 = Color3.fromRGB(190, 185, 170)
questL.Font = Enum.Font.Gotham
questL.TextSize = 13
questL.TextXAlignment = Enum.TextXAlignment.Left
questL.TextYAlignment = Enum.TextYAlignment.Top
questL.TextWrapped = true
questL.Text = "Quest Journal: talk to Herald Mira"
questL.Parent = screen
Instance.new("UICorner", questL).CornerRadius = UDim.new(0, 8)

local skillFrame = Instance.new("Frame")
skillFrame.Size = UDim2.new(0, 280, 0, 52)
skillFrame.Position = UDim2.new(0.5, -140, 1, -70)
skillFrame.BackgroundColor3 = Color3.fromRGB(16, 14, 22)
skillFrame.BackgroundTransparency = 0.3
skillFrame.Parent = screen
Instance.new("UICorner", skillFrame).CornerRadius = UDim.new(0, 8)

local skillButtons = {}
for i = 1, 4 do
	local b = Instance.new("TextButton")
	b.Size = UDim2.new(0, 58, 0, 44)
	b.Position = UDim2.new(0, 8 + (i - 1) * 68, 0, 4)
	b.BackgroundColor3 = Color3.fromRGB(35, 30, 45)
	b.Text = tostring(i)
	b.TextColor3 = Color3.fromRGB(200, 190, 170)
	b.Font = Enum.Font.GothamBold
	b.TextSize = 12
	b.Parent = skillFrame
	Instance.new("UICorner", b).CornerRadius = UDim.new(0, 6)
	skillButtons[i] = b
	b.MouseButton1Click:Connect(function()
		local id = skillBar[i]
		if id then RemoteRegistry.RE_CastSkill:FireServer(id, {}) end
	end)
end

local hint = Instance.new("TextLabel")
hint.Size = UDim2.new(0, 500, 0, 18)
hint.Position = UDim2.new(0.5, -250, 1, -22)
hint.BackgroundTransparency = 1
hint.Text = "LMB Attack | RMB Heavy | Q Block | Shift Dodge | 1-4 Skills | Walk East Gate → Eldoria"
hint.TextColor3 = Color3.fromRGB(130, 125, 115)
hint.Font = Enum.Font.Gotham
hint.TextSize = 11
hint.Parent = screen

local function refresh()
	hpF.Size = UDim2.new(math.clamp(stats.Health / math.max(stats.MaxHealth, 1), 0, 1), 0, 1, 0)
	rpF.Size = UDim2.new(math.clamp(stats.Resource / math.max(stats.MaxResource, 1), 0, 1), 0, 1, 0)
	spF.Size = UDim2.new(math.clamp(stats.Stamina / math.max(stats.MaxStamina, 1), 0, 1), 0, 1, 0)
	hpL.Text = string.format("HP %d/%d", stats.Health, stats.MaxHealth)
	rpL.Text = string.format("RES %d/%d", stats.Resource, stats.MaxResource)
	spL.Text = string.format("STA %d/%d", stats.Stamina, stats.MaxStamina)
	levelL.Text = string.format("Lv %d  %s the %s %s", stats.Level, stats.Name ~= "" and stats.Name or "Hero", stats.Race, stats.Class)
	for i = 1, 4 do
		local id = skillBar[i]
		if id then
			local class = ClassesConfig.Get(stats.Class)
			local name = id
			if class then
				for _, s in class.Skills do
					if s.Id == id then name = s.Name break end
				end
			end
			skillButtons[i].Text = name:sub(1, 8)
		else
			skillButtons[i].Text = tostring(i)
		end
	end
end

UserInputService.InputBegan:Connect(function(input, gpe)
	if gpe then return end
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		RemoteRegistry.RE_CombatIntent:FireServer("Light")
	elseif input.UserInputType == Enum.UserInputType.MouseButton2 then
		RemoteRegistry.RE_CombatIntent:FireServer("Heavy")
	elseif input.KeyCode == Enum.KeyCode.Q then
		RemoteRegistry.RE_CombatIntent:FireServer("BlockStart")
	elseif input.KeyCode == Enum.KeyCode.LeftShift then
		RemoteRegistry.RE_CombatIntent:FireServer("Dodge")
	elseif input.KeyCode == Enum.KeyCode.One and skillBar[1] then
		RemoteRegistry.RE_CastSkill:FireServer(skillBar[1], {})
	elseif input.KeyCode == Enum.KeyCode.Two and skillBar[2] then
		RemoteRegistry.RE_CastSkill:FireServer(skillBar[2], {})
	elseif input.KeyCode == Enum.KeyCode.Three and skillBar[3] then
		RemoteRegistry.RE_CastSkill:FireServer(skillBar[3], {})
	elseif input.KeyCode == Enum.KeyCode.Four and skillBar[4] then
		RemoteRegistry.RE_CastSkill:FireServer(skillBar[4], {})
	elseif input.KeyCode == Enum.KeyCode.G then
		-- Engage boss if in glade (client intent)
		RemoteRegistry.RE_DungeonAction:FireServer({ Action = "EngageForestGuardian" })
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if input.KeyCode == Enum.KeyCode.Q then
		RemoteRegistry.RE_CombatIntent:FireServer("BlockStop")
	end
end)

RemoteRegistry.RE_ProfileSync.OnClientEvent:Connect(function(data)
	if typeof(data) ~= "table" then return end
	for k, v in pairs(data) do
		if stats[k] ~= nil or k == "CharacterName" then
			if k == "CharacterName" then stats.Name = v
			else stats[k] = v end
		end
	end
	if data.SkillBar then skillBar = data.SkillBar end
	if data.LastLocation and data.LastLocation.RegionId then
		zoneL.Text = data.LastLocation.RegionId == "Eldoria" and "Eldoria — Enchanted Forest" or "Aurenholm — Capital of Aydra"
	end
	refresh()
end)

RemoteRegistry.RE_QuestSync.OnClientEvent:Connect(function(data)
	if data.Type == "Sync" and data.Active then
		if #data.Active == 0 then
			questL.Text = "No active quest.\nTalk to Herald Mira (Central Plaza)."
		else
			local q = data.Active[1]
			local lines = { q.DisplayName }
			if q.Objectives and q.Progress then
				for _, obj in q.Objectives do
					local cur = q.Progress[obj.Id] or 0
					table.insert(lines, string.format("• %s (%d/%d)", obj.Text, cur, obj.Count))
				end
			end
			questL.Text = table.concat(lines, "\n")
		end
	elseif data.Type == "Accepted" then
		questL.Text = "Accepted: " .. (data.Name or data.QuestId)
	end
end)

RemoteRegistry.RE_BossEvent.OnClientEvent:Connect(function(data)
	if data.Type == "Intro" then
		zoneL.Text = "Sacred Glade — Forest Guardian"
	elseif data.Type == "PhaseChange" then
		questL.Text = "Boss Phase " .. tostring(data.Phase)
	elseif data.Type == "Announcement" then
		questL.Text = data.Text or ""
	elseif data.Type == "AbilityTelegraph" then
		questL.Text = "Incoming: " .. tostring(data.Ability)
	end
end)

RemoteRegistry.RE_WorldMessage.OnClientEvent:Connect(function(data)
	if data.Type == "Death" then
		questL.Text = data.Message or "You died."
	end
end)

refresh()
print("[MainHUD] Ready")
