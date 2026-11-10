--!strict
--[[
	Items — every item definition. Server-only systems create item instances (Types.ItemInstance)
	by id; the client only ever sees ids and uids. `Visual` is a style key implemented by
	EquipmentVisuals (geometry differs per style — rarities are not just recolours).
]]

export type Rarity = "Common" | "Uncommon" | "Rare" | "Epic" | "Legendary" | "Mythic"
export type ItemType = "Weapon" | "Armor" | "Accessory" | "Consumable" | "Material" | "Quest" | "Junk"
export type Slot = "MainHand" | "OffHand" | "Head" | "Chest" | "Shoulders" | "Hands" | "Legs" | "Feet" | "Cloak" | "Amulet" | "Ring"

export type ItemDef = {
	Id: string,
	Name: string,
	Description: string,
	Lore: string?,
	Type: ItemType,
	Rarity: Rarity,
	Slot: Slot?,
	WeaponType: string?, -- Sword / Shield / Staff / Longbow / Dagger
	ArmorType: ("Light" | "Medium" | "Heavy")?,
	Level: number, -- required level
	Classes: { string }?, -- nil = any class
	Stats: { [string]: number }?,
	Set: string?,
	Value: number, -- vendor sell price (gold)
	Stack: number, -- max stack (1 = unique instance)
	Use: { Heal: number?, Resource: number?, Regen: number?, Duration: number?, Cooldown: number, CombatUsable: boolean }?,
	Visual: string?,
	Icon: string, -- glyph for UI
	Unique: boolean?, -- only one may be owned
	NoSell: boolean?,
}

export type SetDef = {
	Id: string,
	Name: string,
	Lore: string,
	Style: string,
	Pieces: { string },
	Bonuses: { [number]: { Description: string, Mods: { any } } },
}

local Rarities: { [string]: { Name: string, Color: Color3, Order: number, Glow: boolean } } = {
	Common = { Name = "Обычный", Color = Color3.fromRGB(200, 200, 196), Order = 1, Glow = false },
	Uncommon = { Name = "Необычный", Color = Color3.fromRGB(110, 200, 110), Order = 2, Glow = false },
	Rare = { Name = "Редкий", Color = Color3.fromRGB(90, 150, 240), Order = 3, Glow = false },
	Epic = { Name = "Эпический", Color = Color3.fromRGB(176, 104, 240), Order = 4, Glow = true },
	Legendary = { Name = "Легендарный", Color = Color3.fromRGB(245, 168, 60), Order = 5, Glow = true },
	Mythic = { Name = "Мифический", Color = Color3.fromRGB(240, 80, 90), Order = 6, Glow = true },
}

local Items: { [string]: ItemDef } = {}

local function add(def: ItemDef)
	assert(Items[def.Id] == nil, `duplicate item {def.Id}`)
	Items[def.Id] = def
end

