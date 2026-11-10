--!strict

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local CollectionService = game:GetService("CollectionService")

local DataService = require(script.Parent.Parent.Parent.Services.DataService)
local InventoryService = require(script.Parent.Parent.Inventory.InventoryService)
local QuestService = require(script.Parent.Parent.Quest.QuestService)
local PartyService = require(script.Parent.Parent.Party.PartyService)
local EnemiesConfig = require(game.ReplicatedStorage.Shared.Config.Enemies.EnemiesConfig)
local RemoteRegistry = require(game.ReplicatedStorage.Remotes.RemoteRegistry)

local EnemyService = {}

local TAG = "ROE_Enemy"
local active: { [string]: any } = {}

local function createModel(def: any, cf: CFrame): Model
	local model = Instance.new("Model")
	model.Name = def.DisplayName
	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	local scale = def.Scale or 1
	root.Size = Vector3.new(2, 2, 1) * scale
	root.CFrame = cf
	root.Anchored = false
	root.CanCollide = true
	root.Color = def.Type == "Boss" and Color3.fromRGB(40, 90, 40)
		or def.Type == "MiniBoss" and Color3.fromRGB(90, 70, 30)
		or Color3.fromRGB(70, 60, 50)
	root.Material = Enum.Material.SmoothPlastic
	root.Parent = model

	local hum = Instance.new("Humanoid")
	local partyScale = 1
	-- solo default; boss service overrides health when needed
	hum.MaxHealth = def.Health
	hum.Health = def.Health
	hum.WalkSpeed = 12 * (def.Speed or 1)
	hum.Parent = model
	model.PrimaryPart = root
	CollectionService:AddTag(model, TAG)
	model:SetAttribute("EnemyId", def.Id)
	model:SetAttribute("IsBoss", def.Type == "Boss")

	if def.Id == "ForestGuardian" then
		local BossVisuals = require(script.Parent.Parent.Boss.BossVisuals)
		BossVisuals.EnhanceForestGuardian(model)
	elseif def.Type == "MiniBoss" then
		root.Size = Vector3.new(3.5, 5, 2.5)
		root.Material = Enum.Material.Slate
	elseif def.Id == "CorruptedWolf" then
		root.Size = Vector3.new(3, 1.8, 5)
		root.Color = Color3.fromRGB(50, 40, 55)
	elseif def.Id == "RootCultist" then
		root.Color = Color3.fromRGB(40, 60, 40)
	end

	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.new(0, 140, 0, 28)
	bb.StudsOffset = Vector3.new(0, 3 * scale, 0)
	bb.AlwaysOnTop = true
	bb.Parent = root
	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 1, 0)
	label.BackgroundTransparency = 1
	label.Text = def.DisplayName .. " [" .. def.Level .. "]"
	label.TextColor3 = def.Type == "Boss" and Color3.fromRGB(255, 180, 80) or Color3.fromRGB(220, 210, 190)
	label.Font = Enum.Font.GothamBold
	label.TextSize = 12
	label.Parent = bb
	return model
end

local function reward(player: Player, def: any)
	local profile = DataService.Get(player)
	if not profile then return end
	profile.Experience += def.Experience
	local need = profile.Level * 100
	while profile.Experience >= need do
		profile.Experience -= need
		profile.Level += 1
		need = profile.Level * 100
	end
	local gold = math.random(def.GoldMin, def.GoldMax)
	profile.Currency.Gold += gold
	for _, entry in def.Loot do
		if math.random() <= entry.Chance then
			InventoryService.AddItem(player, entry.ItemId, math.random(entry.Min, entry.Max))
		end
	end
	DataService.Save(player)
	DataService.Sync(player)
	QuestService.OnKill(player, def.Id)
	RemoteRegistry.RE_CombatResult:FireClient(player, {
		Type = "KillReward",
		Enemy = def.DisplayName,
		Experience = def.Experience,
		Gold = gold,
	})
end

