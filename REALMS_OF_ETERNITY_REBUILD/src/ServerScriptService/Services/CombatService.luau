--!strict
--[[
	CombatService — server-authoritative combat core shared by players, enemies, bosses, allies.

	Owns: combatant registry, damage pipeline, healing/shields, statuses, resource & stamina
	regen, movement-speed resolution, server projectiles, telegraph broadcast, threat tables,
	and replication of combat state through model attributes.

	Damage pipeline (ApplyDamage):
	  invulnerable/i-frames → parry window → block (facing, stamina/mana, guard break)
	  → armour/resistance → status multipliers → shield absorb → health → poise/stagger
	  → hit reaction anim → knockback → death.

	Extension points used by PlayerCombat/AI (no core edits needed):
	  CombatService.OutgoingModifiers: { (source, target, info) -> number }  multiplicative
	  Signals: Damaged(target, info, result), Died(target, info), Parried(defender, attacker),
	           Healed(target, amount, source), CombatantAdded(c), CombatantRemoved(c)

	Attributes mirrored on the model (read by HUD, nameplates, AI of other systems):
	  CombatantId, Kind, Team, DisplayName, Level, Health, MaxHealth, Resource, MaxResource,
	  ResourceType, Stamina, MaxStamina, Shield, Dead, Statuses ("Id:stacks:expires,..."),
	  Blocking, InCombat
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Formulas = require(Shared.Logic.Formulas)
local Net = require(Shared.Core.Net)
local Registry = require(Shared.Core.Registry)
local Shapes = require(Shared.Logic.Shapes)
local Signal = require(Shared.Core.Signal)
local Statuses = require(Shared.Config.Statuses)
local Types = require(Shared.Core.Types)

type Stats = Types.Stats
type DamageInfo = Types.DamageInfo
type DamageResult = Types.DamageResult
type Shape = Types.Shape

export type StatusInstance = {
	Id: string,
	Stacks: number,
	Expires: number,
	Magnitude: number?,
	Source: Combatant?,
	NextTick: number,
}

export type Combatant = {
	Id: number,
	Model: Model,
	Root: BasePart,
	Humanoid: Humanoid?,
	Kind: Types.CombatantKind,
	Team: Types.Team,
	Player: Player?,
	Name: string,
	Level: number,
	Stats: Stats,
	Health: number,
	MaxHealth: number,
	Resource: number,
	MaxResource: number,
	ResourceType: string,
	Stamina: number,
	MaxStamina: number,
	Shield: number,
	ShieldExpires: number,
	Statuses: { [string]: StatusInstance },
	Poise: number,
	MaxPoise: number,
	PoiseRegenAt: number,
	HitRadius: number,
	Dead: boolean,
	LastCombat: number,
	StaminaPausedUntil: number,
	SpeedScale: number, -- set by controllers (sprint, aim, AI patrol...)
	Flags: {
		InvulnUntil: number,
		ParryUntil: number,
		SuperArmorUntil: number,
		Blocking: boolean,
		BlockReduction: number,
		BlockCostPerDamage: number,
		BlockUsesResource: boolean,
		MoveLockUntil: number,
	},
	Threat: { [number]: number },
	DamageBy: { [number]: number }, -- combatant id -> total damage dealt (reward credit)
	Data: { [string]: any }, -- domain extension (AI state, class runtime...)
}

local FEEDBACK_RADIUS = 260
local REGEN_STEP = 0.1
local COMBAT_TIMEOUT = 6
local POISE_REGEN_DELAY = 3

local CombatService = {
	Priority = 90,
	CombatantAdded = Signal.new() :: Signal.Signal<Combatant>,
	CombatantRemoved = Signal.new() :: Signal.Signal<Combatant>,
	Damaged = Signal.new() :: Signal.Signal<Combatant, DamageInfo, DamageResult>,
	Died = Signal.new() :: Signal.Signal<Combatant, DamageInfo?>,
	Parried = Signal.new() :: Signal.Signal<Combatant, Combatant?>,
	Healed = Signal.new() :: Signal.Signal<Combatant, number, Combatant?>,
	OutgoingModifiers = {} :: { (Combatant, Combatant, DamageInfo) -> number },
}

local byId: { [number]: Combatant } = {}
local byModel: { [Model]: Combatant } = {}
local nextId = 0
local rng = Random.new()

-- ── Helpers ───────────────────────────────────────────────────────────────────
local function now(): number
	return os.clock()
end

local function setAttr(model: Model, name: string, value: any)
	if model:GetAttribute(name) ~= value then
		model:SetAttribute(name, value)
	end
end

local function roundAttr(value: number): number
	return math.floor(value * 10 + 0.5) / 10
end

local function statusString(c: Combatant): string
	local parts = {}
	local serverNow = Workspace:GetServerTimeNow()
	for id, status in c.Statuses do
		local remaining = math.max(0, status.Expires - now())
		table.insert(parts, `{id}:{status.Stacks}:{math.floor((serverNow + remaining) * 10) / 10}`)
	end
	table.sort(parts)
	return table.concat(parts, ",")
end

local function syncAttributes(c: Combatant)
	local model = c.Model
	setAttr(model, "Health", roundAttr(c.Health))
	setAttr(model, "MaxHealth", c.MaxHealth)
	setAttr(model, "Resource", roundAttr(c.Resource))
	setAttr(model, "MaxResource", c.MaxResource)
	setAttr(model, "Stamina", roundAttr(c.Stamina))
	setAttr(model, "MaxStamina", c.MaxStamina)
	setAttr(model, "Shield", roundAttr(c.Shield))
	setAttr(model, "Dead", c.Dead)
	setAttr(model, "Level", c.Level)
	setAttr(model, "Blocking", c.Flags.Blocking)
	setAttr(model, "InCombat", now() - c.LastCombat < COMBAT_TIMEOUT)
end

local function statusEffect(c: Combatant, key: string): number
	local result = 1
	for id, status in c.Statuses do
		local def = Statuses.Get(id)
		if def then
			local effects = def.Effects :: any
			local value = effects[key]
			if value ~= nil then
				local useMagnitude = def.UseMagnitude
				if status.Magnitude and useMagnitude and (key == useMagnitude .. "Mult") then
					value = status.Magnitude
				end
				if id == "Chill" then
					value = 1 - (1 - value) * status.Stacks
				end
				result *= value
			end
		end
	end
	return result
end

local function statusFlag(c: Combatant, key: string): boolean
	for id in c.Statuses do
		local def = Statuses.Get(id)
		if def and (def.Effects :: any)[key] then
			return true
		end
	end
	return false
end

local function feedback(target: Combatant, payload: { [string]: any })
	payload.T = target.Model
	Net.FireNear(target.Root.Position, FEEDBACK_RADIUS, "CombatFeedback", payload)
end

local function animate(model: Model, clip: string, opts: { [string]: any }?)
	local anim = Registry.Find("AnimationService")
	if anim then
		anim:Play(model, clip, opts)
	end
end

-- ── Registry ──────────────────────────────────────────────────────────────────
export type RegisterOptions = {
	Kind: Types.CombatantKind,
	Team: Types.Team,
	Player: Player?,
	Name: string,
	Level: number,
	Stats: Stats,
	ResourceType: string?,
	StartResourceFull: boolean?,
	HitRadius: number?,
	MaxPoise: number?,
	Data: { [string]: any }?,
}

function CombatService:Register(model: Model, opts: RegisterOptions): Combatant
	local existing = byModel[model]
	if existing then
		self:Unregister(model)
	end
	local root = (model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart) :: BasePart
	assert(root, `Combatant {model:GetFullName()} has no root part`)
	nextId += 1
	local stats = opts.Stats
	local c: Combatant = {
		Id = nextId,
		Model = model,
		Root = root,
		Humanoid = model:FindFirstChildOfClass("Humanoid"),
		Kind = opts.Kind,
		Team = opts.Team,
		Player = opts.Player,
		Name = opts.Name,
		Level = opts.Level,
		Stats = stats,
		Health = stats.MaxHealth,
		MaxHealth = stats.MaxHealth,
		Resource = if opts.StartResourceFull == false then 0 else stats.MaxResource,
		MaxResource = stats.MaxResource,
		ResourceType = opts.ResourceType or "None",
		Stamina = stats.MaxStamina,
		MaxStamina = stats.MaxStamina,
		Shield = 0,
		ShieldExpires = 0,
		Statuses = {},
		Poise = opts.MaxPoise or 50,
		MaxPoise = opts.MaxPoise or 50,
		PoiseRegenAt = 0,
		HitRadius = opts.HitRadius or 1.6,
		Dead = false,
		LastCombat = -math.huge,
		StaminaPausedUntil = 0,
		SpeedScale = 1,
		Flags = {
			InvulnUntil = 0,
			ParryUntil = 0,
			SuperArmorUntil = 0,
			Blocking = false,
			BlockReduction = 0,
			BlockCostPerDamage = 0.6,
			BlockUsesResource = false,
			MoveLockUntil = 0,
		},
		Threat = {},
		DamageBy = {},
		Data = opts.Data or {},
	}
	byId[c.Id] = c
	byModel[model] = c
	model:SetAttribute("CombatantId", c.Id)
	model:SetAttribute("Kind", c.Kind)
	model:SetAttribute("Team", c.Team)
	model:SetAttribute("DisplayName", c.Name)
	model:SetAttribute("ResourceType", c.ResourceType)
	model:SetAttribute("HitRadius", c.HitRadius)
	if c.Humanoid then
		c.Humanoid:SetStateEnabled(Enum.HumanoidStateType.Dead, false)
		c.Humanoid.BreakJointsOnDeath = false
	end
	syncAttributes(c)
	model.Destroying:Connect(function()
		if byModel[model] == c then
			self:Unregister(model)
		end
	end)
	self.CombatantAdded:Fire(c)
	return c
end

function CombatService:Unregister(model: Model)
	local c = byModel[model]
	if not c then
		return
	end
	byModel[model] = nil
	byId[c.Id] = nil
	self.CombatantRemoved:Fire(c)
end

function CombatService:Get(model: Instance?): Combatant?
	if model and model:IsA("Model") then
		return byModel[model]
	end
	return nil
end

function CombatService:GetById(id: number): Combatant?
	return byId[id]
end

function CombatService:GetPlayerCombatant(player: Player): Combatant?
	local character = player.Character
	return character and byModel[character]
end

function CombatService:All(): { [number]: Combatant }
	return byId
end

function CombatService:IsHostile(a: Combatant, b: Combatant): boolean
	return a.Team ~= b.Team and a.Team ~= "Neutral" and b.Team ~= "Neutral"
end

function CombatService:InCombat(c: Combatant): boolean
	return now() - c.LastCombat < COMBAT_TIMEOUT
end

function CombatService:SetStats(c: Combatant, stats: Stats)
	local healthRatio = if c.MaxHealth > 0 then c.Health / c.MaxHealth else 1
	local resourceRatio = if c.MaxResource > 0 then c.Resource / c.MaxResource else 1
	c.Stats = stats
	c.MaxHealth = stats.MaxHealth
	c.MaxResource = stats.MaxResource
	c.MaxStamina = stats.MaxStamina
	if not c.Dead then
		c.Health = math.clamp(c.MaxHealth * healthRatio, 1, c.MaxHealth)
	end
	c.Resource = math.clamp(c.MaxResource * resourceRatio, 0, c.MaxResource)
	c.Stamina = math.min(c.Stamina, c.MaxStamina)
	syncAttributes(c)
end

-- ── State queries ─────────────────────────────────────────────────────────────
function CombatService:HasStatus(c: Combatant, id: string): boolean
	return c.Statuses[id] ~= nil
end

function CombatService:CanAct(c: Combatant): boolean
	return not c.Dead and not statusFlag(c, "PreventsActions")
end

function CombatService:CanMove(c: Combatant): boolean
	return not c.Dead and not statusFlag(c, "PreventsMovement") and now() >= c.Flags.MoveLockUntil
end

function CombatService:IsSilenced(c: Combatant): boolean
	return c.Statuses.Silence ~= nil
end

function CombatService:IsUntargetable(c: Combatant): boolean
	return c.Dead or statusFlag(c, "Untargetable")
end

function CombatService:HasSuperArmor(c: Combatant): boolean
	return now() < c.Flags.SuperArmorUntil or statusFlag(c, "SuperArmor")
end

function CombatService:DamageDealtMult(c: Combatant): number
	return statusEffect(c, "DamageDealtMult")
end

-- Combatants of `team` (or hostile to `exclude` when team is nil) inside the shape.
export type QueryOptions = {
	Team: Types.Team?,
	HostileTo: Combatant?,
	Exclude: { [Combatant]: boolean }?,
	MaxTargets: number?,
	IncludeDead: boolean?,
	IncludeUntargetable: boolean?,
	LineOfSight: boolean?,
}

function CombatService:Query(origin: CFrame, shape: Shape, opts: QueryOptions): { Combatant }
	local results: { { c: Combatant, d: number } } = {}
	local reach = Shapes.Reach(shape) + 12
	local reachSq = reach * reach
	for _, c in byId do
		if c.Dead and not opts.IncludeDead then
			continue
		end
		if opts.Team and c.Team ~= opts.Team then
			continue
		end
		if opts.HostileTo and not self:IsHostile(opts.HostileTo, c) then
			continue
		end
		if opts.Exclude and opts.Exclude[c] then
			continue
		end
		if not opts.IncludeUntargetable and statusFlag(c, "Untargetable") and opts.HostileTo then
			continue
		end
		local delta = c.Root.Position - origin.Position
		local distSq = delta:Dot(delta)
		if distSq > reachSq then
			continue
		end
		-- test the feet-level point so tall rigs are not missed by height tolerance
		local point = c.Root.Position - Vector3.new(0, (c.Root.Size.Y / 2), 0)
		if
			Shapes.Contains(shape, origin, point, c.HitRadius)
			or Shapes.Contains(shape, origin, c.Root.Position, c.HitRadius)
		then
			if opts.LineOfSight then
				local params = RaycastParams.new()
				params.FilterType = Enum.RaycastFilterType.Include
				params.FilterDescendantsInstances = { Workspace.Terrain, Workspace:FindFirstChild("World") :: Instance }
				local from = origin.Position + Vector3.new(0, 3, 0)
				local hit = Workspace:Raycast(from, c.Root.Position - from, params)
				if hit and (hit.Position - c.Root.Position).Magnitude > c.HitRadius + 2 then
					continue
				end
			end
			table.insert(results, { c = c, d = distSq })
		end
	end
	table.sort(results, function(a, b)
		return a.d < b.d
	end)
	local list: { Combatant } = {}
	for index, entry in results do
		if opts.MaxTargets and index > opts.MaxTargets then
			break
		end
		table.insert(list, entry.c)
	end
	return list
end

-- ── Resources ─────────────────────────────────────────────────────────────────
function CombatService:SpendResource(c: Combatant, amount: number): boolean
	if amount <= 0 then
		return true
	end
	if c.Resource + 1e-6 < amount then
		return false
	end
	c.Resource -= amount
	setAttr(c.Model, "Resource", roundAttr(c.Resource))
	return true
end

function CombatService:GiveResource(c: Combatant, amount: number)
	c.Resource = math.clamp(c.Resource + amount, 0, c.MaxResource)
	setAttr(c.Model, "Resource", roundAttr(c.Resource))
end

function CombatService:SpendStamina(c: Combatant, amount: number): boolean
	if amount <= 0 then
		return true
	end
	if c.Stamina + 1e-6 < amount then
		return false
	end
	c.Stamina -= amount
	c.StaminaPausedUntil = now() + 0.8
	setAttr(c.Model, "Stamina", roundAttr(c.Stamina))
	return true
end

function CombatService:AddThreat(target: Combatant, source: Combatant, amount: number)
	target.Threat[source.Id] = (target.Threat[source.Id] or 0) + amount
end

-- ── Statuses ──────────────────────────────────────────────────────────────────
function CombatService:ApplyStatus(target: Combatant, apply: Types.StatusApply, source: Combatant?): boolean
	if target.Dead then
		return false
	end
	local def = Statuses.Get(apply.Id)
	if not def then
		warn(`[Combat] unknown status {apply.Id}`)
		return false
	end
	if apply.Chance and rng:NextNumber() > apply.Chance then
		return false
	end
	if def.Kind == "Debuff" and (now() < target.Flags.InvulnUntil or statusFlag(target, "Invulnerable")) then
		return false
	end
	-- Crowd control against super armour is converted into poise damage instead.
	local isHardCC = apply.Id == "Stun" or apply.Id == "Stagger" or apply.Id == "Knockdown" or apply.Id == "Root"
	if isHardCC and self:HasSuperArmor(target) then
		target.Poise -= 20
		return false
	end
	-- Bosses resist hard CC: shorter durations.
	local duration = apply.Duration
	if isHardCC and (target.Kind == "Boss" or target.Kind == "MiniBoss") then
		duration *= 0.35
	end
	local existing = target.Statuses[apply.Id]
	local t = now()
	if existing then
		existing.Stacks = math.min(def.MaxStacks, existing.Stacks + (apply.Stacks or 1))
		existing.Expires = math.max(existing.Expires, t + duration)
		existing.Magnitude = apply.Magnitude or existing.Magnitude
		existing.Source = source or existing.Source
	else
		target.Statuses[apply.Id] = {
			Id = apply.Id,
			Stacks = math.min(def.MaxStacks, apply.Stacks or 1),
			Expires = t + duration,
			Magnitude = apply.Magnitude,
			Source = source,
			NextTick = t + (def.Tick or 1),
		}
	end
	if apply.Id == "Stun" or apply.Id == "Stagger" or apply.Id == "Knockdown" then
		target.Flags.Blocking = false
		local clip = if apply.Id == "Knockdown" then "Knockdown" else "Stagger"
		animate(target.Model, clip, { Duration = duration })
		local runtime = target.Data.Interrupt
		if type(runtime) == "function" then
			runtime(apply.Id)
		end
	end
	if apply.Id == "Stealth" then
		-- drop all threat on this target
		for _, other in byId do
			other.Threat[target.Id] = nil
		end
	end
	setAttr(target.Model, "Statuses", statusString(target))
	return true
end

function CombatService:RemoveStatus(target: Combatant, id: string)
	if target.Statuses[id] then
		target.Statuses[id] = nil
		setAttr(target.Model, "Statuses", statusString(target))
	end
end

function CombatService:Cleanse(target: Combatant)
	for id in target.Statuses do
		local def = Statuses.Get(id)
		if def and def.Dispellable then
			target.Statuses[id] = nil
		end
	end
	setAttr(target.Model, "Statuses", statusString(target))
end

-- ── Healing & shields ─────────────────────────────────────────────────────────
function CombatService:Heal(target: Combatant, amount: number, source: Combatant?): number
	if target.Dead or amount <= 0 then
		return 0
	end
	local scaled = amount * target.Stats.Recovery * statusEffect(target, "HealingTakenMult")
	local before = target.Health
	target.Health = math.min(target.MaxHealth, target.Health + scaled)
	local healed = target.Health - before
	if healed > 0.5 then
		setAttr(target.Model, "Health", roundAttr(target.Health))
		feedback(target, { A = math.floor(healed + 0.5), H = true, S = source and source.Model })
		self.Healed:Fire(target, healed, source)
	end
	return healed
end

function CombatService:AddShield(target: Combatant, amount: number, duration: number)
	target.Shield = math.max(target.Shield, amount)
	target.ShieldExpires = now() + duration
	setAttr(target.Model, "Shield", roundAttr(target.Shield))
end

-- ── Damage ────────────────────────────────────────────────────────────────────
local function facingFactor(defender: Combatant, from: Vector3): number
	local look = defender.Root.CFrame.LookVector
	local delta = Vector3.new(from.X - defender.Root.Position.X, 0, from.Z - defender.Root.Position.Z)
	if delta.Magnitude < 0.1 then
		return 1
	end
	return Vector3.new(look.X, 0, look.Z).Unit:Dot(delta.Unit)
end

local function applyKnockback(target: Combatant, velocity: Vector3)
	if target.Kind == "Boss" or target.Kind == "MiniBoss" or CombatService:HasSuperArmor(target) then
		return
	end
	if target.Player then
		Net.FireClient(target.Player, "Knockback", velocity)
	else
		local root = target.Root
		root.AssemblyLinearVelocity =
			Vector3.new(velocity.X, math.max(root.AssemblyLinearVelocity.Y, velocity.Y), velocity.Z)
	end
end

function CombatService:ApplyDamage(target: Combatant, info: DamageInfo): DamageResult
	local result: DamageResult = {
		Applied = 0,
		Absorbed = 0,
		Blocked = false,
		Parried = false,
		Dodged = false,
		Killed = false,
		IsCrit = info.IsCrit == true,
		GuardBroken = false,
	}
	if target.Dead then
		return result
	end
	local source = info.Source :: Combatant?
	local t = now()
	local fromPos = info.Position or (source and source.Root.Position) or target.Root.Position
	target.LastCombat = t
	if source then
		source.LastCombat = t
	end

	-- 1. Evasion / invulnerability
	if info.CanDodge ~= false and (t < target.Flags.InvulnUntil or statusFlag(target, "Invulnerable")) then
		result.Dodged = true
		feedback(target, { D = true, S = source and source.Model })
		return result
	elseif t < target.Flags.InvulnUntil and statusFlag(target, "Invulnerable") then
		result.Dodged = true
		return result
	end

	-- 2. Parry (front only)
	if info.CanParry ~= false and t < target.Flags.ParryUntil and facingFactor(target, fromPos) > 0.2 then
		result.Parried = true
		feedback(target, { P = true, S = source and source.Model })
		if source and not source.Dead then
			if source.Kind == "Boss" then
				source.Poise -= 35
			else
				self:ApplyStatus(source, { Id = "Stagger", Duration = 1.1 }, target)
			end
		end
		self.Parried:Fire(target, source)
		return result
	end

	local amount = info.Amount

	-- 3. Block
	if target.Flags.Blocking and info.CanBlock ~= false and facingFactor(target, fromPos) > 0.25 then
		result.Blocked = true
		local blockedAmount = amount * target.Flags.BlockReduction
		local cost = blockedAmount * target.Flags.BlockCostPerDamage
		local pool = if target.Flags.BlockUsesResource then target.Resource else target.Stamina
		if pool >= cost then
			if target.Flags.BlockUsesResource then
				target.Resource -= cost
			else
				target.Stamina -= cost
				target.StaminaPausedUntil = t + 0.8
			end
			amount -= blockedAmount
		else
			-- guard break: the block collapses and the defender staggers
			result.GuardBroken = true
			if target.Flags.BlockUsesResource then
				target.Resource = 0
			else
				target.Stamina = 0
			end
			target.Flags.Blocking = false
			self:ApplyStatus(target, { Id = "Stagger", Duration = 1.2 }, source :: any)
		end
	end

	-- 4. Mitigation + status multipliers
	local attackerLevel = if source then source.Level else target.Level
	amount = Formulas.MitigatedDamage(amount, info.Type, target.Stats, attackerLevel)
	amount *= statusEffect(target, "DamageTakenMult")
	amount = math.max(if result.Blocked then 0 else 1, amount)

	-- 5. Shield absorb
	if target.Shield > 0 then
		local absorbed = math.min(target.Shield, amount)
		target.Shield -= absorbed
		amount -= absorbed
		result.Absorbed = absorbed
	end

	-- 6. Health
	amount = math.floor(amount + 0.5)
	target.Health = math.max(0, target.Health - amount)
	result.Applied = amount
	if source then
		target.DamageBy[source.Id] = (target.DamageBy[source.Id] or 0) + amount + result.Absorbed
		if target.Kind ~= "Player" then
			target.Threat[source.Id] = (target.Threat[source.Id] or 0)
				+ (amount + result.Absorbed) * ((source.Data.ThreatMult :: number?) or 1)
		end
	end

	-- 7. Poise / stagger and hit reaction
	if not result.Blocked and target.Health > 0 then
		local superArmor = self:HasSuperArmor(target)
		if info.Poise and info.Poise > 0 then
			target.Poise -= info.Poise * (if superArmor then 0.4 else 1)
			target.PoiseRegenAt = t + POISE_REGEN_DELAY
			if target.Poise <= 0 then
				target.Poise = target.MaxPoise
				local staggerTime = if target.Kind == "Boss" then 2.5 elseif target.Kind == "MiniBoss" then 1.8 else 1.4
				if target.Kind == "Boss" or target.Kind == "MiniBoss" then
					target.Statuses.Stagger =
						{ Id = "Stagger", Stacks = 1, Expires = t + staggerTime, NextTick = t + 99, Source = source }
					animate(target.Model, "Stagger", { Duration = staggerTime })
					local interrupt = target.Data.Interrupt
					if type(interrupt) == "function" then
						interrupt("Stagger")
					end
					setAttr(target.Model, "Statuses", statusString(target))
				else
					self:ApplyStatus(target, { Id = "Stagger", Duration = staggerTime }, source :: any)
				end
			end
		end
		if not superArmor and info.Reaction and info.Reaction ~= "None" and not target.Statuses.Stagger then
			animate(target.Model, if info.Reaction == "Heavy" then "HitHeavy" else "HitLight", nil)
			local interrupt = target.Data.Interrupt
			if info.Reaction == "Heavy" and type(interrupt) == "function" and target.Kind ~= "Boss" then
				interrupt("HitHeavy")
			end
		end
	end

	-- 8. Knockback
	if info.Knockback and info.Knockback.Magnitude > 0 and not result.Blocked then
		applyKnockback(target, info.Knockback)
	end

	syncAttributes(target)
	feedback(target, {
		A = amount,
		Ty = info.Type,
		C = result.IsCrit or nil,
		B = result.Blocked or nil,
		G = result.GuardBroken or nil,
		Ab = info.Ability,
		S = source and source.Model,
		Pos = info.Position,
	})

	-- 9. Death
	if target.Health <= 0 then
		result.Killed = true
		self:Kill(target, info)
	end

	self.Damaged:Fire(target, info, result)
	return result
end

export type DealOptions = {
	Multiplier: number?,
	Poise: number?,
	Reaction: Types.Reaction?,
	Knockback: number?, -- studs/s away from `KnockbackFrom` (or source)
	KnockbackFrom: Vector3?,
	Ability: string?,
	Position: Vector3?,
	Tags: { [string]: boolean }?,
}

-- Rolls damage from the source's stats and applies it. Used by every attack in the game.
function CombatService:DealDamage(
	source: Combatant,
	target: Combatant,
	spec: Types.DamageSpec,
	opts: DealOptions?
): DamageResult
	local options: DealOptions = opts or {}
	local info: DamageInfo = {
		Amount = 0,
		Type = spec.Type,
		Source = source,
		Ability = options.Ability,
		CanBlock = spec.CanBlock,
		CanParry = spec.CanParry,
		CanDodge = spec.CanDodge,
		Poise = options.Poise,
		Reaction = options.Reaction,
		Position = options.Position,
		Tags = options.Tags,
	}
	local multiplier = (options.Multiplier or 1) * statusEffect(source, "DamageDealtMult")
	for _, modifier in self.OutgoingModifiers do
		local ok, value = pcall(modifier, source, target, info)
		if ok and type(value) == "number" then
			multiplier *= value
		end
	end
	local roll = Formulas.RollDamage(source.Stats, spec, multiplier, function()
		return rng:NextNumber()
	end)
	info.Amount = roll.Amount
	info.IsCrit = roll.IsCrit
	if options.Knockback and options.Knockback > 0 then
		local from = options.KnockbackFrom or source.Root.Position
		local direction = target.Root.Position - from
		direction = Vector3.new(direction.X, 0, direction.Z)
		if direction.Magnitude < 0.1 then
			direction = source.Root.CFrame.LookVector
		end
		info.Knockback = direction.Unit * options.Knockback + Vector3.new(0, options.Knockback * 0.35, 0)
	end
	return self:ApplyDamage(target, info)
end

function CombatService:Kill(target: Combatant, info: DamageInfo?)
	if target.Dead then
		return
	end
	target.Dead = true
	target.Health = 0
	target.Shield = 0
	target.Flags.Blocking = false
	table.clear(target.Statuses)
	setAttr(target.Model, "Statuses", "")
	syncAttributes(target)
	animate(target.Model, "Death", { Hold = true })
	if target.Humanoid then
		target.Humanoid.WalkSpeed = 0
		target.Humanoid.JumpHeight = 0
	end
	self.Died:Fire(target, info)
end

function CombatService:Revive(target: Combatant, healthFraction: number)
	target.Dead = false
	target.Health = math.max(1, target.MaxHealth * healthFraction)
	target.Stamina = target.MaxStamina
	target.Poise = target.MaxPoise
	target.Threat = {}
	target.DamageBy = {}
	target.LastCombat = -math.huge
	syncAttributes(target)
	local anim = Registry.Find("AnimationService")
	if anim then
		anim:Stop(target.Model, "Death")
	end
end

-- ── Telegraphs ────────────────────────────────────────────────────────────────
export type TelegraphSpec = {
	Shape: Shape,
	CFrame: CFrame,
	Duration: number,
	Style: ("Enemy" | "Boss" | "Player" | "Safe")?,
	Follow: Model?, -- telegraph tracks this model until it resolves
}

local telegraphId = 0
function CombatService:Telegraph(spec: TelegraphSpec): number
	telegraphId += 1
	Net.FireNear(spec.CFrame.Position, 400, "Telegraph", {
		Id = telegraphId,
		Shape = spec.Shape,
		CFrame = spec.CFrame,
		Duration = spec.Duration,
		Style = spec.Style or "Enemy",
		Follow = spec.Follow,
		Start = Workspace:GetServerTimeNow(),
	})
	return telegraphId
end

function CombatService:CancelTelegraph(id: number)
	Net.FireAll("TelegraphCancel", id)
end

-- ── Projectiles ───────────────────────────────────────────────────────────────
export type ProjectileSpec = {
	Source: Combatant,
	Origin: Vector3,
	Direction: Vector3,
	Speed: number,
	Range: number,
	Radius: number,
	Gravity: number?,
	Homing: number?,
	Target: Combatant?,
	Pierce: number?,
	Visual: string,
	OnHit: (target: Combatant, position: Vector3) -> (),
	OnEnd: ((position: Vector3, hitSomething: boolean) -> ())?,
}

type LiveProjectile = {
	Id: number,
	Spec: ProjectileSpec,
	Position: Vector3,
	Velocity: Vector3,
	Travelled: number,
	Hit: { [Combatant]: boolean },
	PierceLeft: number,
}

local projectiles: { [number]: LiveProjectile } = {}
local projectileId = 0
local worldRayParams = RaycastParams.new()
worldRayParams.FilterType = Enum.RaycastFilterType.Include

function CombatService:FireProjectile(spec: ProjectileSpec): number
	projectileId += 1
	local direction = if spec.Direction.Magnitude > 1e-3
		then spec.Direction.Unit
		else spec.Source.Root.CFrame.LookVector
	local live: LiveProjectile = {
		Id = projectileId,
		Spec = spec,
		Position = spec.Origin,
		Velocity = direction * spec.Speed,
		Travelled = 0,
		Hit = {},
		PierceLeft = spec.Pierce or 0,
	}
	projectiles[projectileId] = live
	Net.FireNear(spec.Origin, 450, "Projectile", {
		Id = projectileId,
		Visual = spec.Visual,
		Origin = spec.Origin,
		Velocity = live.Velocity,
		Gravity = spec.Gravity or 0,
		Homing = spec.Homing or 0,
		Target = spec.Target and spec.Target.Model,
		Range = spec.Range,
		Source = spec.Source.Model,
	})
	return projectileId
end

local function endProjectile(live: LiveProjectile, position: Vector3, hitSomething: boolean)
	projectiles[live.Id] = nil
	Net.FireNear(position, 450, "ProjectileEnd", live.Id, position, hitSomething)
	if live.Spec.OnEnd then
		task.spawn(live.Spec.OnEnd, position, hitSomething)
	end
end

local function stepProjectiles(dt: number)
	if next(projectiles) == nil then
		return
	end
	local world = Workspace:FindFirstChild("World")
	worldRayParams.FilterDescendantsInstances = if world then { Workspace.Terrain, world } else { Workspace.Terrain }
	for _, live in projectiles do
		local spec = live.Spec
		local target = spec.Target
		if spec.Homing and spec.Homing > 0 and target and not target.Dead then
			local desired = (target.Root.Position - live.Position)
			if desired.Magnitude > 0.5 then
				local current = live.Velocity.Unit
				local wanted = desired.Unit
				local angle = math.acos(math.clamp(current:Dot(wanted), -1, 1))
				local maxTurn = spec.Homing * dt
				local alpha = if angle > 1e-3 then math.min(1, maxTurn / angle) else 1
				live.Velocity = current:Lerp(wanted, alpha).Unit * spec.Speed
			end
		end
		if spec.Gravity and spec.Gravity > 0 then
			live.Velocity -= Vector3.new(0, spec.Gravity * dt, 0)
		end
		local step = live.Velocity * dt
		local from = live.Position
		local to = from + step

		-- combatant collision along the segment
		local segment = to - from
		local segLenSq = segment:Dot(segment)
		local ended = false
		for _, c in byId do
			if c.Dead or live.Hit[c] or not CombatService:IsHostile(spec.Source, c) then
				continue
			end
			if statusFlag(c, "Untargetable") then
				continue
			end
			local toTarget = c.Root.Position - from
			local t = if segLenSq > 0 then math.clamp(toTarget:Dot(segment) / segLenSq, 0, 1) else 0
			local closest = from + segment * t
			local radius = spec.Radius + c.HitRadius
			-- vertical extent: treat the body as a capsule around the root
			local offset = c.Root.Position - closest
			local horizontal = Vector3.new(offset.X, 0, offset.Z).Magnitude
			if horizontal <= radius and math.abs(offset.Y) <= c.Root.Size.Y / 2 + 2.5 + spec.Radius then
				live.Hit[c] = true
				task.spawn(spec.OnHit, c, closest)
				if live.PierceLeft > 0 then
					live.PierceLeft -= 1
				else
					endProjectile(live, closest, true)
					ended = true
					break
				end
			end
		end
		if ended then
			continue
		end

		local ray = Workspace:Raycast(from, step, worldRayParams)
		if ray then
			endProjectile(live, ray.Position, false)
			continue
		end
		live.Position = to
		live.Travelled += step.Magnitude
		if live.Travelled >= spec.Range then
			endProjectile(live, to, false)
		end
	end
end

-- ── Regeneration / status ticking / movement ──────────────────────────────────
local function regenTick(dt: number)
	local t = now()
	for _, c in byId do
		if c.Dead then
			continue
		end
		local changedStatus = false
		-- statuses
		for id, status in c.Statuses do
			local def = Statuses.Get(id)
			if t >= status.Expires then
				c.Statuses[id] = nil
				changedStatus = true
				continue
			end
			if def and def.Tick and t >= status.NextTick then
				status.NextTick += def.Tick
				local magnitude = (status.Magnitude or 3) * status.Stacks
				if def.DamageType then
					local sourceLevel = if status.Source then status.Source.Level else c.Level
					local service: any = CombatService
					service:ApplyDamage(
						c,
						{
							Amount = magnitude * (1 + 0.15 * (sourceLevel - 1)),
							Type = def.DamageType :: any,
							Source = status.Source,
							CanBlock = false,
							CanParry = false,
							CanDodge = false,
							Ability = id,
							Tags = { DoT = true },
						} :: DamageInfo
					)
					if c.Dead then
						break
					end
				elseif def.HealPerTick then
					CombatService:Heal(c, magnitude, status.Source)
				end
			end
		end
		if c.Dead then
			continue
		end
		if changedStatus then
			setAttr(c.Model, "Statuses", statusString(c))
		end
		-- shield expiry
		if c.Shield > 0 and t >= c.ShieldExpires then
			c.Shield = 0
		end
		-- health regen (stronger out of combat)
		local inCombat = t - c.LastCombat < COMBAT_TIMEOUT
		if c.Health < c.MaxHealth then
			local rate = c.Stats.HealthRegen * (if inCombat then 1 else 4)
			if c.Kind ~= "Player" and not inCombat then
				rate = c.MaxHealth * 0.2 -- enemies reset quickly when leashed
			end
			c.Health = math.min(c.MaxHealth, c.Health + rate * dt)
		end
		-- class resource
		if c.ResourceType == "Resolve" then
			if not inCombat then
				c.Resource = math.max(0, c.Resource - 4 * dt)
			else
				c.Resource = math.min(c.MaxResource, c.Resource + c.Stats.ResourceRegen * dt)
			end
		elseif c.Resource < c.MaxResource then
			c.Resource = math.min(c.MaxResource, c.Resource + c.Stats.ResourceRegen * dt)
		end
		-- stamina
		if c.Stamina < c.MaxStamina and t >= c.StaminaPausedUntil and not c.Flags.Blocking then
			c.Stamina = math.min(c.MaxStamina, c.Stamina + c.Stats.StaminaRegen * dt)
		end
		-- poise
		if t >= c.PoiseRegenAt and c.Poise < c.MaxPoise then
			c.Poise = math.min(c.MaxPoise, c.Poise + c.MaxPoise * 0.25 * dt)
		end
		-- movement
		local humanoid = c.Humanoid
		if humanoid then
			local canMove = CombatService:CanMove(c)
			local speed = c.Stats.MoveSpeed * statusEffect(c, "MoveSpeedMult") * c.SpeedScale
			if c.Flags.Blocking then
				speed *= 0.5
			end
			humanoid.WalkSpeed = if canMove then math.max(0, speed) else 0
			if c.Player then
				humanoid.JumpHeight = if canMove and CombatService:CanAct(c) then 7.5 else 0
			end
		end
		syncAttributes(c)
	end
end

function CombatService:Init()
	Net.DeclareUnreliable("CombatFeedback")
	local accumulator = 0
	RunService.Heartbeat:Connect(function(dt)
		stepProjectiles(dt)
		accumulator += dt
		if accumulator >= REGEN_STEP then
			local step = accumulator
			accumulator = 0
			regenTick(step)
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		local character = player.Character
		if character then
			self:Unregister(character)
		end
	end)
end

return CombatService
