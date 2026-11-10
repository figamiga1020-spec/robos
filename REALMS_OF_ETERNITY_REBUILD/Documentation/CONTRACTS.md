# REALMS OF ETERNITY — Integration Contracts

This file is the binding contract between all systems. Every module must follow it. If a system
needs something that is not here, it must implement it **inside its own write set** and document
it in its final report — never edit another system's files.

## 0. Ground rules

- Luau, `--!strict` everywhere (pure data config files may be `--!nonstrict`). Zero `TypeError`s
  from `luau-lsp analyze`, zero selene errors, `stylua` formatted. Brief comments only for
  non-obvious intent.
- Player-facing text is **Russian**. Code identifiers English.
- **No fake asset IDs.** No `rbxassetid://` numbers. Allowed built-in content only:
  - particles: `rbxasset://textures/particles/{sparkles_main,fire_main,fire_sparks_main,smoke_main,explosion01_core_main,explosion01_shockwave_main,explosion01_implosion_main,explosion01_smoke_main,forcefield_glow_main,forcefield_vortex_main}.dds`, `rbxasset://textures/particles/SquareParticle.png`
  - sounds: `rbxasset://sounds/{action_jump,action_jump_land,action_footsteps_plastic,action_get_up,action_swim,impact_water,impact_explosion_03}.mp3`, `rbxasset://sounds/{action_falling,oof,ouch,volume_slider}.ogg`
  - fonts: `rbxasset://fonts/families/<Name>.json` for Merriweather, Montserrat, Oswald, GrenzeGotisch (Latin only), Fondamento (Latin only), RomanAntique, Roboto, SourceSansPro.
  - Everything else (music, unique SFX, meshes) is listed in `Documentation/AssetManifest.md` as a
    spec and the code must degrade gracefully when the asset is absent.
- Geometry is procedural (Parts, WedgeParts, CornerWedgeParts, cylinders/balls, `SpecialMesh`
  with built-in `MeshType` Head/Sphere/Cylinder/Wedge, Terrain API). Name every part meaningfully
  (no `Part`, `Part1`). Decorative parts: `CanCollide=false, CanQuery=false, CanTouch=false`.
  Group large structures into Models; set `ModelStreamingMode` Atomic for rigs.
- Server is authoritative. Every client→server remote goes through `Net.Handle`/`Net.HandleInvoke`
  with `Validate` checkers and a rate limit.
- Use `Registry.Get("XService")` at call time (inside functions), never at require time.

## 1. Project layout

```
src/ReplicatedStorage/Shared/
  Core/        Net, Registry, Signal, Trove, Types, Util
  Logic/       pure: Validate, RateLimiter, Shapes, Formulas, DataSchema, Easing (+ your pure logic)
  Config/      Races, Classes, Items, Statuses, Scaling, Keybinds, WorldLayout (+ Enemies, Bosses, Quests, Dialogues, NPCs, Events, Factions, Sounds)
  Modules/     Anchors (+ Rig/*, Creatures/*)
  Animations/  Anim, AnimationLibrary, AnimationPlayer, Sets/** (AnimSet modules)
src/ServerScriptService/
  Bootstrap/Main.server.luau     boots Services/* (*Service, Init → Start)
  Services/    *Service modules (auto-discovered, optional `Priority` number: higher inits first)
  World/       builders (not services): Capital/*, Eldoria/*, Dungeon/*, Kit/*
  QA/          in-Studio smoke tests
src/StarterPlayer/StarterPlayerScripts/
  ClientMain.client.luau         boots Controllers/* (*Controller)
  Controllers/ *Controller modules
  Core/        PlayerState
  UI/          Theme, Components, Screens/** (auto-discovered by UIController)
tests/specs/*.spec.luau          Lune unit tests (T.describe/T.it/T.expect, T.load("ReplicatedStorage/Shared/..."))
```

