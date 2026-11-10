--!strict
--[[
	AnimationPlayer — per-rig keyframe animation engine driving Motor6D.Transform.

	Layers (evaluated every Step):
	  1. Base      — looping locomotion clips, cross-faded (SetBase), cycle speed adjustable.
	  2. Actions   — one-shot or looping clips sorted by Priority; each fades in/out and only
	                 overrides joints it owns (natural masking: an upper-body attack leaves legs
	                 to locomotion).
	  3. Additive  — clips multiplied on top (breathing, recoil, flinch).
	  4. Procedural— AnimSet.Procedural(ctx, poses, dt, now) post-process (tails, wings, look-at).

	Motor6D.Transform is not replicated, so every client runs an AnimationPlayer for each rig
	it can see (AnimationController). The server only broadcasts which clip starts when.
]]

local Anim = require(script.Parent.Anim)
local AnimationLibrary = require(script.Parent.AnimationLibrary)

type Clip = Anim.Clip
type Pose = Anim.Pose

export type PlayOptions = {
	Speed: number?,
	Duration: number?, -- scale the clip so it lasts exactly this long
	FadeIn: number?,
	FadeOut: number?,
	Hold: boolean?, -- stay on the last frame until stopped (death, knockdown)
	Looped: boolean?,
	Priority: number?,
	StartTime: number?, -- seconds already elapsed (late join / latency compensation)
	Weight: number?,
	OnMarker: ((name: string) -> ())?,
	OnEnd: (() -> ())?,
}

export type Track = {
	Clip: Clip,
	Time: number,
	Speed: number,
	Weight: number,
	TargetWeight: number,
	FadeIn: number,
	FadeOut: number,
	Hold: boolean,
	Looped: boolean,
	Priority: number,
	Stopping: boolean,
	OnMarker: ((string) -> ())?,
	OnEnd: (() -> ())?,
	Ended: boolean,
}

type BaseTrack = { Clip: Clip, Time: number, Weight: number, Target: number, Speed: number }

export type AnimationPlayer = {
	Model: Model,
	SetName: string,
	Motors: { [string]: Motor6D },
	Context: { [string]: any },
	SetAnimSet: (self: AnimationPlayer, setName: string) -> (),
	GetClip: (self: AnimationPlayer, name: string) -> Clip?,
	SetBase: (self: AnimationPlayer, clipName: string, fade: number?, speed: number?) -> (),
	SetBaseSpeed: (self: AnimationPlayer, speed: number) -> (),
	Play: (self: AnimationPlayer, clipName: string, options: PlayOptions?) -> Track?,
	Stop: (self: AnimationPlayer, clipName: string?, fade: number?) -> (),
	IsPlaying: (self: AnimationPlayer, clipName: string) -> boolean,
	Step: (self: AnimationPlayer, dt: number, now: number) -> (),
	Refresh: (self: AnimationPlayer) -> (),
	Destroy: (self: AnimationPlayer) -> (),
}

local IDENTITY = CFrame.new()

local AnimationPlayer = {}
AnimationPlayer.__index = AnimationPlayer

local function collectMotors(model: Model): { [string]: Motor6D }
	local motors: { [string]: Motor6D } = {}
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("Motor6D") and not motors[descendant.Name] then
			motors[descendant.Name] = descendant
		end
	end
	return motors
end

function AnimationPlayer.new(model: Model, setName: string): AnimationPlayer
	local self = setmetatable({
		Model = model,
		SetName = setName,
		Motors = collectMotors(model),
		Context = { Model = model },
		_base = {} :: { BaseTrack },
		_baseName = "",
		_baseSpeed = 1,
		_actions = {} :: { Track },
		_pose = {} :: Pose,
		_scratch = {} :: Pose,
	}, AnimationPlayer)
	return (self :: any) :: AnimationPlayer
end

function AnimationPlayer:SetAnimSet(setName: string)
	self.SetName = setName
end

function AnimationPlayer:Refresh()
	self.Motors = collectMotors(self.Model)
end

function AnimationPlayer:GetClip(name: string): Clip?
	return AnimationLibrary.GetClip(self.SetName, name)
end