-- ── Weapons ───────────────────────────────────────────────────────────────────
-- Knight
add({ Id = "sword_recruit", Name = "Меч новобранца", Description = "Простой клинок королевского арсенала.", Type = "Weapon", Rarity = "Common", Slot = "MainHand", WeaponType = "Sword", Level = 1, Classes = { "Knight" }, Stats = { AttackPower = 8 }, Value = 4, Stack = 1, Visual = "Sword_Recruit", Icon = "🗡" })
add({ Id = "sword_guard", Name = "Клинок стражи Ауренхольма", Description = "Сбалансированный меч с гардой-солнцем.", Type = "Weapon", Rarity = "Uncommon", Slot = "MainHand", WeaponType = "Sword", Level = 3, Classes = { "Knight" }, Stats = { AttackPower = 14, Strength = 2 }, Value = 30, Stack = 1, Visual = "Sword_Guard", Icon = "🗡" })
add({ Id = "sword_thornbound", Name = "Терновый клинок надзирателя", Description = "Лезвие обвито окаменевшими шипами.", Lore = "Меч стража храма, оплетённый корнями за столетия ожидания.", Type = "Weapon", Rarity = "Rare", Slot = "MainHand", WeaponType = "Sword", Level = 6, Classes = { "Knight" }, Stats = { AttackPower = 22, Strength = 3, CritChance = 0.02 }, Value = 80, Stack = 1, Visual = "Sword_Thornbound", Icon = "🗡" })
add({ Id = "blade_verdant_oath", Name = "Клятва Зелёного Стража", Description = "Клинок из живой сердцевины, по которому струится золотой сок.", Lore = "Последний дар Лесного Стража тому, кто освободил его от порчи. Клинок помнит клятву Хранителей.", Type = "Weapon", Rarity = "Legendary", Slot = "MainHand", WeaponType = "Sword", Level = 8, Classes = { "Knight" }, Stats = { AttackPower = 34, Strength = 5, Vitality = 4, CritChance = 0.03 }, Value = 400, Stack = 1, Visual = "Sword_VerdantOath", Icon = "🗡", Unique = true })
add({ Id = "shield_recruit", Name = "Щит новобранца", Description = "Деревянный щит, окованный железом.", Type = "Weapon", Rarity = "Common", Slot = "OffHand", WeaponType = "Shield", Level = 1, Classes = { "Knight" }, Stats = { Armor = 10 }, Value = 4, Stack = 1, Visual = "Shield_Recruit", Icon = "🛡" })
add({ Id = "shield_aurenholm", Name = "Щит солнечного герба", Description = "Каплевидный щит с гербом Ауренхольма.", Type = "Weapon", Rarity = "Uncommon", Slot = "OffHand", WeaponType = "Shield", Level = 3, Classes = { "Knight" }, Stats = { Armor = 20, Vitality = 2 }, Value = 30, Stack = 1, Visual = "Shield_Aurenholm", Icon = "🛡" })
add({ Id = "shield_bark_aegis", Name = "Эгида из коры", Description = "Щит из коры древнего дерева, мягко светящийся изнутри.", Type = "Weapon", Rarity = "Epic", Slot = "OffHand", WeaponType = "Shield", Level = 7, Classes = { "Knight" }, Stats = { Armor = 36, Vitality = 4, Resistance = 10 }, Value = 160, Stack = 1, Visual = "Shield_BarkAegis", Icon = "🛡" })
-- Mage
add({ Id = "staff_apprentice", Name = "Посох ученика", Description = "Ясеневый посох с мутным кристаллом.", Type = "Weapon", Rarity = "Common", Slot = "MainHand", WeaponType = "Staff", Level = 1, Classes = { "Mage" }, Stats = { SpellPower = 9 }, Value = 4, Stack = 1, Visual = "Staff_Apprentice", Icon = "⚚" })
add({ Id = "staff_academy", Name = "Посох Академии", Description = "Посох с кольцами рун, выдаваемый выпускникам.", Type = "Weapon", Rarity = "Uncommon", Slot = "MainHand", WeaponType = "Staff", Level = 3, Classes = { "Mage" }, Stats = { SpellPower = 15, Intelligence = 2 }, Value = 30, Stack = 1, Visual = "Staff_Academy", Icon = "⚚" })
add({ Id = "staff_moonroot", Name = "Посох лунного корня", Description = "Изогнутый корень с бледным светящимся плодом.", Type = "Weapon", Rarity = "Rare", Slot = "MainHand", WeaponType = "Staff", Level = 6, Classes = { "Mage" }, Stats = { SpellPower = 24, Intelligence = 3, ResourceRegen = 1 }, Value = 80, Stack = 1, Visual = "Staff_Moonroot", Icon = "⚚" })
add({ Id = "staff_heartwood", Name = "Сердцевина Стража", Description = "Ветвь, выросшая из сердца Лесного Стража; вокруг навершия вращаются семена света.", Lore = "Архимаг готов отдать за неё половину библиотеки.", Type = "Weapon", Rarity = "Legendary", Slot = "MainHand", WeaponType = "Staff", Level = 8, Classes = { "Mage" }, Stats = { SpellPower = 37, Intelligence = 5, ResourceRegen = 2, CritChance = 0.03 }, Value = 400, Stack = 1, Visual = "Staff_Heartwood", Icon = "⚚", Unique = true })
-- Ranger
add({ Id = "bow_hunter", Name = "Охотничий лук", Description = "Надёжный лук из тиса.", Type = "Weapon", Rarity = "Common", Slot = "MainHand", WeaponType = "Longbow", Level = 1, Classes = { "Ranger" }, Stats = { AttackPower = 8 }, Value = 4, Stack = 1, Visual = "Bow_Hunter", Icon = "🏹" })
add({ Id = "bow_elmwood", Name = "Вязовый длинный лук", Description = "Длинный лук стрелков пограничья.", Type = "Weapon", Rarity = "Uncommon", Slot = "MainHand", WeaponType = "Longbow", Level = 3, Classes = { "Ranger" }, Stats = { AttackPower = 14, Dexterity = 2 }, Value = 30, Stack = 1, Visual = "Bow_Elmwood", Icon = "🏹" })
add({ Id = "bow_thornstring", Name = "Лук терновой тетивы", Description = "Тетива сплетена из гибких шипастых лоз.", Type = "Weapon", Rarity = "Rare", Slot = "MainHand", WeaponType = "Longbow", Level = 6, Classes = { "Ranger" }, Stats = { AttackPower = 22, Dexterity = 3, CritChance = 0.02 }, Value = 80, Stack = 1, Visual = "Bow_Thornstring", Icon = "🏹" })
add({ Id = "bow_guardian_whisper", Name = "Шёпот Стража", Description = "Лук из двух переплетённых ветвей; стрелы оставляют за собой светящиеся лепестки.", Lore = "Говорят, при натяжении слышен шелест священной поляны.", Type = "Weapon", Rarity = "Legendary", Slot = "MainHand", WeaponType = "Longbow", Level = 8, Classes = { "Ranger" }, Stats = { AttackPower = 34, Dexterity = 5, CritChance = 0.04, CritDamage = 0.1 }, Value = 400, Stack = 1, Visual = "Bow_GuardianWhisper", Icon = "🏹", Unique = true })
-- Assassin
add({ Id = "daggers_cutpurse", Name = "Кинжалы карманника", Description = "Пара коротких узких клинков.", Type = "Weapon", Rarity = "Common", Slot = "MainHand", WeaponType = "Dagger", Level = 1, Classes = { "Assassin" }, Stats = { AttackPower = 8 }, Value = 4, Stack = 1, Visual = "Daggers_Cutpurse", Icon = "🔪" })
add({ Id = "daggers_nightglass", Name = "Кинжалы ночного стекла", Description = "Тёмное стекло, острое как бритва.", Type = "Weapon", Rarity = "Uncommon", Slot = "MainHand", WeaponType = "Dagger", Level = 3, Classes = { "Assassin" }, Stats = { AttackPower = 14, Dexterity = 2 }, Value = 30, Stack = 1, Visual = "Daggers_Nightglass", Icon = "🔪" })
add({ Id = "daggers_venomfang", Name = "Ядовитые клыки", Description = "Изогнутые клинки с желобами для яда.", Type = "Weapon", Rarity = "Rare", Slot = "MainHand", WeaponType = "Dagger", Level = 6, Classes = { "Assassin" }, Stats = { AttackPower = 22, Dexterity = 3, CritDamage = 0.08 }, Value = 80, Stack = 1, Visual = "Daggers_Venomfang", Icon = "🔪" })
add({ Id = "daggers_verdant_fangs", Name = "Клыки зелёной тени", Description = "Клинки-шипы, срезанные с короны Стража. Оставляют за собой зелёный туман.", Lore = "Оружие для тех, кто сражается в тени корней.", Type = "Weapon", Rarity = "Legendary", Slot = "MainHand", WeaponType = "Dagger", Level = 8, Classes = { "Assassin" }, Stats = { AttackPower = 33, Dexterity = 5, CritChance = 0.04, CritDamage = 0.12 }, Value = 400, Stack = 1, Visual = "Daggers_VerdantFangs", Icon = "🔪", Unique = true })

