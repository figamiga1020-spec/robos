--!strict

local Players = game:GetService("Players")
local DataService = require(script.Parent.Parent.Parent.Services.DataService)
local ClassesConfig = require(game.ReplicatedStorage.Shared.Config.Classes.ClassesConfig)
local ItemsConfig = require(game.ReplicatedStorage.Shared.Config.Items.ItemsConfig)
local RemoteRegistry = require(game.ReplicatedStorage.Remotes.RemoteRegistry)

local CombatService = {}

local LIGHT_CD = 0.5
local HEAVY_CD = 1.3
local DODGE_COST = 16
local DODGE_IFRAMES = 0.32
local BLOCK_DR = 0.55

type State = {
	LastLight: number,
	LastHeavy: number,
	Blocking: boolean,
	Dodging: boolean,
	DodgeEnd: number,
	Combo: number,
	LastCombo: number,
	SkillCd: { [string]: number },
}

local states: { [number]: State } = {}

local function state(p: Player): State
	local id = p.UserId
	if not states[id] then
		states[id] = {
			LastLight = 0, LastHeavy = 0, Blocking = false, Dodging = false,
			DodgeEnd = 0, Combo = 0, LastCombo = 0, SkillCd = {},
		}
	end
	return states[id]
end

local function weaponDamage(profile: any): number
	local uid = profile.Equipment and profile.Equipment.MainHand
	if not uid then return 6 end
	for _, it in profile.Inventory do
		if it.Uid == uid then
			local def = ItemsConfig.Get(it.ItemId)
			if def and def.Stats and def.Stats.Damage then
				return def.Stats.Damage
			end
		end
	end
	return 6
end

local function calcDamage(profile: any, mult: number, isHeavy: boolean): number
	local wpn = weaponDamage(profile)
	local str = profile.Stats.Strength or 10
	local dex = profile.Stats.Dexterity or 10
	local intel = profile.Stats.Intelligence or 10
	local class = ClassesConfig.Get(profile.Class)
	local scale = str * 0.5 + dex * 0.2
	if class and (profile.Class == "Mage") then
		scale = intel * 0.55
	elseif profile.Class == "Ranger" or profile.Class == "Assassin" then
		scale = dex * 0.5 + str * 0.2
	end
	local base = wpn + scale
	local m = mult * (isHeavy and 1.7 or 1)
	local critChance = (profile.Stats.CriticalChance or 0.05)
	if math.random() < critChance then
		m *= (profile.Stats.CriticalDamage or 1.5)
	end
	return math.max(1, math.floor(base * m + 0.5))
end

local function applyToModel(attacker: Player, target: Model, dmg: number, tags: any?)
	local hum = target:FindFirstChildOfClass("Humanoid")
	if not hum or hum.Health <= 0 then return end

	local tp = Players:GetPlayerFromCharacter(target)
	if tp then
		local ts = state(tp)
		if ts.Dodging then
			RemoteRegistry.RE_CombatResult:FireClient(attacker, { Type = "Miss", Reason = "Dodge" })
			return
		end
		local tProfile = DataService.Get(tp)
		if ts.Blocking then
			dmg = math.floor(dmg * (1 - BLOCK_DR))
		end
		if tProfile then
			local armor = (tProfile.Stats.Armor or 0)
			-- gear armor from chest etc simplified via Stats.Armor updates later
			if armor > 0 then
				dmg = math.max(1, math.floor(dmg * (1 - armor / (armor + 55))))
			end
			tProfile.Health = math.max(0, tProfile.Health - dmg)
			hum.Health = tProfile.Health
			DataService.Sync(tp)
			if tProfile.Health <= 0 then
				-- Death handled by DeathService via humanoid
			end
		end
	else
		hum:TakeDamage(dmg)
	end

	RemoteRegistry.RE_CombatResult:FireAllClients({
		Type = "Hit",
		Attacker = attacker.UserId,
		Damage = dmg,
		Target = tp and tp.UserId or target.Name,
		Tags = tags,
	})
end

local function findTarget(character: Model, range: number): Model?
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then return nil end
	local params = OverlapParams.new()
	params.FilterDescendantsInstances = { character }
	params.FilterType = Enum.RaycastFilterType.Exclude
	local parts = workspace:GetPartBoundsInRadius(root.Position + root.CFrame.LookVector * (range * 0.45), range * 0.55, params)
	for _, part in parts do
		local model = part:FindFirstAncestorOfClass("Model")
		if model and model:FindFirstChildOfClass("Humanoid") then
			return model
		end
	end
	return nil
end

function CombatService.LightAttack(player: Player)
	local profile = DataService.Get(player)
	if not profile or not profile.HasCharacter then return end
	local character = player.Character
	if not character then return end
	local hum = character:FindFirstChildOfClass("Humanoid")
	if not hum or hum.Health <= 0 then return end

	local st = state(player)
	local now = os.clock()
	if st.Dodging or now - st.LastLight < LIGHT_CD then return end
	if profile.Stamina < 4 then return end
	profile.Stamina -= 4
	st.LastLight = now
	if now - st.LastCombo < 1.2 then
		st.Combo = math.min(3, st.Combo + 1)
	else
		st.Combo = 1
	end
	st.LastCombo = now

	local mult = 0.85 + st.Combo * 0.12
	local dmg = calcDamage(profile, mult, false)
	local target = findTarget(character, 10)
	if target then
		applyToModel(player, target, dmg, { Combo = st.Combo })
	else
		RemoteRegistry.RE_CombatResult:FireClient(player, { Type = "Whiff", Style = "Light" })
	end
	DataService.Sync(player)
