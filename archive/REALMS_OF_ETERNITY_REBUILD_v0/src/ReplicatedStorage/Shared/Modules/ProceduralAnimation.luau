--!strict
--[[
	Procedural animation layer via Motor6D.Transform.
	Used until real published Animation assets exist in Studio.
	Plays short, readable combat/locomotion sequences on R15-like rigs.
]]

local ProceduralAnimation = {}

export type Keyframe = {
	Time: number,
	Joints: { [string]: CFrame }, -- joint name → local transform offset
}

export type Clip = {
	Id: string,
	Duration: number,
	Priority: number, -- higher wins
	Loop: boolean,
	Keys: { Keyframe },
}

local active: { [Model]: { ClipId: string, Start: number, Clip: Clip, Weight: number } } = {}

-- Joint names common on R15
local JOINTS = {
	"Root", "Waist", "Neck",
	"LeftShoulder", "RightShoulder",
	"LeftElbow", "RightElbow",
	"LeftWrist", "RightWrist",
	"LeftHip", "RightHip",
	"LeftKnee", "RightKnee",
	"LeftAnkle", "RightAnkle",
}

local function findMotor(character: Model, name: string): Motor6D?
	for _, d in character:GetDescendants() do
		if d:IsA("Motor6D") and (d.Name == name or d.Name:find(name)) then
			return d
		end
	end
	-- Alternate: search by Part1 name
	for _, d in character:GetDescendants() do
		if d:IsA("Motor6D") and d.Part1 and d.Part1.Name:find(name) then
			return d
		end
	end
	return nil
end

local function lerpCF(a: CFrame, b: CFrame, t: number): CFrame
	return a:Lerp(b, t)
end

