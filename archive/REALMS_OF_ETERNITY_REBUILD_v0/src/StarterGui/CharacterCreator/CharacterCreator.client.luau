--!strict
--[[
	Phase-1 character creator: 15 races, 4 playable classes.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local gui = player:WaitForChild("PlayerGui")

local RemoteRegistry = require(ReplicatedStorage.Remotes.RemoteRegistry)
local RacesConfig = require(ReplicatedStorage.Shared.Config.Races.RacesConfig)
local ClassesConfig = require(ReplicatedStorage.Shared.Config.Classes.ClassesConfig)

local raceId = "Human"
local classId = "Knight"
local charName = ""

local screen = Instance.new("ScreenGui")
screen.Name = "ROE_CharacterCreator"
screen.ResetOnSpawn = false
screen.Parent = gui

local frame = Instance.new("Frame")
frame.Size = UDim2.new(0.9, 0, 0.88, 0)
frame.Position = UDim2.new(0.05, 0, 0.06, 0)
frame.BackgroundColor3 = Color3.fromRGB(12, 10, 16)
frame.BorderSizePixel = 0
frame.Parent = screen
Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 12)

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -20, 0, 40)
title.Position = UDim2.new(0, 10, 0, 8)
title.BackgroundTransparency = 1
title.Text = "REALMS OF ETERNITY — Create Your Hero"
title.TextColor3 = Color3.fromRGB(220, 195, 140)
title.Font = Enum.Font.GothamBold
title.TextSize = 22
title.Parent = frame

local subtitle = Instance.new("TextLabel")
subtitle.Size = UDim2.new(1, -20, 0, 22)
subtitle.Position = UDim2.new(0, 10, 0, 48)
subtitle.BackgroundTransparency = 1
subtitle.Text = "World of Aydra  •  Capital Aurenholm  •  Continuous open world (no portals)"
subtitle.TextColor3 = Color3.fromRGB(140, 135, 125)
subtitle.Font = Enum.Font.Gotham
subtitle.TextSize = 13
subtitle.Parent = frame

local function panel(xScale: number, name: string)
	local f = Instance.new("ScrollingFrame")
	f.Name = name
	f.Size = UDim2.new(0.3, 0, 0.55, 0)
	f.Position = UDim2.new(xScale, 0, 0.14, 0)
	f.BackgroundColor3 = Color3.fromRGB(22, 18, 28)
	f.BorderSizePixel = 0
	f.ScrollBarThickness = 4
	f.Parent = frame
	Instance.new("UICorner", f).CornerRadius = UDim.new(0, 8)
	local lay = Instance.new("UIListLayout")
	lay.Padding = UDim.new(0, 4)
	lay.Parent = f
	return f
end

local racePanel = panel(0.03, "Races")
local classPanel = panel(0.35, "Classes")

local info = Instance.new("TextLabel")
info.Size = UDim2.new(0.28, 0, 0.55, 0)
info.Position = UDim2.new(0.68, 0, 0.14, 0)
info.BackgroundColor3 = Color3.fromRGB(22, 18, 28)
info.TextColor3 = Color3.fromRGB(190, 185, 170)
info.Font = Enum.Font.Gotham
info.TextSize = 14
info.TextWrapped = true
info.TextXAlignment = Enum.TextXAlignment.Left
info.TextYAlignment = Enum.TextYAlignment.Top
info.Parent = frame
Instance.new("UICorner", info).CornerRadius = UDim.new(0, 8)
local infoPad = Instance.new("UIPadding")
infoPad.PaddingLeft = UDim.new(0, 10)
infoPad.PaddingTop = UDim.new(0, 10)
infoPad.Parent = info

local function refreshInfo()
	local r = RacesConfig.Get(raceId)
	local c = ClassesConfig.Get(classId)
	if r and c then
		info.Text = string.format(
			"%s  %s\n\n%s\n\n%s\n\nPassive: %s\n%s\n\nPlaystyle: %s",
			r.DisplayName, c.DisplayName, r.Description, c.Description, r.PassiveName, r.PassiveDesc, c.Playstyle
		)
	end
end

for _, id in RacesConfig.List do
	local r = RacesConfig.Get(id)
	if r then
		local b = Instance.new("TextButton")
		b.Size = UDim2.new(1, -8, 0, 30)
		b.BackgroundColor3 = Color3.fromRGB(40, 35, 50)
		b.Text = r.DisplayName
		b.TextColor3 = Color3.fromRGB(210, 200, 180)
		b.Font = Enum.Font.Gotham
		b.TextSize = 13
		b.Parent = racePanel
		b.MouseButton1Click:Connect(function()
			raceId = id
			refreshInfo()
		end)
	end
end

for _, c in ClassesConfig.GetPlayable() do
	local b = Instance.new("TextButton")
	b.Size = UDim2.new(1, -8, 0, 30)
	b.BackgroundColor3 = Color3.fromRGB(40, 35, 50)
	b.Text = c.DisplayName
	b.TextColor3 = Color3.fromRGB(210, 200, 180)
	b.Font = Enum.Font.Gotham
	b.TextSize = 13
	b.Parent = classPanel
	b.MouseButton1Click:Connect(function()
		classId = c.Id
		refreshInfo()
	end)
end

refreshInfo()

local nameBox = Instance.new("TextBox")
nameBox.Size = UDim2.new(0.4, 0, 0, 36)
nameBox.Position = UDim2.new(0.03, 0, 0.78, 0)
nameBox.BackgroundColor3 = Color3.fromRGB(30, 26, 38)
nameBox.PlaceholderText = "Hero name..."
nameBox.Text = ""
nameBox.TextColor3 = Color3.fromRGB(230, 230, 230)
nameBox.Font = Enum.Font.Gotham
nameBox.TextSize = 16
nameBox.Parent = frame
Instance.new("UICorner", nameBox).CornerRadius = UDim.new(0, 6)

local createBtn = Instance.new("TextButton")
createBtn.Size = UDim2.new(0.28, 0, 0, 40)
createBtn.Position = UDim2.new(0.68, 0, 0.78, 0)
createBtn.BackgroundColor3 = Color3.fromRGB(80, 55, 120)
createBtn.Text = "ENTER AYDRA"
createBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
createBtn.Font = Enum.Font.GothamBold
createBtn.TextSize = 16
createBtn.Parent = frame
Instance.new("UICorner", createBtn).CornerRadius = UDim.new(0, 8)

createBtn.MouseButton1Click:Connect(function()
	createBtn.Text = "CREATING..."
	RemoteRegistry.RE_CreateCharacter:FireServer({
		Name = nameBox.Text,
		Race = raceId,
		Class = classId,
		Appearance = {
			Gender = "Neutral",
			SkinTone = 1,
			HairStyle = "Short",
			HairColor = { 0.2, 0.15, 0.1 },
			EyeColor = { 0.25, 0.35, 0.45 },
			FaceId = "Default",
			Scale = (RacesConfig.Get(raceId) and RacesConfig.Get(raceId).Scale) or 1,
		},
	})
end)

RemoteRegistry.RE_CreateCharacterResult.OnClientEvent:Connect(function(ok, msg)
	if ok then
		createBtn.Text = "DONE"
		createBtn.BackgroundColor3 = Color3.fromRGB(40, 110, 60)
		task.delay(0.8, function()
			screen.Enabled = false
		end)
	else
		createBtn.Text = "ENTER AYDRA"
		warn("Create failed:", msg)
	end
end)

RemoteRegistry.RE_ProfileSync.OnClientEvent:Connect(function(data)
	if data and data.HasCharacter then
		screen.Enabled = false
	end
end)

print("[CharacterCreator] Ready")
