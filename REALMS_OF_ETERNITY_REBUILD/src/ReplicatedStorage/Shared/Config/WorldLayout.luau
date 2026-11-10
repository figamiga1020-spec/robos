--!strict
--[[
	WorldLayout — single source of truth for world geography (studs).
	Used by world builders, minimap/map UI, zone discovery, lighting/music presets, enemy spawn
	groups, NPC placement and quest objectives. The built world MUST match these coordinates.

	Axes: +X = east, -Z = north. Yaw (degrees): 0 faces north (-Z), -90 faces east (+X),
	90 faces west (-X), 180 faces south (+Z).

	ANCHORS: named points. The builder that owns `Region` creates an invisible part
	Workspace.World.Anchors.<id> at the correct floor height (see World/Anchors.luau).
	Consumers call Anchors.Get(id) / Anchors.Wait(id) and never hard-code positions.
]]

export type Rect = { X1: number, Z1: number, X2: number, Z2: number }
export type District = { Id: string, Name: string, Rect: Rect, Note: string }
export type Zone = {
	Id: string,
	Name: string,
	Region: string,
	Center: Vector2,
	Radius: number,
	Level: { number },
	Preset: string,
	Safe: boolean?,
	Underground: boolean?,
}
export type Road = {
	Id: string,
	Name: string,
	Width: number,
	Kind: "Main" | "Secondary" | "Trail" | "Hidden",
	Points: { Vector2 },
}
export type Anchor = { Pos: Vector2, Yaw: number, Region: string, Kind: string, Note: string, Height: number? }
export type RegionDef = {
	Id: string,
	Name: string,
	NameEn: string,
	Center: Vector2,
	Size: Vector2,
	Levels: { number },
	Built: boolean,
	Theme: string,
	Boss: string,
	Connections: { string },
}

local function v2(x: number, z: number): Vector2
	return Vector2.new(x, z)
end

local WorldLayout = {}

WorldLayout.WorldSize = v2(6200, 5000)
WorldLayout.SeaLevel = 0

-- ── Capital: Aurenholm ────────────────────────────────────────────────────────
WorldLayout.Capital = {
	Center = Vector3.new(0, 20, 0),
	GroundY = 20, -- paved plateau height; terrain is flattened to this under the city
	HalfSize = 325, -- walls run along x,z = ±325
	WallHeight = 45,
	WallThickness = 12,
	MainAvenue = { Axis = "X", HalfWidth = 14 }, -- z ∈ [-14, 14], west gate → east gate
	CrossAvenue = { Axis = "Z", HalfWidth = 12 }, -- x ∈ [-12, 12], south gate → castle
	Square = { X1 = -50, Z1 = -50, X2 = 50, Z2 = 50 },
	Gates = {
		West = {
			Pos = Vector3.new(-325, 20, 0),
			Width = 26,
			Open = true,
			Note = "Ворота Заката — прибытие с Королевского тракта",
		},
		East = {
			Pos = Vector3.new(325, 20, 0),
			Width = 26,
			Open = true,
			Note = "Ворота Рассвета — дорога в Эльдорию",
		},
		North = {
			Pos = Vector3.new(0, 20, -325),
			Width = 24,
			Open = false,
			Note = "Северные ворота закрыты: путь в Ноктхольд (глава 2)",
		},
		South = {
			Pos = Vector3.new(0, 20, 325),
			Width = 24,
			Open = false,
			Note = "Южные ворота затоплены: путь в Морвен (глава 3)",
		},
	},
}

