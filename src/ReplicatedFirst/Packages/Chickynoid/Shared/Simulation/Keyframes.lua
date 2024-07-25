local Provider = game:GetService("KeyframeSequenceProvider")

local function convert(sequence: KeyframeSequence)
	if sequence:IsA("Animation") then
		local success, err = pcall(function()
			sequence = Provider:GetKeyframeSequenceAsync(sequence.AnimationId)
		end)
		
		if err then
			error(err)
		end
	end
	
	local frames = {}
	
	local max = 0 --Assume all animation's minimum keyframe time is 0
	
	for _, keyframe: Keyframe in pairs(sequence:GetKeyframes()) do
		local currentKeyframe = {}
		
		for _, pose: Pose in pairs(keyframe:GetDescendants()) do
			if not pose:IsA("Pose") then
				continue
			end
			
			table.insert(currentKeyframe, {
				limb = pose.Name,
				cf = pose.CFrame,
				easingDirection = pose.EasingDirection,
				easingStyle = pose.EasingStyle,
			})
		end
			
		frames[keyframe.Time] = currentKeyframe
		max = math.max(max, keyframe.Time)
	end
	
	return frames, max
end

local function percentDiff(a,b)
	local absDiff = math.abs(a - b)
	local avg = (a + b)/2

	return (absDiff / avg) * 100
end

local function isClose(a, b)
	return (100 - percentDiff(a, b))/100
end

local originalMotorOffsets = { --Only takes in roblox rig motors currently. (C1 Motors)
	["HumanoidRootPart"] = CFrame.new(0, 0, 0, -1, 0, 0, 0, 0, 1, 0, 1, -0),
	
	["Head"] = CFrame.new(0, -0.491300106, -0.000263773836, 1, 0, 0, 0, 1, 0, 0, 0, 1),
	--["Head"] = CFrame.new(0, -0.5, 0, -1, 0, 0, 0, 0, 1, 0, 1, 0), --Comment this in, if you are using a R6 rig
	
	--R6
	["Left Arm"] = CFrame.new(0.5, 0.5, 0, 0, 0, -1, 0, 1, 0, 1, 0, 0),
	["Left Leg"] = CFrame.new(-0.5, 1, 0, 0, 0, -1, 0, 1, 0, 1, 0, 0),
	["Right Arm"] = CFrame.new(-0.5, 0.5, 0, 0, 0, 1, 0, 1, 0, -1, 0, 0),
	["Right Leg"] = CFrame.new(0.5, 1, 0, 0, 0, 1, 0, 1, 0, -1, 0, 0),
	["Torso"] = CFrame.new(0, 0, 0, -1, 0, 0, 0, 0, 1, 0, 1, 0),

	--R15
	["RightFoot"] = CFrame.new(0, 0.106015317, 7.65293444e-05, 1, 0, 0, 0, 1, 0, 0, 0, 1),
	["RightHand"] = CFrame.new(3.52001166e-07, 0.131572768, 6.12894695e-08, 1, 0, 0, 0, 1, 0, 0, 0, 1),
	["RightLowerArm"] = CFrame.new(1.19336448e-07, 0.274708718, 7.65889566e-20, 1, 0, 0, 0, 1, 0, 0, 0, 1),
	["RightLowerLeg"] = CFrame.new(0, 0.413358927, 2.48585493e-05, 1, 0, 0, 0, 1, 0, 0, 0, 1),
	["RightUpperArm"] = CFrame.new(-0.500534058, 0.418923318, 8.95738594e-08, 1, 0, 0, 0, 1, 0, 0, 0, 1),
	["RightUpperLeg"] = CFrame.new(0, 0.471393555, -6.49150097e-05, 1, 0, 0, 0, 1, 0, 0, 0, 1),
	["LeftFoot"] = CFrame.new(-1.80400747e-07, 0.106015436, -1.72411478e-06, 1, 0, 0, 0, 1, 0, 0, 0, 1),
	["LeftHand"] = CFrame.new(0.000471446925, 0.131572768, 6.12894695e-08, 1, 0, 0, 0, 1, 0, 0, 0, 1),
	["LeftLowerArm"] = CFrame.new(0.000479135837, 0.274824202, 7.65889566e-20, 1, 0, 0, 0, 1, 0, 0, 0, 1),
	["LeftLowerLeg"] = CFrame.new(2.95890423e-08, 0.413189024, -1.56485186e-07, 1, 0, 0, 0, 1, 0, 0, 0, 1),
	["LeftUpperArm"] = CFrame.new(0.5005337, 0.418923318, 8.95738594e-08, 1, 0, 0, 0, 1, 0, 0, 0, 1),
	["LeftUpperLeg"] = CFrame.new(5.91780847e-08, 0.471393436, -1.59454345e-07, 1, 0, 0, 0, 1, 0, 0, 0, 1),
	["LowerTorso"] = CFrame.new(-1.1920929e-07, -0.199972257, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1),
	["UpperTorso"] = CFrame.new(-5.79121036e-08, -0.849000454, 1.19686121e-07, 1, 0, 0, 0, 1, 0, 0, 0, 1),
}