Verification commands (run from `REALMS_OF_ETERNITY_REBUILD/`, use a private sourcemap path):
```
export PATH=$HOME/.local/bin:$PATH
rojo sourcemap default.project.json -o /tmp/sm-$NAME.json
luau-lsp analyze --sourcemap /tmp/sm-$NAME.json --definitions=$PWD/.tools/globalTypes.d.luau --base-luaurc .luaurc --formatter plain <your paths>
selene --display-style quiet <your paths>
stylua <your paths>
lune run tests/run.luau
rojo build default.project.json -o /tmp/$NAME.rbxl
```
Do not run shell scripts you wrote (`bash x.sh`), heredocs, or `python3 -c` — the sandbox blocks
them; call the tools directly and use file-editing tools.

## 2. Existing core APIs (already implemented)

### Net (Shared/Core/Net)
Server: `Net.Handle(name, {Args={...}, Rate={cap, perSec}}, fn(player, ...))`, `Net.HandleInvoke`,
`Net.FireClient(p, name, ...)`, `FireAll`, `FireList(players, ...)`, `FireAllExcept(p, ...)`,
`FireNear(pos, radius, name, ...)`, `Net.DeclareUnreliable(name)`.
Client: `Net.Fire(name, ...)`, `Net.Invoke(name, ...) -> ...` (returns `false, reason` on failure), `Net.On(name, fn)`.

### DataService (server)
`GetProfile(p)`, `WaitForProfile(p)`, `GetCharacter(p) -> CharacterRecord?` (mutable; it is the save),
`GetActiveId(p)`, `SetActiveCharacter(p, id)`, `AddCharacter(p, record)`, `DeleteCharacter(p, id)`,
`NewUid()`, `MarkDirty(p, section)`, `PushSection(p, section, data)`, `Save(p, reason, force?)`, `IsMock()`.
Signals: `ProfileLoaded(p, profile)`, `ProfileReleasing(p, profile)`, `CharacterActivated(p, record)`.
Persisted sections: Account, Character, Inventory, Equipment, Hotbar, Quests, World, Settings, Bank.
**After mutating a CharacterRecord field call `MarkDirty` for the matching section.**

### CombatService (server)
`Register(model, {Kind, Team, Player?, Name, Level, Stats, ResourceType?, StartResourceFull?, HitRadius?, MaxPoise?, Data?}) -> Combatant`,
`Unregister(model)`, `Get(model)`, `GetById`, `GetPlayerCombatant(p)`, `All()`, `IsHostile(a,b)`, `InCombat(c)`,
`SetStats(c, stats)`, `HasStatus`, `CanAct`, `CanMove`, `IsSilenced`, `IsUntargetable`, `HasSuperArmor`,
`Query(originCF, shape, {Team?, HostileTo?, Exclude?, MaxTargets?, IncludeDead?, LineOfSight?}) -> {Combatant}`,
`SpendResource`, `GiveResource`, `SpendStamina`, `AddThreat`, `ApplyStatus(target, StatusApply, source?)`,
`RemoveStatus`, `Cleanse`, `Heal(target, amount, source?)`, `AddShield(target, amount, duration)`,
`ApplyDamage(target, DamageInfo) -> DamageResult`,
`DealDamage(source, target, DamageSpec, {Multiplier?, Poise?, Reaction?, Knockback?, KnockbackFrom?, Ability?, Position?, Tags?}) -> DamageResult`,
`Kill(c, info?)`, `Revive(c, fraction)`,
`Telegraph({Shape, CFrame, Duration, Style?("Enemy"|"Boss"|"Player"|"Safe"), Follow?}) -> id`, `CancelTelegraph(id)`,
`FireProjectile({Source, Origin, Direction, Speed, Range, Radius, Gravity?, Homing?, Target?, Pierce?, Visual, OnHit(target,pos), OnEnd?(pos, hit)}) -> id`.
Signals: `CombatantAdded`, `CombatantRemoved`, `Damaged(target, info, result)`, `Died(target, info?)`,
`Parried(defender, attacker?)`, `Healed(target, amount, source?)`. Extension: `CombatService.OutgoingModifiers`
(list of `fn(source, target, info) -> multiplier`).
Combatant fields of note: `Flags.{InvulnUntil, ParryUntil, SuperArmorUntil, Blocking, BlockReduction, BlockCostPerDamage, BlockUsesResource, MoveLockUntil}`,
`SpeedScale` (controllers set it: sprint 1.4, aim 0.55, AI patrol 0.5 ...), `Data.Interrupt = fn(reason)` (called on stun/stagger/heavy hit),
`Data.ThreatMult`, `DamageBy[id]`, `Threat[id]`. Times are `os.clock()` on the server.
Model attributes mirrored: CombatantId, Kind, Team, DisplayName, Level, Health, MaxHealth, Resource,
MaxResource, ResourceType, Stamina, MaxStamina, Shield, Dead, Blocking, InCombat, HitRadius,
Statuses (`"Id:stacks:expiresServerTime,..."`).
Reaction clips auto-played by CombatService through AnimationService: `HitLight`, `HitHeavy`, `Stagger`, `Knockdown`, `Death` (Hold).