end

function CombatService.HeavyAttack(player: Player)
	local profile = DataService.Get(player)
	if not profile or not profile.HasCharacter then return end
	local character = player.Character
	if not character then return end
	local st = state(player)
	local now = os.clock()
	if st.Dodging or now - st.LastHeavy < HEAVY_CD then return end
	if profile.Stamina < 12 then return end
	profile.Stamina -= 12
	st.LastHeavy = now
	st.Combo = 0

	local dmg = calcDamage(profile, 1.0, true)
	local target = findTarget(character, 11)
	if target then
		applyToModel(player, target, dmg, { Heavy = true })
	else
		RemoteRegistry.RE_CombatResult:FireClient(player, { Type = "Whiff", Style = "Heavy" })
	end
	DataService.Sync(player)
end

function CombatService.Dodge(player: Player)
	local profile = DataService.Get(player)
	if not profile then return end
	local st = state(player)
	local now = os.clock()
	if st.Dodging or profile.Stamina < DODGE_COST then return end
	profile.Stamina -= DODGE_COST
	st.Dodging = true
	st.Blocking = false
	st.DodgeEnd = now + DODGE_IFRAMES
	RemoteRegistry.RE_CombatResult:FireClient(player, { Type = "Dodge", Duration = DODGE_IFRAMES })
	task.delay(DODGE_IFRAMES, function()
		if states[player.UserId] then states[player.UserId].Dodging = false end
	end)
	DataService.Sync(player)
end

function CombatService.SetBlock(player: Player, on: boolean)
	local st = state(player)
	if st.Dodging then return end
	st.Blocking = on
end

function CombatService.CastSkill(player: Player, skillId: string, targetData: any?)
	local profile = DataService.Get(player)
	if not profile then return end
	local class = ClassesConfig.Get(profile.Class)
	if not class then return end

	local skillDef = nil
	for _, s in class.Skills do
		if s.Id == skillId then skillDef = s break end
	end
	if not skillDef then return end
	if not profile.KnownSkills[skillId] then return end

	local st = state(player)
	local now = os.clock()
	if st.SkillCd[skillId] and now < st.SkillCd[skillId] then
		RemoteRegistry.RE_SkillResult:FireClient(player, { Success = false, Reason = "Cooldown" })
		return
	end
	if profile.Resource < skillDef.ResourceCost then
		RemoteRegistry.RE_SkillResult:FireClient(player, { Success = false, Reason = "Resource" })
		return
	end

	profile.Resource -= skillDef.ResourceCost
	st.SkillCd[skillId] = now + skillDef.Cooldown

	local character = player.Character
	if not character then return end

	local dmg = calcDamage(profile, skillDef.DamageMult or 1, false)

	if skillDef.Type == "Buff" or skillDef.Type == "Self" or skillDef.Type == "Dash" then
		-- Client handles movement dash / VFX; server validates cost only
		RemoteRegistry.RE_SkillResult:FireAllClients({
			Success = true,
			Caster = player.UserId,
			SkillId = skillId,
			Type = skillDef.Type,
			Status = skillDef.Status,
			Duration = skillDef.StatusDuration,
		})
	elseif skillDef.Type == "AoE" then
		local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root then
			local origin = root.Position + root.CFrame.LookVector * math.min(skillDef.Range, 20)
			if targetData and typeof(targetData.Position) == "Vector3" then
				origin = targetData.Position
			end
			local params = OverlapParams.new()
			params.FilterDescendantsInstances = { character }
			params.FilterType = Enum.RaycastFilterType.Exclude
			local radius = 10
			local parts = workspace:GetPartBoundsInRadius(origin, radius, params)
			local hits = 0
			for _, part in parts do
				local model = part:FindFirstAncestorOfClass("Model")
				if model and model:FindFirstChildOfClass("Humanoid") then
					applyToModel(player, model, dmg, { Skill = skillId })
					hits += 1
				end
			end
			RemoteRegistry.RE_SkillResult:FireAllClients({
				Success = true, Caster = player.UserId, SkillId = skillId,
				Type = "AoE", Origin = origin, Radius = radius, Hits = hits,
			})
		end
	else
		local target = findTarget(character, skillDef.Range)
		if target then
			applyToModel(player, target, dmg, { Skill = skillId, Status = skillDef.Status })
		end
		RemoteRegistry.RE_SkillResult:FireAllClients({
			Success = true, Caster = player.UserId, SkillId = skillId, Type = skillDef.Type,
		})
	end

	DataService.Sync(player)
end

function CombatService.Init()
	RemoteRegistry.RE_CombatIntent.OnServerEvent:Connect(function(player, intent, data)
		if intent == "Light" then CombatService.LightAttack(player)
		elseif intent == "Heavy" then CombatService.HeavyAttack(player)
		elseif intent == "Dodge" then CombatService.Dodge(player)
		elseif intent == "BlockStart" then CombatService.SetBlock(player, true)
		elseif intent == "BlockStop" then CombatService.SetBlock(player, false)
		end
	end)
	RemoteRegistry.RE_CastSkill.OnServerEvent:Connect(function(player, skillId, targetData)
		if typeof(skillId) ~= "string" then return end
		CombatService.CastSkill(player, skillId, targetData)
	end)
	Players.PlayerRemoving:Connect(function(p)
		states[p.UserId] = nil
	end)
	print("[CombatService] Ready")
end

return CombatService