local function sampleClip(clip: Clip, t: number): { [string]: CFrame }
	if #clip.Keys == 0 then return {} end
	local time = clip.Loop and (t % clip.Duration) or math.clamp(t, 0, clip.Duration)
	local prev = clip.Keys[1]
	local nextK = clip.Keys[#clip.Keys]
	for i = 1, #clip.Keys - 1 do
		if time >= clip.Keys[i].Time and time <= clip.Keys[i + 1].Time then
			prev = clip.Keys[i]
			nextK = clip.Keys[i + 1]
			break
		end
	end
	local span = math.max(0.001, nextK.Time - prev.Time)
	local alpha = (time - prev.Time) / span
	local out = {}
	local jointSet = {}
	for j in pairs(prev.Joints) do jointSet[j] = true end
	for j in pairs(nextK.Joints) do jointSet[j] = true end
	for j in pairs(jointSet) do
		local a = prev.Joints[j] or CFrame.new()
		local b = nextK.Joints[j] or CFrame.new()
		out[j] = lerpCF(a, b, alpha)
	end
	return out
end

----------------------------------------------------------------
-- Clip library (readable combat poses)
----------------------------------------------------------------
local function rot(x: number, y: number, z: number): CFrame
	return CFrame.Angles(math.rad(x), math.rad(y), math.rad(z))
end

ProceduralAnimation.Clips = {
	Idle = {
		Id = "Idle", Duration = 2, Priority = 1, Loop = true,
		Keys = {
			{ Time = 0, Joints = { Waist = rot(0, 0, 0), RightShoulder = rot(0, 0, 8), LeftShoulder = rot(0, 0, -8) } },
			{ Time = 1, Joints = { Waist = rot(2, 0, 0), RightShoulder = rot(0, 0, 12), LeftShoulder = rot(0, 0, -12) } },
			{ Time = 2, Joints = { Waist = rot(0, 0, 0), RightShoulder = rot(0, 0, 8), LeftShoulder = rot(0, 0, -8) } },
		},
	},
	CombatIdle = {
		Id = "CombatIdle", Duration = 1.6, Priority = 2, Loop = true,
		Keys = {
			{ Time = 0, Joints = {
				Waist = rot(0, 15, 0),
				RightShoulder = rot(-40, 20, 20),
				LeftShoulder = rot(-25, -30, -15),
				RightElbow = rot(-50, 0, 0),
			} },
			{ Time = 0.8, Joints = {
				Waist = rot(0, 18, 0),
				RightShoulder = rot(-42, 22, 22),
				LeftShoulder = rot(-28, -32, -18),
				RightElbow = rot(-55, 0, 0),
			} },
			{ Time = 1.6, Joints = {
				Waist = rot(0, 15, 0),
				RightShoulder = rot(-40, 20, 20),
				LeftShoulder = rot(-25, -30, -15),
				RightElbow = rot(-50, 0, 0),
			} },
		},
	},
	Light1 = {
		Id = "Light1", Duration = 0.45, Priority = 10, Loop = false,
		Keys = {
			{ Time = 0, Joints = { RightShoulder = rot(-30, 20, 10), RightElbow = rot(-40, 0, 0), Waist = rot(0, 10, 0) } },
			{ Time = 0.12, Joints = { RightShoulder = rot(-80, 40, 30), RightElbow = rot(-20, 0, 0), Waist = rot(0, 25, 0) } },
			{ Time = 0.28, Joints = { RightShoulder = rot(-20, -40, -10), RightElbow = rot(-10, 0, 0), Waist = rot(0, -15, 0) } },
			{ Time = 0.45, Joints = { RightShoulder = rot(-35, 10, 10), RightElbow = rot(-40, 0, 0), Waist = rot(0, 5, 0) } },
		},
	},
	Light2 = {
		Id = "Light2", Duration = 0.48, Priority = 10, Loop = false,
		Keys = {
			{ Time = 0, Joints = { LeftShoulder = rot(-20, -20, -10), RightShoulder = rot(-30, 10, 10), Waist = rot(0, -10, 0) } },
			{ Time = 0.15, Joints = { LeftShoulder = rot(-70, -40, -20), Waist = rot(0, -30, 0) } },
			{ Time = 0.32, Joints = { LeftShoulder = rot(-10, 30, 20), Waist = rot(0, 20, 0) } },
			{ Time = 0.48, Joints = { LeftShoulder = rot(-25, -15, -10), Waist = rot(0, 0, 0) } },
		},
	},
	Light3 = {
		Id = "Light3", Duration = 0.55, Priority = 10, Loop = false,
		Keys = {
			{ Time = 0, Joints = { RightShoulder = rot(-90, 0, 20), RightElbow = rot(-90, 0, 0), Waist = rot(-5, 0, 0) } },
			{ Time = 0.18, Joints = { RightShoulder = rot(-100, 30, 40), RightElbow = rot(-30, 0, 0), Waist = rot(5, 25, 0) } },
			{ Time = 0.35, Joints = { RightShoulder = rot(10, -50, -20), RightElbow = rot(-5, 0, 0), Waist = rot(10, -20, 0) } },
			{ Time = 0.55, Joints = { RightShoulder = rot(-40, 15, 15), RightElbow = rot(-45, 0, 0), Waist = rot(0, 0, 0) } },
		},
	},
	Heavy = {
		Id = "Heavy", Duration = 0.85, Priority = 12, Loop = false,
		Keys = {
			{ Time = 0, Joints = { RightShoulder = rot(-20, 20, 10), Waist = rot(0, 20, 0) } },
			{ Time = 0.25, Joints = { RightShoulder = rot(-120, 40, 50), RightElbow = rot(-20, 0, 0), Waist = rot(-10, 30, 0) } },
			{ Time = 0.45, Joints = { RightShoulder = rot(-130, 45, 55), Waist = rot(-12, 35, 0) } },
			{ Time = 0.6, Joints = { RightShoulder = rot(20, -60, -30), RightElbow = rot(0, 0, 0), Waist = rot(15, -25, 0) } },
			{ Time = 0.85, Joints = { RightShoulder = rot(-35, 10, 10), Waist = rot(0, 0, 0) } },
		},
	},
	Dodge = {
		Id = "Dodge", Duration = 0.35, Priority = 15, Loop = false,
		Keys = {
			{ Time = 0, Joints = { Waist = rot(0, 0, 0), LeftHip = rot(0, 0, 0), RightHip = rot(0, 0, 0) } },
			{ Time = 0.1, Joints = { Waist = rot(20, 0, 15), LeftHip = rot(-40, 0, 0), RightHip = rot(20, 0, 0) } },
			{ Time = 0.22, Joints = { Waist = rot(5, 0, -10), LeftHip = rot(10, 0, 0), RightHip = rot(-30, 0, 0) } },
			{ Time = 0.35, Joints = { Waist = rot(0, 0, 0), LeftHip = rot(0, 0, 0), RightHip = rot(0, 0, 0) } },
		},
	},
	Block = {
		Id = "Block", Duration = 0.4, Priority = 8, Loop = true,
		Keys = {
			{ Time = 0, Joints = {
				LeftShoulder = rot(-70, -40, -30),
				LeftElbow = rot(-80, 0, 0),
				RightShoulder = rot(-50, 30, 20),
				Waist = rot(0, -15, 0),
			} },
			{ Time = 0.4, Joints = {
				LeftShoulder = rot(-72, -42, -32),
				LeftElbow = rot(-82, 0, 0),
				RightShoulder = rot(-52, 32, 22),
				Waist = rot(0, -15, 0),
			} },
		},
	},
	Cast = {
		Id = "Cast", Duration = 0.7, Priority = 11, Loop = false,
		Keys = {
			{ Time = 0, Joints = { RightShoulder = rot(-20, 10, 10), LeftShoulder = rot(-15, -10, -10) } },
			{ Time = 0.25, Joints = { RightShoulder = rot(-100, 0, 30), LeftShoulder = rot(-60, 0, -20), Waist = rot(-5, 0, 0) } },
			{ Time = 0.45, Joints = { RightShoulder = rot(-110, 0, 40), LeftShoulder = rot(-70, 0, -25) } },
			{ Time = 0.7, Joints = { RightShoulder = rot(-30, 15, 10), LeftShoulder = rot(-20, -10, -10), Waist = rot(0, 0, 0) } },
		},
	},
	Hit = {
		Id = "Hit", Duration = 0.3, Priority = 14, Loop = false,
		Keys = {
			{ Time = 0, Joints = { Waist = rot(0, 0, 0) } },
			{ Time = 0.08, Joints = { Waist = rot(-15, 0, 10), Neck = rot(-10, 0, 5) } },
			{ Time = 0.3, Joints = { Waist = rot(0, 0, 0), Neck = rot(0, 0, 0) } },
		},
	},
	Death = {
		Id = "Death", Duration = 1.0, Priority = 20, Loop = false,
		Keys = {
			{ Time = 0, Joints = { Waist = rot(0, 0, 0) } },
			{ Time = 0.4, Joints = { Waist = rot(40, 20, 0), Neck = rot(30, 0, 0), RightShoulder = rot(40, 0, 30), LeftShoulder = rot(40, 0, -30) } },
			{ Time = 1.0, Joints = { Waist = rot(70, 0, 0), Neck = rot(40, 0, 0) } },
		},
	},
} :: { [string]: Clip }

function ProceduralAnimation.Play(character: Model, clipId: string)
	local clip = ProceduralAnimation.Clips[clipId]
	if not clip then return end
	local cur = active[character]
	if cur and cur.Clip.Priority > clip.Priority and (os.clock() - cur.Start) < cur.Clip.Duration then
		return -- don't interrupt higher priority
	end
	active[character] = {
		ClipId = clipId,
		Start = os.clock(),
		Clip = clip,
		Weight = 1,
	}
end

function ProceduralAnimation.Stop(character: Model)
	active[character] = nil
	-- Reset motors toward identity
	for _, name in JOINTS do
		local m = findMotor(character, name)
		if m then
			m.Transform = CFrame.new()
		end
	end
end

function ProceduralAnimation.Update(character: Model)
	local state = active[character]
	if not state then return end
	local elapsed = os.clock() - state.Start
	if not state.Clip.Loop and elapsed >= state.Clip.Duration then
		active[character] = nil
		for _, name in JOINTS do
			local m = findMotor(character, name)
			if m then m.Transform = CFrame.new() end
		end
		return
	end
	local poses = sampleClip(state.Clip, elapsed)
	for joint, cf in pairs(poses) do
		local m = findMotor(character, joint)
		if m then
			m.Transform = cf
		end
	end
end

function ProceduralAnimation.UpdateAll()
	for character in pairs(active) do
		if character.Parent then
			ProceduralAnimation.Update(character)
		else
			active[character] = nil
		end
	end
end

return ProceduralAnimation