### AnimationService (server)
`Play(model, clip, {Speed?, Duration?, Hold?, Looped?, FadeIn?, FadeOut?, Priority?}, exceptPlayer?)`, `Stop(model, clip?, fade?)`,
`SetState(model, state?)` (attribute `AnimState`), `SetAnimSet(model, name)` (attribute `AnimSet`).

### Anchors (shared)
`Anchors.Create(id, cf)`, `CreateOnFloor(id, ignore?)`, `CreateRegion(region, ignore?)`, `Get(id)`, `Wait(id)`, `CFrame(id)`.
Ids are declared in `Config/WorldLayout.Anchors`.

### Client
`PlayerState.Get/Changed/Observe(section)`; `UIController` (see §6); `Theme`, `Components`.
`AnimationPlayer` engine + `Anim` authoring helpers (see Animations/Anim.luau header).

## 3. Rigs

### 3.1 Humanoid rig (players, NPCs, humanoid enemies) — built by `Shared/Modules/Rig/RigBuilder`
- Parts (R15 names): HumanoidRootPart, LowerTorso, UpperTorso, Head, Left/Right UpperArm, LowerArm,
  Hand, Left/Right UpperLeg, LowerLeg, Foot. `Humanoid` (RigType R15, `BreakJointsOnDeath=false`),
  `HumanoidRootPart` is PrimaryPart.
- Motor6D names: `Root` (HRP→LowerTorso), `Waist`, `Neck`, `LeftShoulder`, `LeftElbow`, `LeftWrist`,
  `RightShoulder`, `RightElbow`, `RightWrist`, `LeftHip`, `LeftKnee`, `LeftAnkle`, `RightHip`,
  `RightKnee`, `RightAnkle`. Weapon motors: `RightGrip` (RightHand→main hand weapon Handle),
  `LeftGrip` (LeftHand→off-hand weapon / bow / second dagger), `ShieldMount` (LeftLowerArm→shield).
  Optional race motors: `Tail1`,`Tail2`,`Tail3`, `LeftWing`,`RightWing`, `LeftEar`,`RightEar`.
- **Rest pose (all Transforms = identity):** standing straight facing -Z, arms hanging along the body,
  palms facing the thighs, legs straight. Joint C0/C1 are placed at anatomical pivots (shoulder,
  elbow, hip ...) so rotations look natural. +X rotation on a shoulder raises the arm forward.
- **Grip conventions at identity:**
  - Sword / Dagger: blade extends along the hand's local **-Z** (forward when the arm hangs).
  - Staff: shaft along the hand's local **Y**, tip upward (≈ +4.5 studs above the hand).
  - Longbow (LeftGrip): limbs along the hand's local **Y**, string on the **+Z** side (toward the body).
  - Shield (ShieldMount): face pointing to the character's **-X** (outward from left forearm); a block
    pose rotates the arm so the face points forward.
  - Weapon attachments: blades have `TrailTop`/`TrailBottom`; staff `Tip`; bow `StringTop`, `StringBottom`, `Nock`; shield `ShieldFace`.
- Attributes: `RigType="Humanoid"`, `AnimSet` (Knight/Mage/Ranger/Assassin for players; "Humanoid" or an NPC set), `Race`, `Class`.
- CollectionService tag **`AnimatedRig`** on every animated model (players, NPCs, enemies, bosses).
- API: `RigBuilder.Build(spec) -> Model` where
  `spec = { Race: string, Appearance: Types.Appearance?, Outfit: string?, Equipment: { [slot]: itemId }?, Name: string?, Scale: number? }`
  and `RigBuilder.ApplyEquipment(model, { [slot]: itemId })` (re-dresses an existing rig).
  NPC outfits: Guard, Noble, King, Queen, Merchant, Smith, Scholar, Archmage, Priestess, Commoner,
  Innkeeper, Mercenary, Sage, Smuggler, Elder, Ranger, Scout, Villager, Cultist, Bandit, Hunter,
  Librarian, Herald, Alchemist, Banker. (Enemy humanoids use Bandit/Cultist/Hunter + weapons.)

