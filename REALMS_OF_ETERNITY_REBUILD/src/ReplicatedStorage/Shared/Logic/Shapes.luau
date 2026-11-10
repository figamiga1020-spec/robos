--!strict
--[[
	Shapes — authoritative hit-volume math shared by server hit detection and client telegraphs.
	Local frame: origin at actor root (ground level), forward = -Z (CFrame.LookVector).
	`targetRadius` inflates the test so large creatures are hit at their edge, not their centre.
]]

local Types = require(script.Parent.Parent.Core.Types)

type Shape = Types.Shape

local Shapes = {}

local DEFAULT_HEIGHT = 10

function Shapes.Contains(shape: Shape, origin: CFrame, point: Vector3, targetRadius: number?): boolean
	local pad = targetRadius or 0
	local frame = if shape.Offset then origin * CFrame.new(shape.Offset) else origin
	local localPoint = frame:PointToObjectSpace(point)
	local height = shape.Height or DEFAULT_HEIGHT
	if math.abs(localPoint.Y) > height + pad then
		return false
	end
	local flat = Vector3.new(localPoint.X, 0, localPoint.Z)
	local distance = flat.Magnitude

	if shape.Type == "Sphere" then
		return distance <= (shape.Radius or 0) + pad
	elseif shape.Type == "Ring" then
		return distance <= (shape.Radius or 0) + pad and distance >= math.max(0, (shape.Inner or 0) - pad)
	elseif shape.Type == "Cone" then
		local range = shape.Range or 0
		if distance > range + pad then
			return false
		end
		if distance <= pad + 1 then
			return true -- point-blank always counts
		end
		local forward = Vector3.new(0, 0, -1)
		local cos = flat.Unit:Dot(forward)
		local halfAngle = math.rad((shape.Angle or 90) / 2)
		-- widen by the angular size of the target's radius at this distance
		local slack = math.atan2(pad, distance)
		return cos >= math.cos(math.min(math.pi, halfAngle + slack))
	elseif shape.Type == "Box" then
		local halfW = (shape.Width or 0) / 2 + pad
		local length = shape.Length or 0
		return math.abs(localPoint.X) <= halfW and localPoint.Z <= pad and localPoint.Z >= -(length + pad)
	elseif shape.Type == "Line" then
		local halfW = (shape.Width or 2) / 2 + pad
		local length = shape.Range or shape.Length or 0
		return math.abs(localPoint.X) <= halfW and localPoint.Z <= pad and localPoint.Z >= -(length + pad)
	end
	return false
end

-- Approximate footprint radius (for broad-phase culling).
function Shapes.Reach(shape: Shape): number
	local base = 0
	if shape.Type == "Sphere" or shape.Type == "Ring" then
		base = shape.Radius or 0
	elseif shape.Type == "Cone" then
		base = shape.Range or 0
	elseif shape.Type == "Box" then
		local w = (shape.Width or 0) / 2
		local l = shape.Length or 0
		base = math.sqrt(w * w + l * l)
	elseif shape.Type == "Line" then
		local w = (shape.Width or 2) / 2
		local l = shape.Range or shape.Length or 0
		base = math.sqrt(w * w + l * l)
	end
	local offset = shape.Offset
	return base + (if offset then offset.Magnitude else 0)
end

return Shapes
