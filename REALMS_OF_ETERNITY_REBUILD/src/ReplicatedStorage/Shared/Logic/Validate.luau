--!strict
--[[
	Validate — runtime type checkers for every client → server payload.
	A checker returns (true) or (false, reason). Nothing from the client is trusted:
	NaN/inf numbers, oversized strings, wrong instance classes and unknown enum values are rejected.
	Pure Luau (no Roblox services) so it is unit-tested under Lune.
]]

export type Checker = (value: any) -> (boolean, string?)

local Validate = {}

local function isFiniteNumber(value: any): boolean
	return type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
end

function Validate.Any(): Checker
	return function(_value: any)
		return true
	end
end

function Validate.Number(min: number?, max: number?): Checker
	return function(value: any)
		if not isFiniteNumber(value) then
			return false, "expected finite number"
		end
		if min and value < min then
			return false, `number below {min}`
		end
		if max and value > max then
			return false, `number above {max}`
		end
		return true
	end
end

function Validate.Integer(min: number?, max: number?): Checker
	local number = Validate.Number(min, max)
	return function(value: any)
		local ok, err = number(value)
		if not ok then
			return false, err
		end
		if value % 1 ~= 0 then
			return false, "expected integer"
		end
		return true
	end
end

function Validate.String(maxLength: number, minLength: number?): Checker
	return function(value: any)
		if type(value) ~= "string" then
			return false, "expected string"
		end
		if #value > maxLength then
			return false, "string too long"
		end
		if minLength and #value < minLength then
			return false, "string too short"
		end
		if not utf8.len(value) then
			return false, "invalid utf8"
		end
		return true
	end
end

function Validate.Boolean(): Checker
	return function(value: any)
		if type(value) ~= "boolean" then
			return false, "expected boolean"
		end
		return true
	end
end

-- Accepts one of the listed string values.
function Validate.OneOf(options: { string }): Checker
	local set: { [string]: boolean } = {}
	for _, option in options do
		set[option] = true
	end
	return function(value: any)
		if type(value) ~= "string" or not set[value] then
			return false, "unexpected value"
		end
		return true
	end
end

-- Accepts a key of the given table (e.g. an id in a config table).
function Validate.KeyOf(map: { [string]: any }): Checker
	return function(value: any)
		if type(value) ~= "string" or map[value] == nil then
			return false, "unknown id"
		end
		return true
	end
end

function Validate.Vector3(maxMagnitude: number?): Checker
	return function(value: any)
		if typeof(value) ~= "Vector3" then
			return false, "expected Vector3"
		end
		if not (isFiniteNumber(value.X) and isFiniteNumber(value.Y) and isFiniteNumber(value.Z)) then
			return false, "non-finite vector"
		end
		if maxMagnitude and value.Magnitude > maxMagnitude then
			return false, "vector too large"
		end
		return true
	end
end

-- Unit-ish direction: finite, non-zero; caller should still .Unit it.
function Validate.Direction(): Checker
	local vector = Validate.Vector3(4)
	return function(value: any)
		local ok, err = vector(value)
		if not ok then
			return false, err
		end
		if value.Magnitude < 1e-3 then
			return false, "zero direction"
		end
		return true
	end
end

function Validate.Instance(className: string?): Checker
	return function(value: any)
		if typeof(value) ~= "Instance" then
			return false, "expected Instance"
		end
		if className and not value:IsA(className) then
			return false, `expected {className}`
		end
		return true
	end
end

function Validate.Optional(checker: Checker): Checker
	return function(value: any)
		if value == nil then
			return true
		end
		return checker(value)
	end
end

-- Exact-shape dictionary: every listed key validated, unknown keys rejected.
function Validate.Shape(fields: { [string]: Checker }, maxExtraKeys: number?): Checker
	return function(value: any)
		if type(value) ~= "table" then
			return false, "expected table"
		end
		local extra = 0
		for key in value do
			if type(key) ~= "string" then
				return false, "non-string key"
			end
			if fields[key] == nil then
				extra += 1
			end
		end
		if extra > (maxExtraKeys or 0) then
			return false, "unexpected keys"
		end
		for key, checker in fields do
			local ok, err = checker(value[key])
			if not ok then
				return false, `{key}: {err or "invalid"}`
			end
		end
		return true
	end
end

function Validate.Array(checker: Checker, maxLength: number): Checker
	return function(value: any)
		if type(value) ~= "table" then
			return false, "expected array"
		end
		local count = 0
		for key in value do
			count += 1
			if type(key) ~= "number" or key % 1 ~= 0 or key < 1 then
				return false, "not an array"
			end
		end
		if count > maxLength or count ~= #value then
			return false, "bad array length"
		end
		for _, item in value do
			local ok, err = checker(item)
			if not ok then
				return false, err
			end
		end
		return true
	end
end

-- Validates a list of arguments against a list of checkers (extra args rejected).
function Validate.Args(checkers: { Checker }, args: { any }, argCount: number): (boolean, string?)
	if argCount > #checkers then
		return false, "too many arguments"
	end
	for index, checker in checkers do
		local ok, err = checker(args[index])
		if not ok then
			return false, `arg {index}: {err or "invalid"}`
		end
	end
	return true
end

Validate.IsFiniteNumber = isFiniteNumber

return Validate