### 3.2 Creature rigs — `Shared/Modules/Creatures/*` (enemy system)
Any joint names, documented in the creature module; same tag/attributes (`RigType` = creature name, `AnimSet`).

## 4. Animation contract
- AnimSet modules live in `Shared/Animations/Sets/**`, built with `Anim.Set(name, inherit, clips, extra)`.
  They require Anim via `require(<path to Shared>.Animations.Anim)`.
- Required per chain: `Idle`, `Walk`, `Run`, `HitLight`, `HitHeavy`, `Stagger`, `Knockdown`, `Death`
  (+ `Sprint`, `CombatIdle`, `Jump`, `Fall`, `Land`, `Swim` for humanoids).
- Player sets: every `ActionDef.Clip` from Config/Classes with **Length == Duration** and impact pose at hit `At`,
  plus `Dodge_Roll`, `Dodge_Blink`, `Dodge_Dash` (shared, in Humanoid), `<Class>_BlockLoop` for block/mana-shield/deflect hold,
  `Ranger_AimedDraw` (looping hold while charging).
- NPC ambient states (attribute `AnimState` → looping clip `NPC_<State>` in the Humanoid set):
  Talk, Hammer, Sweep, Sit, GuardIdle, Read, Injured, Cheer, Cower, Pray, Kneel, Stir, Lute, Wave, Point.
- Enemy `AnimState` "Combat" → `CombatIdle`.
- Client `AnimationController` animates every `AnimatedRig` in range: locomotion from velocity,
  `Anim`/`AnimStop` remotes, `AnimState`, `Dead` attribute (hold `Death`), local prediction API.

## 5. Remote catalog (name → direction → payload)

Core (implemented): `StateSection` S→C (section, data) · `RequestState` invoke → {sections} ·
`SaveSettings` C→S (partial Settings) · `CombatFeedback` S→C unreliable {T=target, S=source?, A=amount, Ty=type, C=crit, B=blocked, G=guardBroken, P=parried, D=dodged, H=heal, Ab=ability, Pos} ·
`Knockback` S→C (velocity) · `Telegraph` S→C {Id, Shape, CFrame, Duration, Style, Follow, Start(serverTime)} · `TelegraphCancel` S→C (id) ·
`Projectile` S→C {Id, Visual, Origin, Velocity, Gravity, Homing, Target, Range, Source} · `ProjectileEnd` S→C (id, pos, hit) ·
`Anim` S→C {M=model, C=clip, T=serverTime, O=opts} · `AnimStop` S→C (model, clip?, fade?).

Character (CharacterService): `CreateCharacter` invoke ({Name, Race, Class, Appearance}) → (ok, idOrError) ·
`SelectCharacter` invoke (id) → (ok, err) [spawns] · `DeleteCharacter` invoke (id) → (ok, err) ·
`ReturnToMenu` C→S () · `RespawnRequest` C→S () · `CharacterSpawned` S→C {Name, Location, FirstTime} ·
`PlayerDied` S→C {RespawnIn, Waystone, WaystoneName} · `ScreenFade` S→C {In, Hold, Out, Text?}.

Combat (PlayerCombatService): `ActionRequest` C→S (actionId, aimDir: Vector3, target: Model?, groundPos: Vector3?) ·
`ActionRelease` C→S (actionId, heldSeconds) · `BlockState` C→S (bool) · `SprintState` C→S (bool) ·
`ActionRejected` S→C (actionId, reason) · `VFX` S→C {Id, Caster?, Origin?(CFrame), Position?, Direction?, Target?, Radius?, Duration?} ·
section **Combat** {Class, Bar={slot→actionId}, Cooldowns={actionId→{ReadyAt=serverTime, Total}}, Ultimate, UltimateMax, Charging?}.