-- ── Armor: class starter pieces ───────────────────────────────────────────────
local function armor(id: string, name: string, desc: string, rarity: Rarity, slot: Slot, armorType: "Light" | "Medium" | "Heavy", level: number, stats: { [string]: number }, set: string?, visual: string, classes: { string }?, value: number)
	local icons: { [string]: string } = { Head = "⛑", Chest = "🥋", Shoulders = "◭", Hands = "🧤", Legs = "👖", Feet = "👢", Cloak = "🧥" }
	add({ Id = id, Name = name, Description = desc, Type = "Armor", Rarity = rarity, Slot = slot, ArmorType = armorType, Level = level, Classes = classes, Stats = stats, Set = set, Value = value, Stack = 1, Visual = visual, Icon = icons[slot] or "◆" })
end

armor("armor_recruit_chest", "Кольчуга новобранца", "Потёртая кольчуга с табардом.", "Common", "Chest", "Heavy", 1, { Armor = 14, MaxHealth = 10 }, nil, "Recruit", { "Knight" }, 3)
armor("armor_recruit_legs", "Поножи новобранца", "Стёганые штаны с наколенниками.", "Common", "Legs", "Heavy", 1, { Armor = 8 }, nil, "Recruit", { "Knight" }, 2)
armor("armor_apprentice_chest", "Мантия ученика", "Синяя мантия Академии.", "Common", "Chest", "Light", 1, { Armor = 4, Resistance = 6, MaxResource = 10 }, nil, "Apprentice", { "Mage" }, 3)
armor("armor_apprentice_legs", "Штаны ученика", "Лёгкие дорожные штаны.", "Common", "Legs", "Light", 1, { Armor = 3, Resistance = 3 }, nil, "Apprentice", { "Mage" }, 2)
armor("armor_scout_chest", "Куртка разведчика", "Кожаная куртка с капюшоном.", "Common", "Chest", "Medium", 1, { Armor = 8, Dexterity = 1 }, nil, "Scout", { "Ranger" }, 3)
armor("armor_scout_legs", "Штаны разведчика", "Кожаные штаны с ремнями.", "Common", "Legs", "Medium", 1, { Armor = 5 }, nil, "Scout", { "Ranger" }, 2)
armor("armor_shade_chest", "Жилет тени", "Тёмная стёганая куртка с маской.", "Common", "Chest", "Light", 1, { Armor = 6, Dexterity = 1 }, nil, "Shade", { "Assassin" }, 3)
armor("armor_shade_legs", "Штаны тени", "Мягкие штаны с обмотками.", "Common", "Legs", "Light", 1, { Armor = 4 }, nil, "Shade", { "Assassin" }, 2)

