--!strict
--[[
	Scaling — group-size adaptation for encounters (1 / 2 / 3 / 5 players; 4 interpolates).
	Not a plain HP multiplier: each axis (health, damage, adds, mechanic counts, cadence)
	is tuned separately and bosses may override any row in Config/Bosses.
]]

export type ScaleRow = {
	Health: number,
	Difficulty: number, -- damage + pressure multiplier
	Adds: number, -- extra add multiplier for summons
	Mechanics: number, -- count of simultaneous mechanic objects (root anchors, lines...)
	Cadence: number, -- attack interval multiplier (<1 = faster)
	Targets: number, -- simultaneous targeted attacks
	Reward: number, -- reward quality multiplier (time/difficulty, NOT player count bias)
}

local Table: { [number]: ScaleRow } = {
	[1] = { Health = 1.0, Difficulty = 1.0, Adds = 1.0, Mechanics = 1, Cadence = 1.0, Targets = 1, Reward = 1.0 },
	[2] = { Health = 1.45, Difficulty = 1.2, Adds = 1.4, Mechanics = 2, Cadence = 0.95, Targets = 2, Reward = 1.0 },
	[3] = { Health = 1.9, Difficulty = 1.4, Adds = 1.8, Mechanics = 3, Cadence = 0.9, Targets = 2, Reward = 1.0 },
	[4] = { Health = 2.35, Difficulty = 1.58, Adds = 2.2, Mechanics = 4, Cadence = 0.87, Targets = 3, Reward = 1.0 },
	[5] = { Health = 2.8, Difficulty = 1.75, Adds = 2.6, Mechanics = 5, Cadence = 0.85, Targets = 3, Reward = 1.0 },
}

local Scaling = {}

function Scaling.Get(partySize: number, overrides: { [number]: { [string]: number } }?): ScaleRow
	local size = math.clamp(math.floor(partySize + 0.5), 1, 5)
	local row = table.clone(Table[size])
	local override = overrides and overrides[size]
	if override then
		for key, value in override do
			(row :: any)[key] = value
		end
	end
	return row
end

Scaling.Table = Table

return Scaling