local function tickEnemy(state: any, _dt: number)
	if state.Dead then return end
	local def = EnemiesConfig.Get(state.DefId)
	if not def then return end
	local hum = state.Humanoid
	if hum.Health <= 0 then
		state.Dead = true
		local closest: Player? = nil
		local best = 40
		for _, p in Players:GetPlayers() do
			if p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
				local d = (p.Character.HumanoidRootPart.Position - state.Root.Position).Magnitude
				if d < best then best = d closest = p end
			end
		end
		if closest then reward(closest, def) end
		task.delay(4, function()
			if state.Model then state.Model:Destroy() end
			active[state.Id] = nil
		end)
		return
	end

	-- Aggro
	if not state.Target or not state.Target.Character then
		state.Target = nil
		for _, p in Players:GetPlayers() do
			local char = p.Character
			if char and char:FindFirstChild("HumanoidRootPart") then
				local d = (char.HumanoidRootPart.Position - state.Root.Position).Magnitude
				if d <= def.AggroRange then
					state.Target = p
					break
				end
			end
		end
	end

	if state.Target and state.Target.Character then
		local tr = state.Target.Character:FindFirstChild("HumanoidRootPart")
		local th = state.Target.Character:FindFirstChildOfClass("Humanoid")
		if tr and th and th.Health > 0 then
			local dist = (tr.Position - state.Root.Position).Magnitude
			if dist > def.LeashRange then
				state.Target = nil
				hum:MoveTo(state.SpawnCF.Position)
				return
			end
			if dist > def.AttackRange then
				hum:MoveTo(tr.Position)
			else
				hum:MoveTo(state.Root.Position)
				local now = os.clock()
				if now - state.LastAttack >= def.AttackCooldown and def.Damage > 0 then
					state.LastAttack = now
					local profile = DataService.Get(state.Target)
					if profile then
						local dmg = def.Damage
						profile.Health = math.max(0, profile.Health - dmg)
						th.Health = profile.Health
						DataService.Sync(state.Target)
						RemoteRegistry.RE_CombatResult:FireClient(state.Target, {
							Type = "IncomingHit",
							Damage = dmg,
							Source = def.DisplayName,
						})
					end
				end
			end
		else
			state.Target = nil
		end
	end
end

function EnemyService.Spawn(defId: string, cf: CFrame, healthOverride: number?): string?
	local def = EnemiesConfig.Get(defId)
	if not def then return nil end
	local model = createModel(def, cf)
	if healthOverride then
		local hum = model:FindFirstChildOfClass("Humanoid")
		if hum then
			hum.MaxHealth = healthOverride
			hum.Health = healthOverride
		end
	end
	model.Parent = workspace
	local id = HttpService:GenerateGUID(false)
	active[id] = {
		Id = id,
		DefId = defId,
		Model = model,
		Humanoid = model:FindFirstChildOfClass("Humanoid"),
		Root = model.PrimaryPart,
		SpawnCF = cf,
		Target = nil,
		LastAttack = 0,
		Dead = false,
	}
	model:SetAttribute("InstanceId", id)
	return id
end

function EnemyService.SpawnEldoriaDefaults()
	local spots = {
		{ "ForestBrigand", CFrame.new(520, 14, 20) },
		{ "ForestBrigand", CFrame.new(560, 14, -25) },
		{ "ForestBrigand", CFrame.new(600, 14, 10) },
		{ "CorruptedWolf", CFrame.new(680, 15, 60) },
		{ "CorruptedWolf", CFrame.new(720, 15, 40) },
		{ "CorruptedWolf", CFrame.new(740, 15, 90) },
		{ "RootCultist", CFrame.new(1180, 17, -20) },
		{ "RootCultist", CFrame.new(1210, 17, 25) },
		{ "RootCultist", CFrame.new(1220, 17, -15) },
		{ "TempleSentinel", CFrame.new(1240, 17, 0) },
	}
	for _, e in spots do
		EnemyService.Spawn(e[1], e[2])
	end
end

function EnemyService.Init()
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc < 0.2 then return end
		acc = 0
		for _, st in active do
			tickEnemy(st, 0.2)
		end
	end)
	task.defer(function()
		EnemyService.SpawnEldoriaDefaults()
	end)
	print("[EnemyService] Ready")
end

return EnemyService