WorldLayout.Districts = {
	{
		Id = "square",
		Name = "Площадь Короны",
		Rect = { X1 = -50, Z1 = -50, X2 = 50, Z2 = 50 },
		Note = "100×100, фонтан Хранителей в центре, путевой камень",
	},
	{
		Id = "castle",
		Name = "Королевский замок",
		Rect = { X1 = -90, Z1 = -305, X2 = 90, Z2 = -150 },
		Note = "Замок ~160×130 на террасе +18; главная башня 120; тронный зал с королём и королевой",
	},
	{
		Id = "castle_terrace",
		Name = "Королевская лестница",
		Rect = { X1 = -40, Z1 = -150, X2 = 40, Z2 = -60 },
		Note = "Парадная лестница и терраса перед замком",
	},
	{
		Id = "academy",
		Name = "Академия магии",
		Rect = { X1 = -305, Z1 = -305, X2 = -170, Z2 = -175 },
		Note = "Башня-обсерватория, внутренний двор, архимаг",
	},
	{
		Id = "library",
		Name = "Великая библиотека",
		Rect = { X1 = -160, Z1 = -305, X2 = -100, Z2 = -200 },
		Note = "Высокий зал с витражами",
	},
	{
		Id = "alchemy",
		Name = "Алхимическая мастерская",
		Rect = { X1 = -155, Z1 = -140, X2 = -60, Z2 = -60 },
		Note = "Трубы, котлы, теплицы",
	},
	{
		Id = "residential_nw",
		Name = "Северо-западный жилой квартал",
		Rect = { X1 = -305, Z1 = -160, X2 = -170, Z2 = -24 },
		Note = "Фахверковые дома, узкие улочки",
	},
	{
		Id = "temple",
		Name = "Храм Хранителей",
		Rect = { X1 = 110, Z1 = -305, X2 = 200, Z2 = -200 },
		Note = "Купол, колоннада, точка возрождения",
	},
	{
		Id = "residential_ne",
		Name = "Северо-восточный жилой квартал",
		Rect = { X1 = 60, Z1 = -140, X2 = 200, Z2 = -60 },
		Note = "Богатые дома, сады",
	},
	{
		Id = "barracks",
		Name = "Казармы королевской стражи",
		Rect = { X1 = 215, Z1 = -305, X2 = 305, Z2 = -24 },
		Note = "Плац, тренировочные чучела, командир стражи (у Ворот Рассвета)",
	},
	{
		Id = "tavern",
		Name = "Таверна «Сломанный клык»",
		Rect = { X1 = -120, Z1 = 20, X2 = -60, Z2 = 55 },
		Note = "Двухэтажная таверна с открытым залом",
	},
	{
		Id = "market",
		Name = "Торговый район",
		Rect = { X1 = -200, Z1 = 60, X2 = -60, Z2 = 200 },
		Note = "Рыночные ряды, навесы, банк",
	},
	{
		Id = "guilds",
		Name = "Гильдейский квартал",
		Rect = { X1 = -305, Z1 = 20, X2 = -210, Z2 = 160 },
		Note = "Дома гильдий, Вольные Искатели",
	},
	{
		Id = "residential_sw",
		Name = "Юго-западный жилой квартал",
		Rect = { X1 = -305, Z1 = 210, X2 = -80, Z2 = 305 },
		Note = "Бедные дома, бельё на верёвках",
	},
	{
		Id = "smithy",
		Name = "Кузнечный квартал",
		Rect = { X1 = 60, Z1 = 60, X2 = 200, Z2 = 180 },
		Note = "Горны, дым, наковальни, старейшина дварфов",
	},
	{
		Id = "artisans",
		Name = "Район ремесленников",
		Rect = { X1 = 210, Z1 = 20, X2 = 305, Z2 = 160 },
		Note = "Мастерские, ткачи, плотники",
	},
	{
		Id = "warehouses",
		Name = "Склады",
		Rect = { X1 = 40, Z1 = 220, X2 = 200, Z2 = 305 },
		Note = "Амбары, телеги, вход в подземный район",
	},
	{
		Id = "residential_se",
		Name = "Юго-восточный жилой квартал",
		Rect = { X1 = 210, Z1 = 170, X2 = 305, Z2 = 305 },
		Note = "Дома ремесленников",
	},
	{
		Id = "undercroft",
		Name = "Подгорье (скрытый район)",
		Rect = { X1 = 60, Z1 = 230, X2 = 190, Z2 = 300 },
		Note = "Под складами на Y≈0: контрабандисты, тайный рынок",
	},
} :: { District }