-- ── Armor sets ────────────────────────────────────────────────────────────────
local Sets: { [string]: SetDef } = {}

local function defineSet(set: SetDef)
	Sets[set.Id] = set
end

-- Aurenholm Guard (heavy, uncommon) — sold by the blacksmith, quest rewards
armor("guard_helm", "Шлем стражи", "Открытый шлем с солнечным гребнем.", "Uncommon", "Head", "Heavy", 3, { Armor = 10, Vitality = 1 }, "AurenholmGuard", "AurenholmGuard", { "Knight" }, 18)
armor("guard_cuirass", "Кираса стражи", "Стальная кираса поверх синего табарда.", "Uncommon", "Chest", "Heavy", 3, { Armor = 22, MaxHealth = 20 }, "AurenholmGuard", "AurenholmGuard", { "Knight" }, 26)
armor("guard_pauldrons", "Наплечники стражи", "Многослойные наплечники с заклёпками.", "Uncommon", "Shoulders", "Heavy", 3, { Armor = 9, Strength = 1 }, "AurenholmGuard", "AurenholmGuard", { "Knight" }, 18)
armor("guard_gauntlets", "Латные рукавицы стражи", "Тяжёлые рукавицы.", "Uncommon", "Hands", "Heavy", 3, { Armor = 7, Strength = 1 }, "AurenholmGuard", "AurenholmGuard", { "Knight" }, 16)
armor("guard_greaves", "Поножи стражи", "Стальные поножи.", "Uncommon", "Legs", "Heavy", 3, { Armor = 14 }, "AurenholmGuard", "AurenholmGuard", { "Knight" }, 20)
armor("guard_sabatons", "Сабатоны стражи", "Окованные сапоги.", "Uncommon", "Feet", "Heavy", 3, { Armor = 8 }, "AurenholmGuard", "AurenholmGuard", { "Knight" }, 16)
defineSet({ Id = "AurenholmGuard", Name = "Доспех стражи Ауренхольма", Lore = "Форма королевской стражи со времён короля Альдриха. Каждая вмятина — чья-то спасённая жизнь.", Style = "Сталь, синий табард, солнечный герб", Pieces = { "guard_helm", "guard_cuirass", "guard_pauldrons", "guard_gauntlets", "guard_greaves", "guard_sabatons" }, Bonuses = {
	[2] = { Description = "+8% брони", Mods = { { Stat = "Armor", Op = "Mul", Value = 1.08 } } },
	[4] = { Description = "Парирование восстанавливает 15 Решимости и 10% выносливости", Mods = { { Flag = "ParryRefund", Value = 15 } } },
} })

