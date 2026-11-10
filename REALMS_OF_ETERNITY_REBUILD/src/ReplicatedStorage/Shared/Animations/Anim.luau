--!strict
--[[
	Anim — authoring helpers and data types for keyframe clips (Motor6D.Transform offsets).

	A clip is a list of keyframes; each keyframe maps joint (Motor6D) names to a Transform CFrame
	relative to the rig's rest pose. Interpolation from key i to key i+1 uses key i's Ease.
	Joints that appear in any key are "owned" by the clip (missing in a key = rest pose);
	joints that never appear are left to lower layers (natural masking).

	Authoring (degrees, studs):
	  local A = require(Shared.Animations.Anim)
	  return A.Set("Knight", "Humanoid", {
	    Knight_Light1 = A.Clip(0.55, {
	      A.Key(0.00, { RightShoulder = A.R(0, 0, 20) }, "OutQuad"),
	      A.Key(0.22, { RightShoulder = A.R(-80, 40, 90), Waist = A.R(0, -35, 0) }, "OutCubic"),
	      A.Key(0.55, {}),
	    }, { Markers = { Hit = 0.22 } }),
	  })
]]

local Easing = require(script.Parent.Parent.Logic.Easing)

export type Pose = { [string]: CFrame }
export type Keyframe = { T: number, Pose: Pose, Ease: string? }
export type Clip = {
	Name: string,
	Length: number,
	Keys: { Keyframe },
	Joints: { [string]: boolean },
	Looped: boolean,
	Priority: number, -- higher overrides lower among action tracks
	FadeIn: number,
	FadeOut: number,
	Additive: boolean,
	Markers: { [string]: number },
	Weight: number,
}
export type ClipOptions = {
	Looped: boolean?,
	Priority: number?,
	FadeIn: number?,
	FadeOut: number?,
	Additive: boolean?,
	Markers: { [string]: number }?,
	Weight: number?,
}
export type AnimSet = {
	Name: string,
	Inherit: string?,
	Clips: { [string]: Clip },
	-- locomotion thresholds (studs/s) used by the controller to pick Idle/Walk/Run/Sprint
	Locomotion: { Walk: number, Run: number, Sprint: number, WalkCycleSpeed: number?, RunCycleSpeed: number? }?,
	-- optional per-frame procedural post-process: modify `poses` in place
	Procedural: ((ctx: any, poses: Pose, dt: number, now: number) -> ())?,
}

local Anim = {}

local rad = math.rad

-- Rotation in degrees (X pitch, Y yaw, Z roll), applied in XYZ order.
function Anim.R(x: number, y: number, z: number): CFrame
	return CFrame.Angles(rad(x), rad(y), rad(z))
end

-- Translation (studs) + rotation (degrees).
function Anim.P(px: number, py: number, pz: number, rx: number?, ry: number?, rz: number?): CFrame
	return CFrame.new(px, py, pz) * CFrame.Angles(rad(rx or 0), rad(ry or 0), rad(rz or 0))
end

function Anim.Key(t: number, pose: Pose, ease: string?): Keyframe
	return { T = t, Pose = pose, Ease = ease }
end

function Anim.Clip(length: number, keys: { Keyframe }, options: ClipOptions?): Clip
	local opts: ClipOptions = options or {}
	table.sort(keys, function(a, b)
		return a.T < b.T
	end)
	local joints: { [string]: boolean } = {}
	for _, key in keys do
		for joint in key.Pose do
			joints[joint] = true
		end
	end
	return {
		Name = "",
		Length = length,
		Keys = keys,
		Joints = joints,
		Looped = opts.Looped == true,
		Priority = opts.Priority or 1,
		FadeIn = opts.FadeIn or 0.08,
		FadeOut = opts.FadeOut or 0.15,
		Additive = opts.Additive == true,
		Markers = opts.Markers or {},
		Weight = opts.Weight or 1,
	}
end

function Anim.Set(name: string, inherit: string?, clips: { [string]: Clip }, extra: { [string]: any }?): AnimSet
	for clipName, clip in clips do
		clip.Name = clipName
	end
	local set: AnimSet = { Name = name, Inherit = inherit, Clips = clips }
	if extra then
		for key, value in extra do
			(set :: any)[key] = value
		end
	end
	return set
end

-- Samples a clip at time t (seconds). Writes into `out` only joints owned by the clip.
function Anim.Sample(clip: Clip, t: number, out: Pose)
	local keys = clip.Keys
	local count = #keys
	if count == 0 then
		return
	end
	local time = t
	if clip.Looped and clip.Length > 0 then
		time = t % clip.Length
	else
		time = math.clamp(t, 0, clip.Length)
	end
	if count == 1 or time <= keys[1].T then
		local pose = keys[1].Pose
		for joint in clip.Joints do
			out[joint] = pose[joint] or CFrame.identity
		end
		return
	end
	local last = keys[count]
	if time >= last.T then
		if clip.Looped then
			-- wrap from last key back to the first over the remaining loop time
			local span = clip.Length - last.T
			local alpha = if span > 1e-4 then (time - last.T) / span else 1
			alpha = Easing.Apply(last.Ease, alpha)
			local first = keys[1].Pose
			for joint in clip.Joints do
				local a = last.Pose[joint] or CFrame.identity
				local b = first[joint] or CFrame.identity
				out[joint] = a:Lerp(b, alpha)
			end
		else
			for joint in clip.Joints do
				out[joint] = last.Pose[joint] or CFrame.identity
			end
		end
		return
	end
	for index = 1, count - 1 do
		local a = keys[index]
		local b = keys[index + 1]
		if time >= a.T and time <= b.T then
			local span = b.T - a.T
			local alpha = if span > 1e-4 then (time - a.T) / span else 1
			alpha = Easing.Apply(a.Ease, alpha)
			for joint in clip.Joints do
				local from = a.Pose[joint] or CFrame.identity
				local to = b.Pose[joint] or CFrame.identity
				out[joint] = from:Lerp(to, alpha)
			end
			return
		end
	end
end

return Anim