-- ── Regions of Aydra (only Eldoria is built in this slice) ────────────────────
WorldLayout.Regions = {
	{
		Id = "Aurenholm",
		Name = "Ауренхольм",
		NameEn = "Aurenholm",
		Center = v2(0, 0),
		Size = v2(650, 650),
		Levels = { 1, 60 },
		Built = true,
		Theme = "Столица",
		Boss = "",
		Connections = { "Eldoria", "Noctholde", "Morven" },
	},
	{
		Id = "Eldoria",
		Name = "Эльдория",
		NameEn = "Eldoria",
		Center = v2(950, 0),
		Size = v2(1220, 1120),
		Levels = { 1, 8 },
		Built = true,
		Theme = "Зачарованный лес",
		Boss = "Лесной Страж",
		Connections = { "Aurenholm", "Viridia", "Noctholde" },
	},
	{
		Id = "Noctholde",
		Name = "Ноктхольд",
		NameEn = "Noctholde",
		Center = v2(450, -1450),
		Size = v2(1150, 1000),
		Levels = { 9, 16 },
		Built = false,
		Theme = "Земли вечной тьмы",
		Boss = "Рыцарь Безмолвия",
		Connections = { "Aurenholm", "Eldoria", "Morven", "Frostgard" },
	},
	{
		Id = "Frostgard",
		Name = "Фростгард",
		NameEn = "Frostgard",
		Center = v2(-200, -2100),
		Size = v2(1100, 800),
		Levels = { 17, 24 },
		Built = false,
		Theme = "Ледяные земли",
		Boss = "Королева Льда",
		Connections = { "Noctholde", "Aetherion" },
	},
	{
		Id = "Viridia",
		Name = "Виридия",
		NameEn = "Viridia",
		Center = v2(2250, 600),
		Size = v2(1100, 1100),
		Levels = { 9, 16 },
		Built = false,
		Theme = "Затерянные джунгли",
		Boss = "Матриарх Роя",
		Connections = { "Eldoria", "Ashar", "Thalassar" },
	},
	{
		Id = "Ashar",
		Name = "Ашар",
		NameEn = "Ashar",
		Center = v2(2500, -1000),
		Size = v2(1200, 1100),
		Levels = { 25, 32 },
		Built = false,
		Theme = "Песчаное королевство",
		Boss = "Песчаный Колосс",
		Connections = { "Viridia", "Infernum", "Umbra" },
	},
	{
		Id = "Infernum",
		Name = "Инфернум",
		NameEn = "Infernum",
		Center = v2(2400, -2150),
		Size = v2(1000, 700),
		Levels = { 33, 40 },
		Built = false,
		Theme = "Огненные земли",
		Boss = "Генерал Пламени",
		Connections = { "Ashar" },
	},
	{
		Id = "Morven",
		Name = "Морвен",
		NameEn = "Morven",
		Center = v2(-1100, 1100),
		Size = v2(1100, 1000),
		Levels = { 17, 24 },
		Built = false,
		Theme = "Проклятые болота",
		Boss = "Хозяин Топей",
		Connections = { "Aurenholm", "Noctholde", "Thalassar" },
	},
	{
		Id = "Aetherion",
		Name = "Аэтерион",
		NameEn = "Aetherion",
		Center = v2(-1900, -1950),
		Size = v2(1000, 900),
		Levels = { 41, 48 },
		Built = false,
		Theme = "Небесные острова",
		Boss = "Небесный Страж",
		Connections = { "Frostgard", "Necropolis" },
	},
	{
		Id = "Necropolis",
		Name = "Некрополис",
		NameEn = "Necropolis",
		Center = v2(-2350, -500),
		Size = v2(1000, 1100),
		Levels = { 49, 54 },
		Built = false,
		Theme = "Город мёртвых",
		Boss = "Верховный Лич",
		Connections = { "Aetherion", "Umbra", "Elysium" },
	},
	{
		Id = "Thalassar",
		Name = "Талассар",
		NameEn = "Thalassar",
		Center = v2(700, 2050),
		Size = v2(1500, 800),
		Levels = { 25, 32 },
		Built = false,
		Theme = "Подводное царство",
		Boss = "Морской Левиафан",
		Connections = { "Viridia", "Morven" },
	},
	{
		Id = "Umbra",
		Name = "Умбра",
		NameEn = "Umbra",
		Center = v2(-1700, 2050),
		Size = v2(1100, 800),
		Levels = { 49, 56 },
		Built = false,
		Theme = "Теневой разлом (подземный мир под континентом)",
		Boss = "Теневой Двойник",
		Connections = { "Ashar", "Necropolis", "Elysium" },
	},
	{
		Id = "Elysium",
		Name = "Элизиум",
		NameEn = "Elysium",
		Center = v2(-2650, 1500),
		Size = v2(800, 1000),
		Levels = { 56, 60 },
		Built = false,
		Theme = "Забытый рай",
		Boss = "Хранитель Врат",
		Connections = { "Necropolis", "Umbra" },
	},
} :: { RegionDef }