-- Archivist's Vestments (light, uncommon)
armor("archivist_hood", "Капюшон архивариуса", "Капюшон с вышитыми строками древних текстов.", "Uncommon", "Head", "Light", 3, { Resistance = 8, Intelligence = 1 }, "Archivist", "Archivist", { "Mage" }, 18)
armor("archivist_robe", "Мантия архивариуса", "Длинная мантия с поясом-книгой.", "Uncommon", "Chest", "Light", 3, { Armor = 6, Resistance = 12, MaxResource = 15 }, "Archivist", "Archivist", { "Mage" }, 26)
armor("archivist_mantle", "Оплечье архивариуса", "Накидка со свитками.", "Uncommon", "Shoulders", "Light", 3, { Resistance = 6, Intelligence = 1 }, "Archivist", "Archivist", { "Mage" }, 18)
armor("archivist_gloves", "Перчатки переписчика", "Тонкие перчатки в чернильных пятнах.", "Uncommon", "Hands", "Light", 3, { Resistance = 4, CritChance = 0.01 }, "Archivist", "Archivist", { "Mage" }, 16)
armor("archivist_leggings", "Штаны архивариуса", "Плотная ткань с рунической каймой.", "Uncommon", "Legs", "Light", 3, { Armor = 4, Resistance = 6 }, "Archivist", "Archivist", { "Mage" }, 20)
armor("archivist_boots", "Туфли архивариуса", "Мягкие кожаные туфли.", "Uncommon", "Feet", "Light", 3, { Resistance = 4, MoveSpeed = 0.3 }, "Archivist", "Archivist", { "Mage" }, 16)
defineSet({ Id = "Archivist", Name = "Облачение архивариусов", Lore = "Архивариусы ищут правду об исчезновении Хранителей. Их одежда пропитана чернилами и старой магией.", Style = "Тёмно-синяя ткань, золотые строки, книжные пояса", Pieces = { "archivist_hood", "archivist_robe", "archivist_mantle", "archivist_gloves", "archivist_leggings", "archivist_boots" }, Bonuses = {
	[2] = { Description = "+12% восстановления маны", Mods = { { Stat = "ResourceRegen", Op = "Mul", Value = 1.12 } } },
	[4] = { Description = "+8% силы заклинаний, +5% ускорения", Mods = { { Stat = "SpellPower", Op = "Mul", Value = 1.08 }, { Stat = "Haste", Op = "Add", Value = 0.05 } } },
} })