local module = {}
module.__index = module

function module.new()
	local Animator = setmetatable(module, {})	
	Animator.Animations = {}
	
	return Animator
end

function module:InsertAnimations(name: string, keyframeSequence: KeyframeSequence) --Preload all animations before use
	local record = {}
	record.name = name
	record.time = 0
	record.weight = 1
	
	local anim, max = convert(keyframeSequence)
	
	record.animation = anim
	record.max = max
	
	self.Animations[name] = record
end

function module:SetTime(name, time)
	if not self.Animations[name] then
		warn(name, "does not exist in the animation table!")
		return
	end
	
	local record = self.Animations[name]
	record.time = math.clamp(time, 0, record.max)
end

function module:SetWeight(name, weight)
	if not self.Animations[name] then
		warn(name, "does not exist in the animation table!")
		return
	end
	
	self.Animations[name].weight = weight
end


function module:ApplyToRig(rig: Model)
	--Apply to C1 of motor6ds, I think
	local finalPose = {}
	
	for _, record in pairs(self.Animations) do
		local keyframe = record.animation[record.time]
		

    		if keyframe then
			for _, pose in pairs(keyframe) do
				if not finalPose[pose.limb] then
					finalPose[pose.limb] = originalMotorOffsets[pose.limb]
				end
				
				local cf = originalMotorOffsets[pose.limb] * pose.cf:Inverse()
				
				finalPose[pose.limb] = finalPose[pose.limb]:Lerp(cf, record.weight)
				
			end

			continue
		end
		
		--TODO: Interpolate between keyframes, this doesnt actually interpolate yet
		--Current system cant interpolate limbs that are not in the current keyframes
			
		local minIndex = 0
		local maxIndex = record.max
			
		for t, value in pairs(record.animation) do
			if t <= record.time and t >= minIndex then
				minIndex = t
			end
			if t >= record.time and t <= maxIndex then
				maxIndex = t
			end
		end
		
		local minKeyframe = record.animation[minIndex]
		local maxKeyframe = record.animation[maxIndex]
		
		for _, pose in pairs(maxKeyframe) do
			if not finalPose[pose.limb] then
				finalPose[pose.limb] = originalMotorOffsets[pose.limb]
			end

			local cf = originalMotorOffsets[pose.limb] * pose.cf:Inverse()

			finalPose[pose.limb] = finalPose[pose.limb]:Lerp(cf, record.weight)
		end

		--[[
		--This interpolation is broken, and I have no idea how to fix it
		
		local lerpedCfs = {}
		
		for frame, keyframe in pairs(record.animation) do
			for _, pose in pairs(keyframe) do
				if not lerpedCfs[pose.limb] then
					lerpedCfs[pose.limb] = originalMotorOffsets[pose.limb]
				end

				local cf = originalMotorOffsets[pose.limb] * pose.cf:Inverse()

				lerpedCfs[pose.limb] = lerpedCfs[pose.limb]:Lerp(cf, isClose(frame, record.time))
			end
		end
		
		for limb, cf in pairs(lerpedCfs) do
			if not finalPose[limb] then
				finalPose[limb] = originalMotorOffsets[limb]
			end
			
			finalPose[limb] = finalPose[limb]:Lerp(cf, record.weight)
		end]]
	end
	
	--Now apply to rig
	for _, motor6d: Motor6D in pairs(rig:GetDescendants()) do
		if not motor6d:IsA("Motor6D") then
			continue
		elseif not finalPose[motor6d.Part1.Name] then
			continue
		end
		
		motor6d.C1 = finalPose[motor6d.Part1.Name]
	end
end

return module