-- Geographic explanation of every connection (for docs, map tooltips and future builds).
WorldLayout.Passages = {
	{
		A = "Aurenholm",
		B = "Eldoria",
		Via = "Тракт Рассвета от восточных ворот, постепенно уходящий под кроны",
	},
	{
		A = "Aurenholm",
		B = "Noctholde",
		Via = "Северный тракт через Чёрный брод (закрыт в главе 1)",
	},
	{
		A = "Aurenholm",
		B = "Morven",
		Via = "Южная дорога вдоль разлившейся реки Вельмы",
	},
	{
		A = "Eldoria",
		B = "Viridia",
		Via = "Древняя долина на востоке, где лес постепенно становится джунглями (обвал — глава 2)",
	},
	{
		A = "Eldoria",
		B = "Noctholde",
		Via = "Северная лесная тропа через разрушенный мост (глава 2)",
	},
	{
		A = "Viridia",
		B = "Ashar",
		Via = "Ступенчатые пирамиды на краю джунглей, выходящие к дюнам",
	},
	{
		A = "Viridia",
		B = "Thalassar",
		Via = "Мангровое побережье и затопленные храмы",
	},
	{
		A = "Ashar",
		B = "Infernum",
		Via = "Вулканические пустоши и обсидиановые мосты",
	},
	{
		A = "Ashar",
		B = "Umbra",
		Via = "Погребённые гробницы, уходящие в теневой разлом",
	},
	{
		A = "Morven",
		B = "Noctholde",
		Via = "Западные марши — гать через мёртвые леса",
	},
	{ A = "Morven", B = "Thalassar", Via = "Прибрежные тропы и затопленные руины" },
	{ A = "Noctholde", B = "Frostgard", Via = "Горный перевал Безмолвных Колоколов" },
	{
		A = "Frostgard",
		B = "Aetherion",
		Via = "Горные маршруты и физические воздушные мосты",
	},
	{
		A = "Aetherion",
		B = "Necropolis",
		Via = "Нисходящие парящие острова над Пепельной равниной",
	},
	{ A = "Necropolis", B = "Umbra", Via = "Катакомбы, уходящие под континент" },
	{
		A = "Necropolis",
		B = "Elysium",
		Via = "Древняя каменная дорога через разрушенные земли",
	},
	{ A = "Umbra", B = "Elysium", Via = "Лестница Света из глубин разлома" },
}

-- ── Eldoria geography ─────────────────────────────────────────────────────────
WorldLayout.Eldoria = {
	Bounds = { X1 = 340, Z1 = -560, X2 = 1560, Z2 = 560 },
	-- Height guidance (Y of walkable ground) the terrain builder must respect so roads connect.
	Heights = {
		{ At = v2(345, 0), Y = 20, Note = "Ворота Рассвета — стык со столицей" },
		{ At = v2(620, 20), Y = 26, Note = "Лесная дорога, пологие холмы" },
		{
			At = v2(720, -230),
			Y = 14,
			Note = "Поляна мшистого света — низина с ручьём",
		},
		{ At = v2(820, 170), Y = 32, Note = "Разрушенный пост на гребне" },
		{ At = v2(650, 400), Y = 12, Note = "Лагерь разбойников в овраге" },
		{
			At = v2(1080, -60),
			Y = 26,
			Note = "Мшистый Приют среди гигантских деревьев",
		},
		{ At = v2(1250, -400), Y = 16, Note = "Водопад: чаша внизу, обрыв ~75 сверху" },
		{ At = v2(1300, 300), Y = 82, Note = "Холм обсерватории" },
		{ At = v2(1150, 330), Y = 40, Note = "Глухолесье" },
		{ At = v2(1410, -80), Y = 40, Note = "Терраса Древнего храма" },
	},
}

WorldLayout.Zones = {
	{
		Id = "outskirts",
		Name = "Предместья Ауренхольма",
		Region = "Aurenholm",
		Center = v2(-500, 0),
		Radius = 180,
		Level = { 1, 1 },
		Preset = "Outskirts",
		Safe = true,
	},
	{
		Id = "aurenholm",
		Name = "Ауренхольм",
		Region = "Aurenholm",
		Center = v2(0, 0),
		Radius = 330,
		Level = { 1, 1 },
		Preset = "Capital",
		Safe = true,
	},
	{
		Id = "forest_road",
		Name = "Лесная дорога",
		Region = "Eldoria",
		Center = v2(620, 10),
		Radius = 210,
		Level = { 1, 2 },
		Preset = "ForestEdge",
	},
	{
		Id = "mosslight_glade",
		Name = "Поляна мшистого света",
		Region = "Eldoria",
		Center = v2(720, -230),
		Radius = 85,
		Level = { 2, 3 },
		Preset = "Glade",
	},
	{
		Id = "ruined_outpost",
		Name = "Разрушенный эльфийский пост",
		Region = "Eldoria",
		Center = v2(820, 170),
		Radius = 75,
		Level = { 3, 3 },
		Preset = "Forest",
	},
	{
		Id = "bandit_camp",
		Name = "Лагерь «Серых Листьев»",
		Region = "Eldoria",
		Center = v2(650, 400),
		Radius = 75,
		Level = { 4, 5 },
		Preset = "ForestDark",
	},
	{
		Id = "mossreach",
		Name = "Мшистый Приют",
		Region = "Eldoria",
		Center = v2(1080, -60),
		Radius = 115,
		Level = { 4, 4 },
		Preset = "Settlement",
		Safe = true,
	},
	{
		Id = "waterfall",
		Name = "Водопад древних корней",
		Region = "Eldoria",
		Center = v2(1250, -400),
		Radius = 95,
		Level = { 5, 6 },
		Preset = "Waterfall",
	},
	{
		Id = "observatory",
		Name = "Заброшенная обсерватория",
		Region = "Eldoria",
		Center = v2(1300, 300),
		Radius = 85,
		Level = { 5, 6 },
		Preset = "Highland",
	},
	{
		Id = "deepwood",
		Name = "Глухолесье",
		Region = "Eldoria",
		Center = v2(1130, 330),
		Radius = 120,
		Level = { 6, 6 },
		Preset = "ForestDark",
	},
	{
		Id = "ancient_temple",
		Name = "Древний храм",
		Region = "Eldoria",
		Center = v2(1410, -80),
		Radius = 95,
		Level = { 6, 7 },
		Preset = "TempleApproach",
	},
	{
		Id = "root_tunnels",
		Name = "Скрытые корневые тоннели",
		Region = "Eldoria",
		Center = v2(1055, -315),
		Radius = 130,
		Level = { 5, 6 },
		Preset = "Tunnels",
		Underground = true,
	},
} :: { Zone }