-- Thornwalker (medium, rare) — Eldoria drops / quest rewards
armor("thornwalker_hood", "Капюшон тернохода", "Капюшон с маской из листьев.", "Rare", "Head", "Medium", 5, { Armor = 9, Dexterity = 2 }, "Thornwalker", "Thornwalker", { "Ranger", "Assassin" }, 40)
armor("thornwalker_jerkin", "Куртка тернохода", "Кожа, прошитая гибкими лозами.", "Rare", "Chest", "Medium", 5, { Armor = 16, Dexterity = 2, MaxHealth = 15 }, "Thornwalker", "Thornwalker", { "Ranger", "Assassin" }, 55)
armor("thornwalker_mantle", "Плащ-накидка тернохода", "Накидка из мха и коры.", "Rare", "Shoulders", "Medium", 5, { Armor = 8, Dexterity = 1 }, "Thornwalker", "Thornwalker", { "Ranger", "Assassin" }, 40)
armor("thornwalker_grips", "Наручи тернохода", "Наручи с шипами.", "Rare", "Hands", "Medium", 5, { Armor = 6, CritChance = 0.015 }, "Thornwalker", "Thornwalker", { "Ranger", "Assassin" }, 36)
armor("thornwalker_trousers", "Штаны тернохода", "Плотная кожа с наколенниками из коры.", "Rare", "Legs", "Medium", 5, { Armor = 11, Dexterity = 1 }, "Thornwalker", "Thornwalker", { "Ranger", "Assassin" }, 44)
armor("thornwalker_boots", "Сапоги тернохода", "Бесшумные мягкие сапоги.", "Rare", "Feet", "Medium", 5, { Armor = 6, MoveSpeed = 0.5 }, "Thornwalker", "Thornwalker", { "Ranger", "Assassin" }, 36)
defineSet({ Id = "Thornwalker", Name = "Снаряжение тернохода", Lore = "Так одеваются лесные жители Мшистого Приюта, когда уходят за пределы своих стволов-домов.", Style = "Тёмная кожа, мох, шипы, бирюзовые бусины", Pieces = { "thornwalker_hood", "thornwalker_jerkin", "thornwalker_mantle", "thornwalker_grips", "thornwalker_trousers", "thornwalker_boots" }, Bonuses = {
	[2] = { Description = "+6% скорости передвижения", Mods = { { Stat = "MoveSpeed", Op = "Mul", Value = 1.06 } } },
	[4] = { Description = "+6% шанса крита; убийство сокращает перезарядки на 1 с", Mods = { { Stat = "CritChance", Op = "Add", Value = 0.06 }, { Flag = "KillCooldownRefund", Value = 1 } } },
} })

-- Warden of the Grove (epic) — temple drops; three armour-type configurations of one set
for _, variant in { { Suffix = "heavy", Type = "Heavy" :: "Heavy", Classes = { "Knight" }, Main = "Armor" }, { Suffix = "light", Type = "Light" :: "Light", Classes = { "Mage" }, Main = "Resistance" }, { Suffix = "medium", Type = "Medium" :: "Medium", Classes = { "Ranger", "Assassin" }, Main = "Armor" } } do
	local s = variant.Suffix
	local main = variant.Main
	armor(`grovewarden_helm_{s}`, "Венец хранителя рощи", "Венец из живых ветвей с янтарём.", "Epic", "Head", variant.Type, 7, { [main] = 14, Vitality = 3 }, "GroveWarden", `GroveWarden_{s}`, variant.Classes, 90)
	armor(`grovewarden_chest_{s}`, "Панцирь хранителя рощи", "Доспех, в который вросла кора древнего дерева.", "Epic", "Chest", variant.Type, 7, { [main] = 28, MaxHealth = 40, Vitality = 3 }, "GroveWarden", `GroveWarden_{s}`, variant.Classes, 120)
	armor(`grovewarden_shoulders_{s}`, "Наплечья хранителя рощи", "Наплечья из узловатых корней.", "Epic", "Shoulders", variant.Type, 7, { [main] = 12, Vitality = 2 }, "GroveWarden", `GroveWarden_{s}`, variant.Classes, 90)
	armor(`grovewarden_legs_{s}`, "Поножи хранителя рощи", "Поножи, оплетённые лозой.", "Epic", "Legs", variant.Type, 7, { [main] = 18, Vitality = 2 }, "GroveWarden", `GroveWarden_{s}`, variant.Classes, 100)
end
defineSet({ Id = "GroveWarden", Name = "Облачение хранителя рощи", Lore = "Хранители Эльдории носили доспехи, выращенные самим лесом. Тяжёлый, лёгкий и средний варианты — одна клятва.", Style = "Кора, янтарь, мягкое зелёно-золотое свечение", Pieces = { "grovewarden_helm_heavy", "grovewarden_chest_heavy", "grovewarden_shoulders_heavy", "grovewarden_legs_heavy", "grovewarden_helm_light", "grovewarden_chest_light", "grovewarden_shoulders_light", "grovewarden_legs_light", "grovewarden_helm_medium", "grovewarden_chest_medium", "grovewarden_shoulders_medium", "grovewarden_legs_medium" }, Bonuses = {
	[2] = { Description = "+8% здоровья", Mods = { { Stat = "MaxHealth", Op = "Mul", Value = 1.08 } } },
	[4] = { Description = "Зелёное обновление: +60% восстановления здоровья, +10% получаемого лечения", Mods = { { Stat = "HealthRegen", Op = "Mul", Value = 1.6 }, { Stat = "Recovery", Op = "Add", Value = 0.1 } } },
} })

