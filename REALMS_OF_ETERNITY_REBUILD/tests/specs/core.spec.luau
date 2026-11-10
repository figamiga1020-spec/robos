-- Core logic: validation, rate limiting, shapes, formulas, data schema, configs.
local Validate = T.load("ReplicatedStorage/Shared/Logic/Validate")
local RateLimiter = T.load("ReplicatedStorage/Shared/Logic/RateLimiter")
local Shapes = T.load("ReplicatedStorage/Shared/Logic/Shapes")
local Formulas = T.load("ReplicatedStorage/Shared/Logic/Formulas")
local DataSchema = T.load("ReplicatedStorage/Shared/Logic/DataSchema")
local Classes = T.load("ReplicatedStorage/Shared/Config/Classes")
local Races = T.load("ReplicatedStorage/Shared/Config/Races")
local Items = T.load("ReplicatedStorage/Shared/Config/Items")
local Statuses = T.load("ReplicatedStorage/Shared/Config/Statuses")
local Scaling = T.load("ReplicatedStorage/Shared/Config/Scaling")
local WorldLayout = T.load("ReplicatedStorage/Shared/Config/WorldLayout")

T.describe("Validate", function()
	T.it("rejects NaN and infinity", function()
		local check = Validate.Number(0, 100)
		T.expect((check(0 / 0))).toBeFalsy()
		T.expect((check(math.huge))).toBeFalsy()
		T.expect((check(50))).toBeTruthy()
	end)
	T.it("enforces string length and utf8", function()
		local check = Validate.String(5)
		T.expect((check("abcdef"))).toBeFalsy()
		T.expect((check("abc"))).toBeTruthy()
		T.expect((check(42))).toBeFalsy()
	end)
	T.it("validates vectors", function()
		local check = Validate.Direction()
		T.expect((check(Vector3.new(0, 0, 0)))).toBeFalsy()
		T.expect((check(Vector3.new(1, 0, 0)))).toBeTruthy()
		T.expect((check(Vector3.new(0 / 0, 0, 1)))).toBeFalsy()
	end)
	T.it("rejects unknown keys in shapes and extra args", function()
		local shape = Validate.Shape({ A = Validate.Number() })
		T.expect((shape({ A = 1 }))).toBeTruthy()
		T.expect((shape({ A = 1, B = 2 }))).toBeFalsy()
		T.expect((Validate.Args({ Validate.Number() }, { 1, 2 }, 2))).toBeFalsy()
	end)
end)

T.describe("RateLimiter", function()
	T.it("limits bursts and refills over time", function()
		local clock = 0
		local limiter = RateLimiter.new(3, 1, function()
			return clock
		end)
		T.expect(limiter:Allow("p")).toBe(true)
		T.expect(limiter:Allow("p")).toBe(true)
		T.expect(limiter:Allow("p")).toBe(true)
		T.expect(limiter:Allow("p")).toBe(false)
		clock = 1.1
		T.expect(limiter:Allow("p")).toBe(true)
		T.expect(limiter:Allow("q")).toBe(true)
	end)
end)

T.describe("Shapes", function()
	local origin = CFrame.new(0, 0, 0)
	T.it("cone covers the front, not the back", function()
		local cone = { Type = "Cone", Range = 10, Angle = 90 }
		T.expect(Shapes.Contains(cone, origin, Vector3.new(0, 0, -5), 0)).toBe(true)
		T.expect(Shapes.Contains(cone, origin, Vector3.new(0, 0, 5), 0)).toBe(false)
		T.expect(Shapes.Contains(cone, origin, Vector3.new(8, 0, -2), 0)).toBe(false)
	end)
	T.it("target radius inflates reach", function()
		local sphere = { Type = "Sphere", Radius = 5 }
		T.expect(Shapes.Contains(sphere, origin, Vector3.new(6, 0, 0), 0)).toBe(false)
		T.expect(Shapes.Contains(sphere, origin, Vector3.new(6, 0, 0), 1.5)).toBe(true)
	end)
	T.it("ring excludes the inner safe zone", function()
		local ring = { Type = "Ring", Inner = 6, Radius = 20 }
		T.expect(Shapes.Contains(ring, origin, Vector3.new(3, 0, 0), 0)).toBe(false)
		T.expect(Shapes.Contains(ring, origin, Vector3.new(12, 0, 0), 0)).toBe(true)
	end)
	T.it("line extends forward only", function()
		local lineShape = { Type = "Line", Range = 12, Width = 4 }
		T.expect(Shapes.Contains(lineShape, origin, Vector3.new(1, 0, -11), 0)).toBe(true)
		T.expect(Shapes.Contains(lineShape, origin, Vector3.new(3, 0, -5), 0)).toBe(false)
		T.expect(Shapes.Contains(lineShape, origin, Vector3.new(0, 0, 4), 0)).toBe(false)
	end)
end)