WorldLayout.Roads = {
	{
		Id = "kingsroad",
		Name = "Королевский тракт",
		Width = 26,
		Kind = "Main",
		Points = { v2(-760, 0), v2(-560, 6), v2(-420, 2), v2(-325, 0) },
	},
	{
		Id = "dawn_road",
		Name = "Тракт Рассвета",
		Width = 24,
		Kind = "Main",
		Points = { v2(325, 0), v2(450, 6), v2(600, 28), v2(760, 22), v2(900, 2), v2(1000, -12), v2(1070, -22) },
	},
	{
		Id = "temple_way",
		Name = "Храмовый путь",
		Width = 14,
		Kind = "Secondary",
		Points = { v2(1070, -22), v2(1200, -52), v2(1330, -72), v2(1395, -80) },
	},
	{
		Id = "outpost_path",
		Name = "Тропа к посту",
		Width = 12,
		Kind = "Secondary",
		Points = { v2(760, 22), v2(795, 110), v2(818, 160) },
	},
	{
		Id = "glade_trail",
		Name = "Тропа мшистого света",
		Width = 9,
		Kind = "Trail",
		Points = { v2(640, 26), v2(680, -110), v2(715, -215) },
	},
	{
		Id = "observatory_climb",
		Name = "Подъём к обсерватории",
		Width = 12,
		Kind = "Secondary",
		Points = { v2(1070, -22), v2(1150, 110), v2(1235, 225), v2(1292, 292) },
	},
	{
		Id = "waterfall_trail",
		Name = "Тропа к водопаду",
		Width = 9,
		Kind = "Trail",
		Points = { v2(1200, -52), v2(1235, -220), v2(1252, -380) },
	},
	{
		Id = "camp_trail",
		Name = "Разбойничья тропа",
		Width = 8,
		Kind = "Trail",
		Points = { v2(800, 120), v2(725, 290), v2(655, 390) },
	},
	{
		Id = "deepwood_trail",
		Name = "Тропа Глухолесья",
		Width = 8,
		Kind = "Trail",
		Points = { v2(1150, 110), v2(1130, 230), v2(1120, 330) },
	},
	{
		Id = "root_tunnels",
		Name = "Корневые тоннели",
		Width = 10,
		Kind = "Hidden",
		Points = { v2(925, -300), v2(1000, -330), v2(1100, -320), v2(1180, -335) },
	},
} :: { Road }

-- Closed borders in this build — physical, in-world blockers with an explanation.
WorldLayout.Frontiers = {
	{
		Id = "frontier_viridia",
		Pos = v2(1550, 280),
		Note = "Обвал в Древней долине. «Путь в Виридию завален. Глава 2»",
	},
	{
		Id = "frontier_noctholde",
		Pos = v2(900, -550),
		Note = "Разрушенный мост через Чёрный ручей. «Северная тропа. Глава 2»",
	},
	{
		Id = "frontier_kingsroad",
		Pos = v2(-760, 0),
		Note = "Застава на тракте: «Дальше — земли без защиты короны»",
	},
}