function AnimationPlayer:SetBase(clipName: string, fade: number?, speed: number?)
	if self._baseName == clipName then
		if speed then
			self._baseSpeed = speed
		end
		return
	end
	local clip = self:GetClip(clipName)
	if not clip then
		return
	end
	self._baseName = clipName
	self._baseSpeed = speed or 1
	local fadeTime = fade or 0.2
	for _, track in self._base do
		track.Target = 0
		track.Speed = if fadeTime > 0 then 1 / fadeTime else math.huge
	end
	-- phase-match walk/run cycles so feet do not pop between gaits
	local phase = 0
	local current: BaseTrack? = self._base[#self._base]
	if current and current.Clip.Length > 0 then
		phase = (current.Time % current.Clip.Length) / current.Clip.Length
	end
	table.insert(self._base, {
		Clip = clip,
		Time = phase * clip.Length,
		Weight = if #self._base == 0 then 1 else 0,
		Target = 1,
		Speed = if fadeTime > 0 then 1 / fadeTime else math.huge,
	})
end

function AnimationPlayer:SetBaseSpeed(speed: number)
	self._baseSpeed = speed
end

function AnimationPlayer:Play(clipName: string, options: PlayOptions?): Track?
	local clip = self:GetClip(clipName)
	if not clip then
		return nil
	end
	local opts: PlayOptions = options or {}
	local speed = opts.Speed or 1
	if opts.Duration and opts.Duration > 0 and clip.Length > 0 then
		speed = clip.Length / opts.Duration
	end
	-- restarting the same clip replaces the old track
	for _, track in self._actions do
		if track.Clip == clip and not track.Stopping then
			track.Stopping = true
			track.TargetWeight = 0
			track.FadeOut = 0.05
		end
	end
	local track: Track = {
		Clip = clip,
		Time = (opts.StartTime or 0) * speed,
		Speed = speed,
		Weight = 0,
		TargetWeight = opts.Weight or clip.Weight,
		FadeIn = opts.FadeIn or clip.FadeIn,
		FadeOut = opts.FadeOut or clip.FadeOut,
		Hold = opts.Hold == true,
		Looped = if opts.Looped ~= nil then opts.Looped else clip.Looped,
		Priority = opts.Priority or clip.Priority,
		Stopping = false,
		OnMarker = opts.OnMarker,
		OnEnd = opts.OnEnd,
		Ended = false,
	}
	table.insert(self._actions, track)
	table.sort(self._actions, function(a, b)
		return a.Priority < b.Priority
	end)
	return track
end

function AnimationPlayer:Stop(clipName: string?, fade: number?)
	for _, track in self._actions do
		if clipName == nil or track.Clip.Name == clipName then
			track.Stopping = true
			track.TargetWeight = 0
			if fade then
				track.FadeOut = fade
			end
		end
	end
end

function AnimationPlayer:IsPlaying(clipName: string): boolean
	for _, track in self._actions do
		if track.Clip.Name == clipName and not track.Stopping then
			return true
		end
	end
	return false
end

local function approach(current: number, target: number, rate: number, dt: number): number
	if current < target then
		return math.min(target, current + rate * dt)
	end
	return math.max(target, current - rate * dt)
end

function AnimationPlayer:Step(dt: number, now: number)
	local pose: Pose = self._pose
	local scratch: Pose = self._scratch
	table.clear(pose)

	-- 1. base layer (normalised blend)
	local base: { BaseTrack } = self._base
	local accumulated = 0
	for index = #base, 1, -1 do
		local track = base[index]
		track.Weight = approach(track.Weight, track.Target, track.Speed, dt)
		if track.Weight <= 0 and track.Target <= 0 then
			table.remove(base, index)
		end
	end
	for _, track in base do
		track.Time += dt * (self._baseSpeed :: number)
		if track.Weight <= 0 then
			continue
		end
		table.clear(scratch)
		Anim.Sample(track.Clip, track.Time, scratch)
		accumulated += track.Weight
		local alpha = track.Weight / accumulated
		for joint, cf in scratch do
			local existing = pose[joint]
			pose[joint] = if existing then existing:Lerp(cf, alpha) else IDENTITY:Lerp(cf, alpha * accumulated)
		end
	end

	-- 2/3. action + additive layers
	local actions: { Track } = self._actions
	for index = #actions, 1, -1 do
		local track = actions[index]
		local clip = track.Clip
		local previous = track.Time
		track.Time += dt * track.Speed
		-- markers
		if track.OnMarker then
			for name, at in clip.Markers do
				if previous < at and track.Time >= at then
					task.spawn(track.OnMarker, name)
				end
			end
		end
		-- weight
		if track.Stopping then
			local rate = if track.FadeOut > 0 then 1 / track.FadeOut else math.huge
			track.Weight = approach(track.Weight, 0, rate, dt)
		else
			local rate = if track.FadeIn > 0 then 1 / track.FadeIn else math.huge
			track.Weight = approach(track.Weight, track.TargetWeight, rate, dt)
			if not track.Looped and not track.Hold and track.Time >= clip.Length - track.FadeOut * track.Speed then
				track.Stopping = true
			end
		end
		if track.Stopping and track.Weight <= 0 then
			table.remove(actions, index)
			if not track.Ended then
				track.Ended = true
				if track.OnEnd then
					task.spawn(track.OnEnd)
				end
			end
		end
	end
	for _, track in actions do
		if track.Weight <= 0 then
			continue
		end
		table.clear(scratch)
		local sampleTime = if track.Hold then math.min(track.Time, track.Clip.Length) else track.Time
		Anim.Sample(track.Clip, sampleTime, scratch)
		local weight = math.clamp(track.Weight, 0, 1)
		if track.Clip.Additive then
			for joint, cf in scratch do
				local existing = pose[joint] or CFrame.identity
				pose[joint] = existing * IDENTITY:Lerp(cf, weight)
			end
		else
			for joint, cf in scratch do
				local existing = pose[joint] or CFrame.identity
				pose[joint] = existing:Lerp(cf, weight)
			end
		end
	end

	-- 4. procedural
	local procedural = AnimationLibrary.GetField(self.SetName, "Procedural")
	if type(procedural) == "function" then
		local ok, err = pcall(procedural, self.Context, pose, dt, now)
		if not ok then
			warn(`[AnimationPlayer] procedural error ({self.SetName}): {err}`)
		end
	end

	-- write
	for name, motor in self.Motors do
		local cf = pose[name]
		motor.Transform = cf or CFrame.identity
	end
end

function AnimationPlayer:Destroy()
	for _, motor in self.Motors do
		if motor.Parent then
			motor.Transform = CFrame.identity
		end
	end
	table.clear(self._actions)
	table.clear(self._base)
end

return AnimationPlayer