Progression: `ChooseSpec` invoke (specId) → (ok, err) · `ChooseTalent` invoke (tierKey, index) → (ok, err) ·
`LevelUp` S→C {Level} · section **Stats** {Stats, Sets={setId→count}, Spec, Talents}.

Inventory/Economy: `InvEquip` (uid) · `InvUnequip` (slot) · `InvLock` (uid, bool) · `InvFavorite` (uid, bool) ·
`InvDestroy` invoke (uid, confirmed: bool) → (ok, err) · `UseItem` (uid) · `UseHotbar` (slot 1..4) · `SetHotbar` (slot, itemId) ·
`VendorBuy` invoke (vendorId, itemId, qty) → (ok, err) · `VendorSell` invoke (uid, qty) → (ok, err) ·
`BankDeposit` invoke (uid) · `BankWithdraw` invoke (uid) · `BankGold` invoke (amount ±) ·
`OpenVendor` S→C (vendorId) · `OpenBank` S→C () · `LootNotify` S→C {Items={{Id,Qty}}, Gold, XP, Source}.

Party: `PartyCreate`, `PartyInvite` (targetUserId), `PartyRespond` (inviterUserId, accept), `PartyLeave`, `PartyKick` (userId),
`PartyPromote` (userId), `PartyReady` (bool) — all C→S · `PartyInvited` S→C {FromName, FromUserId} ·
section **Party** {Id, Leader, Members={{UserId, Name, Class, Level, Ready, Online}}} (nil/empty table when solo).

Dungeon: `DungeonLeave` C→S () · `DungeonState` S→C {InstanceId, Name, Objective, Room, PartySize, Active}.

Quests/Dialogue: `QuestTrack` C→S (questId) · `QuestUpdate` S→C {QuestId, Event("Started"|"Progress"|"Stage"|"Completed"|"Failed"), Text} ·
`DialogueOpen` S→C {NpcId, Name, Title, Text, Choices={{Index, Text, Kind}}, Model?} · `DialogueChoose` C→S (npcId, index) · `DialogueClose` S→C ()/C→S (npcId).
World: `ZoneEntered` S→C {ZoneId, Name, Level, First} · `WorldEvent` S→C {Id, Name, State("Active"|"Success"|"Failed"|"Ended"), Objective, Progress, Position}.
Boss: `BossEncounter` S→C {Event("Intro"|"Phase"|"Defeated"|"Wipe"|"Ended"), Boss=model, Name, Title, Phase, Duration, Arena=Vector3}.

Interaction: server `ProximityPrompt`s use `Style = Custom`, set `ActionText`/`ObjectText`, `KeyboardKeyCode = G`,
attribute `PromptKind` ∈ Talk, Inspect, Waystone, Door, Loot, Shop, Use. HUD renders them.

## 6. Server service APIs (implemented by their owners)

- **CharacterService**: `GetModel(p)`, `Spawn(p, record)`, `Teleport(p, cf, {Fade: boolean?, Text: string?})`,
  `SetWaystone(p, anchorId)`, `RefreshAppearance(p)`; signals `CharacterSpawned(p, model, record)`, `CharacterDied(p)`.
  Sets character attributes `InInstance` (bool) and `SafePosition` (Vector3, last safe overworld spot).
- **PlayerCombatService**: `ResetForSpawn(p)`; uses `ProgressionService:GetModifiers(p)`.
- **ProgressionService**: `AddXP(p, amount, source)`, `Recompute(p)`, `GetStats(p)`, `GetModifiers(p) -> {Modifier}`
  (passives + spec + talents + set bonuses; Stat, Action and Flag mods), `GetBuild(p) -> {Spec, Talents}`;
  signals `LevelChanged(p, level)`, `StatsChanged(p, stats)`. It calls `CombatService:SetStats` for the player.
- **InventoryService**: `Grant(p, itemId, qty, source) -> (ok, err?)`, `Remove(p, itemId, qty) -> bool`, `Count(p, itemId)`,
  `HasSpace(p, slots)`, `GetEquippedItemIds(p) -> {slot→itemId}`,
  `GrantBundle(p, {Items={{Id,Qty}}?, Gold?, XP?}, source, onceKey?) -> bool` (onceKey recorded in `record.Rewards`; a key never pays twice);
  signal `EquipmentChanged(p)`.