-- ── Anchors ───────────────────────────────────────────────────────────────────
-- Region: "Capital" (capital builder), "Eldoria" (region builder).
-- Kind: Spawn, Waystone, NPC, Interact, SpawnGroup, Event, Door, Landmark.
-- Height: optional explicit Y (indoor/underground anchors); otherwise placed on the floor below.
WorldLayout.Anchors = {
	-- Spawns and waystones
	spawn_arrival = {
		Pos = v2(-470, 0),
		Yaw = -90,
		Region = "Capital",
		Kind = "Spawn",
		Note = "Первое появление на Королевском тракте, вид на Ворота Заката и замок",
	},
	waystone_aurenholm = {
		Pos = v2(30, 32),
		Yaw = 180,
		Region = "Capital",
		Kind = "Waystone",
		Note = "Путевой камень на Площади Короны",
	},
	respawn_capital_temple = {
		Pos = v2(155, -192),
		Yaw = 180,
		Region = "Capital",
		Kind = "Spawn",
		Note = "Ступени Храма Хранителей — возрождение в столице",
	},
	waystone_mossreach = {
		Pos = v2(1068, -18),
		Yaw = 90,
		Region = "Eldoria",
		Kind = "Waystone",
		Note = "Путевой камень Мшистого Приюта",
	},
	waystone_temple = {
		Pos = v2(1372, -58),
		Yaw = -90,
		Region = "Eldoria",
		Kind = "Waystone",
		Note = "Путевой камень у террасы храма",
	},

	-- Capital NPCs
	npc_herald = {
		Pos = v2(-428, 10),
		Yaw = 90,
		Region = "Capital",
		Kind = "NPC",
		Note = "Глашатай на тракте встречает новоприбывших",
	},
	npc_gate_guard_west = {
		Pos = v2(-342, 18),
		Yaw = 90,
		Region = "Capital",
		Kind = "NPC",
		Note = "Стражник у Ворот Заката (снаружи)",
	},
	npc_gate_guard_east = {
		Pos = v2(342, -18),
		Yaw = -90,
		Region = "Capital",
		Kind = "NPC",
		Note = "Стражник у Ворот Рассвета (снаружи)",
	},
	npc_wandering_sage = {
		Pos = v2(-26, -30),
		Yaw = 135,
		Region = "Capital",
		Kind = "NPC",
		Note = "Странствующий мудрец у фонтана",
	},
	npc_commander = {
		Pos = v2(258, -70),
		Yaw = 180,
		Region = "Capital",
		Kind = "NPC",
		Note = "Командир стражи Гальвард Рейн на плацу казарм",
	},
	npc_archmage = {
		Pos = v2(-238, -232),
		Yaw = 135,
		Region = "Capital",
		Kind = "NPC",
		Note = "Архимаг Велис Орманд во дворе Академии",
	},
	npc_academy_vendor = {
		Pos = v2(-196, -196),
		Yaw = 135,
		Region = "Capital",
		Kind = "NPC",
		Note = "Лавка Академии",
	},
	npc_king = {
		Pos = v2(-9, -262),
		Yaw = 180,
		Region = "Capital",
		Kind = "NPC",
		Height = 38,
		Note = "Король Эдриан в тронном зале (пол террасы +18)",
	},
	npc_queen = {
		Pos = v2(9, -262),
		Yaw = 180,
		Region = "Capital",
		Kind = "NPC",
		Height = 38,
		Note = "Королева Сильвена в тронном зале",
	},
	npc_blacksmith = {
		Pos = v2(128, 104),
		Yaw = 0,
		Region = "Capital",
		Kind = "NPC",
		Note = "Кузнец Бранок у горна",
	},
	npc_dwarf_elder = {
		Pos = v2(168, 150),
		Yaw = -45,
		Region = "Capital",
		Kind = "NPC",
		Note = "Старейшина дварфов Торгрим",
	},
	npc_alchemist = {
		Pos = v2(-98, -92),
		Yaw = 180,
		Region = "Capital",
		Kind = "NPC",
		Note = "Алхимик Мирабель",
	},
	npc_merchant_general = {
		Pos = v2(-128, 92),
		Yaw = 0,
		Region = "Capital",
		Kind = "NPC",
		Note = "Торговец у рыночного навеса",
	},
	npc_banker = {
		Pos = v2(-172, 168),
		Yaw = 90,
		Region = "Capital",
		Kind = "NPC",
		Note = "Банкир у Королевской казны",
	},
	npc_innkeeper = {
		Pos = v2(-92, 40),
		Yaw = 0,
		Region = "Capital",
		Kind = "NPC",
		Note = "Трактирщица за стойкой (внутри таверны)",
	},
	npc_mercenary_captain = {
		Pos = v2(-72, 24),
		Yaw = 0,
		Region = "Capital",
		Kind = "NPC",
		Note = "Капитан наёмников у входа в таверну",
	},
	npc_librarian = {
		Pos = v2(-130, -252),
		Yaw = 180,
		Region = "Capital",
		Kind = "NPC",
		Note = "Архивариус-библиотекарь Сейла",
	},
	npc_guildmistress = {
		Pos = v2(-256, 92),
		Yaw = 90,
		Region = "Capital",
		Kind = "NPC",
		Note = "Глава Вольных Искателей",
	},
	npc_priestess = {
		Pos = v2(155, -252),
		Yaw = 180,
		Region = "Capital",
		Kind = "NPC",
		Note = "Жрица Храма Хранителей",
	},
	npc_smuggler = {
		Pos = v2(122, 262),
		Yaw = 0,
		Region = "Capital",
		Kind = "NPC",
		Height = 2,
		Note = "Контрабандист в Подгорье (подземный район)",
	},
	city_event_square = {
		Pos = v2(0, 40),
		Yaw = 180,
		Region = "Capital",
		Kind = "Event",
		Note = "Центр городских событий (караван, объявления)",
	},
	city_event_gate_east = {
		Pos = v2(290, 0),
		Yaw = 90,
		Region = "Capital",
		Kind = "Event",
		Note = "Возвращение раненого отряда",
	},

	-- Eldoria NPCs
	npc_scout_fen = {
		Pos = v2(838, 178),
		Yaw = -135,
		Region = "Eldoria",
		Kind = "NPC",
		Note = "Раненый разведчик Фен у разрушенного поста",
	},
	npc_elder_ysolde = {
		Pos = v2(1098, -96),
		Yaw = 135,
		Region = "Eldoria",
		Kind = "NPC",
		Note = "Старейшина Изольда у Сердце-дерева",
	},
	npc_mossreach_vendor = {
		Pos = v2(1052, -108),
		Yaw = 90,
		Region = "Eldoria",
		Kind = "NPC",
		Note = "Обменник Мшистого Приюта",
	},
	npc_warden_lysa = {
		Pos = v2(1040, 30),
		Yaw = -90,
		Region = "Eldoria",
		Kind = "NPC",
		Note = "Лесная стражница Лиса у входа в поселение",
	},
	npc_archivist_orren = {
		Pos = v2(1360, -40),
		Yaw = -90,
		Region = "Eldoria",
		Kind = "NPC",
		Note = "Архивариус Оррен у террасы храма",
	},

	-- Quest interactables
	clue_broken_shield = {
		Pos = v2(802, 168),
		Yaw = 30,
		Region = "Eldoria",
		Kind = "Interact",
		Note = "Расколотый щит патруля",
	},
	clue_torn_banner = {
		Pos = v2(846, 150),
		Yaw = -60,
		Region = "Eldoria",
		Kind = "Interact",
		Note = "Разорванное знамя Ауренхольма на колу",
	},
	clue_patrol_journal = {
		Pos = v2(826, 192),
		Yaw = 0,
		Region = "Eldoria",
		Kind = "Interact",
		Note = "Журнал патруля под телом лошади/у костра",
	},
	clue_rune_scorch = {
		Pos = v2(764, 204),
		Yaw = 45,
		Region = "Eldoria",
		Kind = "Interact",
		Note = "Светящаяся руна, выжженная на эльфийской стеле",
	},
	observatory_lens = {
		Pos = v2(1300, 300),
		Yaw = 0,
		Region = "Eldoria",
		Kind = "Interact",
		Height = 108,
		Note = "Линза телескопа на верхней площадке обсерватории",
	},
	glade_shrine = {
		Pos = v2(722, -236),
		Yaw = 0,
		Region = "Eldoria",
		Kind = "Interact",
		Note = "Мшистый алтарь поляны (светокорень, лор)",
	},
	temple_door = {
		Pos = v2(1408, -80),
		Yaw = -90,
		Region = "Eldoria",
		Kind = "Door",
		Note = "Врата Древнего храма — вход в подземелье",
	},

	-- Enemy spawn groups
	sg_road_wolves = {
		Pos = v2(560, 70),
		Yaw = 0,
		Region = "Eldoria",
		Kind = "SpawnGroup",
		Note = "Испорченные волки у дороги",
	},
	sg_glade_wolves = {
		Pos = v2(690, -260),
		Yaw = 0,
		Region = "Eldoria",
		Kind = "SpawnGroup",
		Note = "Стая на поляне",
	},
	sg_outpost_bandits = {
		Pos = v2(812, 176),
		Yaw = 0,
		Region = "Eldoria",
		Kind = "SpawnGroup",
		Note = "Разбойники обыскивают пост",
	},
	sg_road_bandits_east = {
		Pos = v2(955, 40),
		Yaw = 0,
		Region = "Eldoria",
		Kind = "SpawnGroup",
		Note = "Засада у дороги",
	},
	sg_bandit_camp = {
		Pos = v2(650, 400),
		Yaw = 0,
		Region = "Eldoria",
		Kind = "SpawnGroup",
		Note = "Лагерь Серых Листьев",
	},
	sg_observatory_hunters = {
		Pos = v2(1268, 278),
		Yaw = 0,
		Region = "Eldoria",
		Kind = "SpawnGroup",
		Note = "Теневые охотники у обсерватории",
	},
	sg_waterfall_cultists = {
		Pos = v2(1232, -362),
		Yaw = 0,
		Region = "Eldoria",
		Kind = "SpawnGroup",
		Note = "Культисты у водопада",
	},
	sg_deepwood_shamblers = {
		Pos = v2(1140, 340),
		Yaw = 0,
		Region = "Eldoria",
		Kind = "SpawnGroup",
		Note = "Древесные шатуны",
	},
	sg_temple_approach = {
		Pos = v2(1330, -150),
		Yaw = 0,
		Region = "Eldoria",
		Kind = "SpawnGroup",
		Note = "Культисты и шатун на подходе к храму",
	},
	sg_tunnel_crawlers = {
		Pos = v2(1050, -320),
		Yaw = 0,
		Region = "Eldoria",
		Kind = "SpawnGroup",
		Height = -10,
		Note = "Существа в корневых тоннелях",
	},

	-- Dynamic events
	event_caravan_start = {
		Pos = v2(420, 4),
		Yaw = -90,
		Region = "Eldoria",
		Kind = "Event",
		Note = "Старт каравана из столицы",
	},
	event_caravan_ambush = {
		Pos = v2(900, 4),
		Yaw = -90,
		Region = "Eldoria",
		Kind = "Event",
		Note = "Место засады на караван",
	},
	event_caravan_end = {
		Pos = v2(1050, -12),
		Yaw = -90,
		Region = "Eldoria",
		Kind = "Event",
		Note = "Караван прибывает в Мшистый Приют",
	},
	event_corrupted_bloom = {
		Pos = v2(930, -170),
		Yaw = 0,
		Region = "Eldoria",
		Kind = "Event",
		Note = "Порченое цветение — очаги порчи",
	},
	event_ashen_stag = {
		Pos = v2(1000, 240),
		Yaw = 0,
		Region = "Eldoria",
		Kind = "Event",
		Note = "Появление редкого элитного Пепельного оленя",
	},
	event_mossreach_siege = {
		Pos = v2(1010, -40),
		Yaw = 90,
		Region = "Eldoria",
		Kind = "Event",
		Note = "Нападение на палисад поселения (цепочка событий)",
	},

	-- Landmarks / tunnels / frontiers
	root_tunnel_west = {
		Pos = v2(925, -300),
		Yaw = 90,
		Region = "Eldoria",
		Kind = "Landmark",
		Note = "Вход в корневые тоннели у поляны",
	},
	root_tunnel_east = {
		Pos = v2(1182, -336),
		Yaw = -90,
		Region = "Eldoria",
		Kind = "Landmark",
		Note = "Выход тоннелей за водопадом",
	},
} :: { [string]: Anchor }

function WorldLayout.ZoneAt(position: Vector3): Zone?
	local flat = Vector2.new(position.X, position.Z)
	local best: Zone? = nil
	local bestRadius = math.huge
	for _, zone in WorldLayout.Zones :: { Zone } do
		local underground = zone.Underground == true
		if underground and position.Y > 6 then
			continue
		end
		if (flat - zone.Center).Magnitude <= zone.Radius and zone.Radius < bestRadius then
			best = zone
			bestRadius = zone.Radius
		end
	end
	return best
end

function WorldLayout.DistrictAt(position: Vector3): District?
	for _, district in WorldLayout.Districts :: { District } do
		local r = district.Rect
		if position.X >= r.X1 and position.X <= r.X2 and position.Z >= r.Z1 and position.Z <= r.Z2 then
			if district.Id ~= "undercroft" or position.Y < 10 then
				return district
			end
		end
	end
	return nil
end

function WorldLayout.YawCFrame(position: Vector3, yaw: number): CFrame
	return CFrame.new(position) * CFrame.Angles(0, math.rad(yaw), 0)
end

return WorldLayout