-- Cloaks and accessories
armor("cloak_wayfarer", "Плащ странника", "Тёплый шерстяной плащ.", "Common", "Cloak", "Light", 1, { Resistance = 3 }, nil, "Cloak_Wayfarer", nil, 3)
armor("cloak_royal_courier", "Плащ королевского гонца", "Синий плащ с золотой застёжкой.", "Uncommon", "Cloak", "Light", 4, { Resistance = 6, MoveSpeed = 0.4 }, nil, "Cloak_Courier", nil, 24)
add({ Id = "ring_patrol_signet", Name = "Перстень пропавшего патруля", Description = "Печатка сержанта Корвина. Командир разрешил оставить её себе.", Type = "Accessory", Rarity = "Uncommon", Slot = "Ring", Level = 2, Stats = { MaxHealth = 15, CritChance = 0.01 }, Value = 20, Stack = 1, Visual = "Ring_Signet", Icon = "💍" })
add({ Id = "amulet_keepers_seed", Name = "Семя Хранителя", Description = "Пульсирующее золотое семя в оправе из коры. Тёплое на ощупь.", Lore = "Сердце-семя Лесного Стража. В тишине кажется, будто оно шепчет чьё-то имя.", Type = "Accessory", Rarity = "Epic", Slot = "Amulet", Level = 8, Stats = { MaxHealth = 40, AttackPower = 6, SpellPower = 6, Haste = 0.03 }, Value = 200, Stack = 1, Visual = "Amulet_Seed", Icon = "✿", Unique = true })

-- ── Consumables ───────────────────────────────────────────────────────────────
add({ Id = "potion_health_minor", Name = "Малое зелье здоровья", Description = "Мгновенно восстанавливает 90 здоровья.", Type = "Consumable", Rarity = "Common", Level = 1, Value = 3, Stack = 20, Use = { Heal = 90, Cooldown = 12, CombatUsable = true }, Icon = "🧪" })
add({ Id = "potion_health", Name = "Зелье здоровья", Description = "Мгновенно восстанавливает 200 здоровья.", Type = "Consumable", Rarity = "Uncommon", Level = 4, Value = 8, Stack = 20, Use = { Heal = 200, Cooldown = 12, CombatUsable = true }, Icon = "🧪" })
add({ Id = "potion_mana_minor", Name = "Малое зелье маны", Description = "Восстанавливает 60 единиц ресурса класса.", Type = "Consumable", Rarity = "Common", Level = 1, Value = 3, Stack = 20, Use = { Resource = 60, Cooldown = 12, CombatUsable = true }, Icon = "⚗" })
add({ Id = "ration_travel", Name = "Дорожный паёк", Description = "Вне боя восстанавливает 8% здоровья в секунду в течение 10 с.", Type = "Consumable", Rarity = "Common", Level = 1, Value = 1, Stack = 20, Use = { Regen = 0.08, Duration = 10, Cooldown = 20, CombatUsable = false }, Icon = "🍖" })