- **EconomyService**: `AddGold(p, n, source)`, `SpendGold(p, n) -> bool`, vendors from `Config/Items.Vendors`.
- **PartyService**: `GetParty(p) -> {Id, Leader: Player, Members: {Player}}?`, `GetMembers(p) -> {Player}` (solo → {p}), `Size(p)`; signal `Changed(partyId)`.
- **DungeonService**: `GetInstanceOf(p) -> instance?`, `Enter(p)`.
- **QuestService**: `Notify(p, kind, data)` with kind ∈ Kill{EnemyId}, Interact{Id}, Reach{ZoneId|AnchorId}, Talk{NpcId}, Collect{ItemId}, Boss{BossId}, Dungeon{Event}, Puzzle{Id}, Flag{Flag};
  `IsActive(p, questId, stage?)`, `HasCompleted(p, questId)`, `SetFlag(p, flag)`, `HasFlag(p, flag)`.
- **NPCService**: `GetNPC(id) -> Model?`, `Bark(id, text)`.
- **EnemyService**: `Spawn(enemyId, cf, {Level?, Instance?, Leash?, OnDeath?, Aggro?: {Player}}) -> (Model, Combatant)`, `Despawn(model)`.
  On death credits players (damage contributors + their party within 90 studs): XP (Formulas.KillXP), loot via
  `InventoryService:GrantBundle`, `QuestService:Notify(p, "Kill", {EnemyId})`.
- **BossService**: `StartEncounter(bossId, arena: Model, {Players, PartySize, InstanceId, OnDefeated, OnWipe}) -> encounter`.
- **WorldService**: builds the world (terrain → capital → Eldoria → dungeon template → anchors), sets
  `ReplicatedStorage:SetAttribute("WorldReady", true)`, day/night (`Lighting.ClockTime`), zone discovery (`ZoneEntered`, QuestService Reach).
  Builders: `World/Capital/CapitalBuilder.Build(worldFolder: Folder)`, `World/Eldoria/EldoriaBuilder.Build(worldFolder)`,
  `World/Terrain/TerrainBuilder.Build()`, `World/Dungeon/TempleBuilder.Build() -> Model` (stored at `ServerStorage.DungeonTemplates.TempleOfRoots`).

### Dungeon template tags (CollectionService tags or attributes inside the template)
Parts named/tagged inside `TempleOfRoots` (all positions relative to the template pivot):
`DG_Entry` (spawn CFrame), `DG_Exit` (exit portal/door part), `DG_Room` (attribute `Room` = 1..N, part = room volume),
`DG_Spawn` (attribute `EnemyId`, `Room`, optional `Elite`), `DG_Pillar` (attribute `Index` 1..3, rotatable rune pillar model root),
`DG_Mural` (shows the target pillar pattern; attribute `Solution` = "2,0,1" etc.), `DG_HiddenWall` (breakable/secret wall), `DG_Mechanism` (lever/altar),
`DG_Gate` (attribute `Room` it seals/unseals), `DG_MiniBoss` (spawn), `DG_ArenaCenter`, `DG_ArenaGate`, `DG_BossSpawn`, `DG_ChestReward`.

## 7. Client controller APIs

- **UIController** (implemented): `Gui(layer)`, `Open(name, args?)`, `Close(name)`, `Toggle`, `IsOpen`, `CloseMenus`, `AnyMenuOpen`, `Back`,
  `SetHUDVisible`, `Notify(text, kind?)`, `Confirm(text, onYes, yesLabel?)`; signals `Opened`, `Closed`.
  Screen names: `MainMenu`, `CharacterCreator`, `Settings`, `Map`, `HUD`, `Inventory`, `Character`, `Skills`, `Journal`, `Party`,
  `Dialogue`, `Vendor`, `Bank`, `GameMenu`, `DeathScreen`, `Fade`, `MobileControls`.
- **InputController**: `GetBinding(action)`, `SetBinding(action, keyName)` (persists via SaveSettings), `IsGameplayEnabled()`,
  signal `Action(actionName, began: boolean)`. Menu actions call `UIController:Toggle(...)`.
