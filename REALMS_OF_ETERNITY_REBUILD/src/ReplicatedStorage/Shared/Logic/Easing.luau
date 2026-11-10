--!strict
--[[
	Easing — curve functions used by the animation engine, UI tweens and VFX timing.
	All functions map t in [0,1] -> [0,1] (Back/Elastic may overshoot).
]]

export type EaseName =
	"Linear"
	| "Constant"
	| "InQuad"
	| "OutQuad"
	| "InOutQuad"
	| "InCubic"
	| "OutCubic"
	| "InOutCubic"
	| "InOutSine"
	| "OutExpo"
	| "InExpo"
	| "OutBack"
	| "InBack"
	| "OutElastic"

local Easing = {}

local functions: { [string]: (number) -> number } = {
	Linear = function(t)
		return t
	end,
	Constant = function(_t)
		return 0
	end,
	InQuad = function(t)
		return t * t
	end,
	OutQuad = function(t)
		return 1 - (1 - t) * (1 - t)
	end,
	InOutQuad = function(t)
		return if t < 0.5 then 2 * t * t else 1 - (-2 * t + 2) ^ 2 / 2
	end,
	InCubic = function(t)
		return t * t * t
	end,
	OutCubic = function(t)
		return 1 - (1 - t) ^ 3
	end,
	InOutCubic = function(t)
		return if t < 0.5 then 4 * t * t * t else 1 - (-2 * t + 2) ^ 3 / 2
	end,
	InOutSine = function(t)
		return -(math.cos(math.pi * t) - 1) / 2
	end,
	OutExpo = function(t)
		return if t >= 1 then 1 else 1 - 2 ^ (-10 * t)
	end,
	InExpo = function(t)
		return if t <= 0 then 0 else 2 ^ (10 * t - 10)
	end,
	OutBack = function(t)
		local c1 = 1.70158
		local c3 = c1 + 1
		return 1 + c3 * (t - 1) ^ 3 + c1 * (t - 1) ^ 2
	end,
	InBack = function(t)
		local c1 = 1.70158
		local c3 = c1 + 1
		return c3 * t * t * t - c1 * t * t
	end,
	OutElastic = function(t)
		if t <= 0 or t >= 1 then
			return t
		end
		return 2 ^ (-10 * t) * math.sin((t * 10 - 0.75) * (2 * math.pi) / 3) + 1
	end,
}

function Easing.Get(name: string?): (number) -> number
	return functions[name or "InOutSine"] or functions.InOutSine
end

function Easing.Apply(name: string?, t: number): number
	return Easing.Get(name)(math.clamp(t, 0, 1))
end

return Easing