-- ── Materials / junk / quest items ────────────────────────────────────────────
add({ Id = "mat_glowroot", Name = "Светокорень", Description = "Светящийся корень Эльдории. Ценится алхимиками.", Type = "Material", Rarity = "Common", Level = 1, Value = 2, Stack = 50, Icon = "❀" })
add({ Id = "mat_bark_resin", Name = "Смола древней коры", Description = "Золотистая смола, застывшая в янтарь.", Type = "Material", Rarity = "Uncommon", Level = 1, Value = 5, Stack = 50, Icon = "◉" })
add({ Id = "mat_wolf_pelt", Name = "Испорченная шкура", Description = "Шкура волка с чёрными прожилками порчи.", Type = "Material", Rarity = "Common", Level = 1, Value = 2, Stack = 50, Icon = "▤" })
add({ Id = "mat_bandit_insignia", Name = "Знак разбойника", Description = "Грубо вырезанный деревянный знак шайки «Серые Листья».", Type = "Material", Rarity = "Common", Level = 1, Value = 1, Stack = 50, Icon = "◇" })
add({ Id = "mat_rune_dust", Name = "Руническая пыль", Description = "Пыль с древних камней, тёплая и колючая.", Type = "Material", Rarity = "Uncommon", Level = 1, Value = 6, Stack = 50, Icon = "✧" })
add({ Id = "junk_rusty_buckle", Name = "Ржавая пряжка", Description = "Хлам. Торговец даст за неё пару монет.", Type = "Junk", Rarity = "Common", Level = 1, Value = 1, Stack = 50, Icon = "▫" })
add({ Id = "q_patrol_journal", Name = "Журнал патруля", Description = "Залитый кровью журнал сержанта Корвина.", Type = "Quest", Rarity = "Common", Level = 1, Value = 0, Stack = 1, Icon = "📜", NoSell = true })
add({ Id = "q_rune_shard", Name = "Осколок руны", Description = "Осколок камня, на котором пульсирует чужая руна.", Type = "Quest", Rarity = "Uncommon", Level = 1, Value = 0, Stack = 1, Icon = "◈", NoSell = true })
add({ Id = "q_temple_key", Name = "Ключ-печать храма", Description = "Каменный диск с узором корней. Открывает Древний храм.", Type = "Quest", Rarity = "Rare", Level = 1, Value = 0, Stack = 1, Icon = "⊛", NoSell = true })

-- Vendor inventories (Economy). Prices are buy prices in gold.
local Vendors: { [string]: { Name: string, Stock: { { Id: string, Price: number, Limit: number? } } } } = {
	blacksmith = { Name = "Кузница Бранока", Stock = {
		{ Id = "sword_guard", Price = 120 }, { Id = "shield_aurenholm", Price = 110 }, { Id = "guard_helm", Price = 70 }, { Id = "guard_cuirass", Price = 110 },
		{ Id = "guard_pauldrons", Price = 70 }, { Id = "guard_gauntlets", Price = 60 }, { Id = "guard_greaves", Price = 80 }, { Id = "guard_sabatons", Price = 60 },
		{ Id = "daggers_nightglass", Price = 120 }, { Id = "bow_elmwood", Price = 120 },
	} },
	alchemist = { Name = "Лавка алхимика", Stock = { { Id = "potion_health_minor", Price = 10 }, { Id = "potion_health", Price = 28 }, { Id = "potion_mana_minor", Price = 10 }, { Id = "ration_travel", Price = 4 } } },
	academy = { Name = "Лавка Академии", Stock = {
		{ Id = "staff_academy", Price = 120 }, { Id = "archivist_hood", Price = 70 }, { Id = "archivist_robe", Price = 110 }, { Id = "archivist_mantle", Price = 70 },
		{ Id = "archivist_gloves", Price = 60 }, { Id = "archivist_leggings", Price = 80 }, { Id = "archivist_boots", Price = 60 },
	} },
	general = { Name = "Товары странника", Stock = { { Id = "cloak_wayfarer", Price = 15 }, { Id = "cloak_royal_courier", Price = 90 }, { Id = "ration_travel", Price = 4 }, { Id = "potion_health_minor", Price = 12 } } },
	mossreach = { Name = "Обменник Мшистого Приюта", Stock = { { Id = "potion_health_minor", Price = 12 }, { Id = "potion_health", Price = 30 }, { Id = "potion_mana_minor", Price = 12 }, { Id = "thornwalker_boots", Price = 140, Limit = 1 } } },
}

local SlotOrder: { Slot } = { "MainHand", "OffHand", "Head", "Shoulders", "Chest", "Hands", "Legs", "Feet", "Cloak", "Amulet", "Ring" }
local SlotNames: { [string]: string } = {
	MainHand = "Основная рука", OffHand = "Вторая рука", Head = "Голова", Shoulders = "Плечи", Chest = "Грудь", Hands = "Кисти",
	Legs = "Ноги", Feet = "Ступни", Cloak = "Плащ", Amulet = "Амулет", Ring = "Кольцо",
}

return {
	Items = Items,
	Sets = Sets,
	Rarities = Rarities,
	Vendors = Vendors,
	SlotOrder = SlotOrder,
	SlotNames = SlotNames,
	Get = function(id: string): ItemDef?
		return Items[id]
	end,
}