- **CameraController**: `SetMode("Menu"|"Gameplay"|"Cinematic")`, `Shake(intensity, duration)`, `PlayCinematic({ {CFrame, Duration, Focus?} }, onDone?)`, `GetAimDirection()`.
- **CombatController**: `Trigger(slot, began)` (slots = Keybinds actions Light/Heavy/Secondary/Dodge/Skill1..4/Ultimate), `GetTarget() -> Model?`, signal `TargetChanged(model?)`.
- **AnimationController**: `PlayLocal(model, clip, opts)`, `Stop(model, clip?)`, `GetPlayer(model) -> AnimationPlayer?`.
- **VFXController**: `Play(effectId, params)` (same params as the `VFX` remote) — owns projectile visuals and hit sparks.
- **SoundController**: `Play(soundId, {Position?, Parent?, Volume?})`, `PlayMusic(trackId?, fade?)`, `SetAmbient(id?)` using `Config/Sounds`.
- **TelegraphController**, **BossController** (cinematic intro, music cue), **EnvironmentController** (zone lighting/weather/ambience).

## 8. Game flow
Join → profile loads → `Account` section → `MainMenu` (camera over the capital) → Continue / New character
→ `CharacterCreator` → `CreateCharacter` → `SelectCharacter` → server builds rig, spawns at saved position or
`spawn_arrival` (first time) → `CharacterSpawned` → menus close, HUD opens, CameraController Gameplay.
Death → `PlayerDied` → DeathScreen → `RespawnRequest` (or auto after RespawnIn) → respawn at waystone.
`ReturnToMenu` saves and despawns.

## 9. Additional fixed identifiers

- **Enemy ids** (Config/Enemies): `forest_bandit`, `bandit_bowman`, `blighted_wolf`, `shadow_hunter`, `grove_cultist`,
  `bark_shambler`, `ruin_sentinel` (elite), `thornbound_warden` (mini-boss), `forest_guardian` (regional boss),
  `guardian_sapling`, `verdant_wisp` (summons), `ashen_stag` (rare elite, world event). Boss ids for
  `QuestService:Notify(p, "Boss", {BossId})`: `thornbound_warden`, `forest_guardian`.
- **Directional dodge clips**: `Dodge_Roll`, `Dodge_RollBack`, `Dodge_RollLeft`, `Dodge_RollRight`, `Dodge_Dash`,
  `Dodge_DashBack`, `Dodge_DashLeft`, `Dodge_DashRight`, `Dodge_Blink`. CombatController picks the suffix from movement
  input relative to the camera and sends the movement direction as `aimDir` for Dodge actions.
- **InventoryService:Equip(p, uid) -> (ok, err)** / **Unequip(p, slot)** — server API mirroring the remotes.
- **Section `QuestMarkers`** (QuestService → client): `{ [npcId] = "!" | "?" | "…" }` per player. NPC models carry attribute `NpcId`
  and `NpcTitle`. HUD draws markers/nameplates locally.
- **MapRenderer** (UI/Widgets/MapRenderer, owned by UI-A, used by HUD minimap):
  `MapRenderer.new(container: Frame, opts: { Mode: "Mini" | "Full", Scale: number? }) -> { SetCenter(Vector3), SetHeading(radians), Update(), Destroy() }`.
- **CharacterPreview** (UI/Widgets/CharacterPreview, owned by UI-A, used by Character screen):
  `CharacterPreview.new(viewport: ViewportFrame, spec: RigBuilder spec) -> { SetSpec(spec), SetYaw(deg), Destroy() }`.
- **Config/CapitalShots** (owned by the Capital builder): `{ { CFrame: CFrame, Focus: Vector3, Duration: number } }` camera
  shots for the main-menu flyover.
- **Respawn hook**: CharacterService asks `Registry.Find("DungeonService"):GetRespawnCFrame(p)` first (returns CFrame? when
  the player is inside an instance), else the bound waystone anchor.
- **Workspace folders** (created by WorldService on Init): `World` (Capital, Eldoria, Anchors), `NPC`, `Enemies`, `Instances`, `VFX`.
- **Sounds**: `SoundController:Play(id)` silently ignores ids whose asset is missing; ids are defined in `Config/Sounds`.