T.describe("Formulas", function()
	T.it("computes sane level-1 stats for every playable class", function()
		for _, id in Classes.Phase1 do
			local stats = Formulas.ComputeStats({
				Class = Classes.Get(id),
				Race = Races.Get("Human"),
				Level = 1,
				ItemStats = {},
				Modifiers = {},
			})
			T.expect(stats.MaxHealth).toBeGreaterThan(100)
			T.expect(stats.AttackPower).toBeGreaterThan(5)
			T.expect(stats.MoveSpeed >= 8 and stats.MoveSpeed <= 28).toBe(true)
		end
	end)
	T.it("applies Add before Mul modifiers and clamps crit", function()
		local base = Formulas.ComputeStats({ Class = Classes.Get("Knight"), Level = 1, ItemStats = {}, Modifiers = {} })
		local modded = Formulas.ComputeStats({
			Class = Classes.Get("Knight"),
			Level = 1,
			ItemStats = {},
			Modifiers = {
				{ Stat = "MaxHealth", Op = "Mul", Value = 2 },
				{ Stat = "MaxHealth", Op = "Add", Value = 10 },
				{ Stat = "CritChance", Op = "Add", Value = 5 },
			},
		})
		T.expect(modded.MaxHealth).toBe(math.floor((base.MaxHealth + 10) * 2 + 0.5))
		T.expect(modded.CritChance).toBe(0.75)
	end)
	T.it("grows with level and gear", function()
		local l1 = Formulas.ComputeStats({ Class = Classes.Get("Mage"), Level = 1, ItemStats = {}, Modifiers = {} })
		local l8 = Formulas.ComputeStats({
			Class = Classes.Get("Mage"),
			Level = 8,
			ItemStats = { { SpellPower = 37 } },
			Modifiers = {},
		})
		T.expect(l8.SpellPower).toBeGreaterThan(l1.SpellPower + 37)
		T.expect(l8.MaxHealth).toBeGreaterThan(l1.MaxHealth)
	end)
	T.it("mitigation is bounded", function()
		T.expect(Formulas.Mitigation(0, 1)).toBe(1)
		T.expect(Formulas.Mitigation(1e9, 1)).toBeNear(0.25, 1e-6)
	end)
	T.it("XP application levels up and respects the cap", function()
		local level, xp, ups = Formulas.ApplyXP(1, 0, Formulas.XPToNext(1) + 5, 8)
		T.expect(level).toBe(2)
		T.expect(xp).toBe(5)
		T.expect(ups).toBe(1)
		local capped = Formulas.ApplyXP(7, 0, 1e9, 8)
		T.expect(capped).toBe(8)
	end)
	T.it("set bonuses activate at 2 and 4 pieces", function()
		local two = Formulas.SetBonuses({ "AurenholmGuard", "AurenholmGuard" }, Items.Sets)
		local four =
			Formulas.SetBonuses({ "AurenholmGuard", "AurenholmGuard", "AurenholmGuard", "AurenholmGuard" }, Items.Sets)
		T.expect(#two).toBe(1)
		T.expect(#four).toBe(2)
	end)
end)

T.describe("DataSchema", function()
	T.it("migrates a v1 profile without losing characters", function()
		local raw = {
			Version = 1,
			Characters = {
				abc = {
					Id = "abc",
					Name = "Ирма",
					Race = "Elf",
					Class = "Ranger",
					Level = 5,
					Inventory = { u1 = { Uid = "u1", Id = "bow_hunter", Qty = 1 } },
				},
			},
			Order = { "abc" },
		}
		local profile, migrated = DataSchema.Migrate(raw, 100)
		T.expect(migrated).toBe(true)
		T.expect(profile.Version).toBe(DataSchema.VERSION)
		T.expect(profile.Characters.abc.Level).toBe(5)
		T.expect(profile.Characters.abc.Inventory.u1.Id).toBe("bow_hunter")
		T.expect(type(profile.Characters.abc.Rewards)).toBe("table")
		T.expect(profile.Settings ~= nil).toBe(true)
	end)
	T.it("never downgrades data from a newer version", function()
		local raw = { Version = DataSchema.VERSION + 5, Characters = {}, Order = {} }
		local profile, migrated = DataSchema.Migrate(raw, 1)
		T.expect(migrated).toBe(false)
		T.expect(profile.Version).toBe(DataSchema.VERSION + 5)
	end)
	T.it("validates names", function()
		T.expect((DataSchema.ValidateName("Ариэль"))).toBe(true)
		T.expect((DataSchema.ValidateName("Kael-Thorn"))).toBe(true)
		T.expect((DataSchema.ValidateName("ab"))).toBe(false)
		T.expect((DataSchema.ValidateName("x1x1x1"))).toBe(false)
		T.expect((DataSchema.ValidateName(" Lead"))).toBe(false)
	end)
	T.it("sanitises appearance against race options", function()
		local race = Races.Get("Dwarf")
		local clean = DataSchema.SanitizeAppearance(
			{
				BodyType = 9,
				Height = 5,
				SkinTone = 99,
				Face = 2,
				Hair = "Mohawk",
				HairColor = 1,
				EyeColor = 1,
				Feature = "FullBeard",
				FeatureColor = 1,
				Marking = 1,
			},
			race
		)
		T.expect(clean.BodyType).toBe(1)
		T.expect(clean.Height).toBe(1)
		T.expect(clean.SkinTone).toBe(1)
		T.expect(clean.Hair).toBe(race.HairStyles[1])
		T.expect(clean.Feature).toBe("FullBeard")
	end)
end)

T.describe("Config integrity", function()
	T.it("every Phase-1 class has a complete combat kit", function()
		for _, id in Classes.Phase1 do
			local def = Classes.Get(id)
			for _, slot in
				{ "Light", "Heavy", "Secondary", "Dodge", "Skill1", "Skill2", "Skill3", "Skill4", "Ultimate" }
			do
				local actionId = def.Bar[slot]
				T.expect(actionId ~= nil).toBe(true)
				local action = Classes.GetAction(actionId)
				T.expect(action ~= nil).toBe(true)
				T.expect(action.Duration > 0).toBe(true)
				T.expect(type(action.Clip)).toBe("string")
				for _, hit in action.Hits or {} do
					T.expect(hit.At <= action.Duration + 1e-6).toBe(true)
					for _, status in hit.Statuses or {} do
						T.expect(Statuses.Get(status.Id) ~= nil).toBe(true)
					end
				end
				for _, projectile in action.Projectiles or {} do
					T.expect(projectile.At <= action.Duration + 1e-6).toBe(true)
				end
			end
			-- light combo chain has three steps and terminates
			local chain, current = 0, def.Bar.Light
			while current and chain < 10 do
				chain += 1
				current = Classes.GetAction(current).ComboNext
			end
			T.expect(chain).toBe(3)
			T.expect(#def.Specs).toBe(3)
			T.expect(#def.Talents >= 4).toBe(true)
			for _, itemId in def.StarterKit do
				T.expect(Items.Get(itemId) ~= nil).toBe(true)
			end
		end
	end)
	T.it("all 20 classes and 15 races exist", function()
		T.expect(#Classes.Order).toBe(20)
		T.expect(#Races.Order).toBe(15)
	end)
	T.it("modifier paths resolve against their actions", function()
		for _, id in Classes.Phase1 do
			local def = Classes.Get(id)
			local mods = {}
			for _, spec in def.Specs do
				for _, m in spec.Mods do
					table.insert(mods, m)
				end
			end
			for _, tier in def.Talents do
				for _, choice in tier.Choices do
					for _, m in choice.Mods do
						table.insert(mods, m)
					end
				end
			end
			for _, m in mods do
				if m.Action then
					local node = Classes.GetAction(m.Action)
					T.expect(node ~= nil).toBe(true)
					local parts = string.split(m.Path, ".")
					for index = 1, #parts - 1 do
						local key = tonumber(parts[index]) or parts[index]
						node = node[key]
						if node == nil then
							error(`bad path {m.Action}.{m.Path}`)
						end
					end
				end
			end
		end
	end)
	T.it("items reference valid sets and vendors reference valid items", function()
		for _, item in Items.Items do
			if item.Set then
				T.expect(Items.Sets[item.Set] ~= nil).toBe(true)
			end
		end
		for _, vendor in Items.Vendors do
			for _, entry in vendor.Stock do
				T.expect(Items.Get(entry.Id) ~= nil).toBe(true)
			end
		end
	end)
	T.it("scaling follows the design table", function()
		T.expect(Scaling.Get(1).Health).toBe(1)
		T.expect(Scaling.Get(2).Health).toBe(1.45)
		T.expect(Scaling.Get(3).Health).toBe(1.9)
		T.expect(Scaling.Get(5).Health).toBe(2.8)
		T.expect(Scaling.Get(9).Health).toBe(2.8)
	end)
	T.it("world anchors sit inside their regions and zones resolve", function()
		local capital = WorldLayout.Capital.HalfSize
		for id, anchor in WorldLayout.Anchors do
			if anchor.Region == "Eldoria" then
				local b = WorldLayout.Eldoria.Bounds
				if
					not (
						anchor.Pos.X >= b.X1
						and anchor.Pos.X <= b.X2
						and anchor.Pos.Y >= b.Z1
						and anchor.Pos.Y <= b.Z2
					)
				then
					error(`anchor {id} outside Eldoria`)
				end
			end
		end
		T.expect(WorldLayout.ZoneAt(Vector3.new(1080, 26, -60)).Id).toBe("mossreach")
		T.expect(WorldLayout.ZoneAt(Vector3.new(0, 20, 0)).Id).toBe("aurenholm")
		T.expect(capital).toBe(325)
	end)
end)
