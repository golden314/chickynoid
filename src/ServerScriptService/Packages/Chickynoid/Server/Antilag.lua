--!native
local function lerp(a, b, t)
	return a + (b - a) * t
end

local module = {}
module.history = {}
module.temporaryPositions = {}

local path = game.ReplicatedFirst.Packages.Chickynoid
local Keyframes = require(path.Shared.Simulation.Keyframes).new()
local Animations = require(path.Shared.Simulation.Animations)
local Enums = require(path.Shared.Enums)

local animStates = {
	{
		"animCounter0",
		"animNum0",
	},
	{
		"animCounter1",
		"animNum1",
	},
	{
		"animCounter2",
		"animNum2",
	},
	{
		"animCounter2",
		"animNum3",
	}
}

function module:Setup(server)
    module.server = server

   local Rig = path.Assets.R15Rig
   local Animator = Rig.Humanoid.Animator
	
   for _, name in pairs(Animations.animations) do
      if Animator:FindFirstChild(name) then
         local animation = Animator[name]
         Keyframes:InsertAnimations(name, animation) --TODO: Parent the animation's keyframes to the animation (Temporary fix)
         --Keyframes:InsertAnimations(name, animation:FindFirstChildWhichIsA("KeyframeSequence")
      end
   end
end

function module:WritePlayerPositions(serverTime)
    local players = self.server:GetPlayers()

    local snapshot = {}
    snapshot.serverTime = serverTime
    snapshot.players = {}
    for _, playerRecord in pairs(players) do
        if playerRecord.chickynoid then
            local characterData = playerRecord.chickynoid.simulation.characterData
            
            local record = {}
            record.position = characterData:GetPosition() --get current visual position
            record.angle = characterData.serialized.angle
            record.animations = {
                animCounter0 = characterData.serialized.animCounter0,
		animNum0 = characterData.serialized.animNum0,
		animCounter1 = characterData.serialized.animCounter1,
		animNum1 = characterData.serialized.animNum1,
		animCounter2 = characterData.serialized.animCounter2,
		animNum2 = characterData.serialized.animNum2,
		animCounter3 = characterData.serialized.animCounter3,
		animNum3 = characterData.serialized.animNum3,
            }
            snapshot.players[playerRecord.userId] = record
        end
    end

    table.insert(self.history, snapshot)

    for counter = #self.history, 1, -1 do
        local oldSnapshot = self.history[counter]

        --only keep 1s of history
        if oldSnapshot.serverTime < serverTime - 1 then
            table.remove(self.history, counter)
        end
    end
end

function module:PushPlayerPositionsToTime(playerRecord, serverTime, debugText)
    local players = self.server:GetPlayers()

    if #self.temporaryPositions > 0 then
        warn("POP not called after a PushPlayerPositionsToTime")
    end

    --find the two records
    local prevRecord = nil
    local nextRecord = nil
    for counter = #self.history - 1, 1, -1 do
        if self.history[counter].serverTime < serverTime then
            prevRecord = self.history[counter]
            nextRecord = self.history[counter + 1]
            break
        end
    end

    if prevRecord == nil then
        warn("Could not find antilag time for ", serverTime)
        return
    end

    local frac = ((serverTime - prevRecord.serverTime) / (nextRecord.serverTime - prevRecord.serverTime))
    local debugFlag = self.server.flags.DEBUG_ANTILAG
    if debugFlag == true then
        print(
            "Prev time ",
            prevRecord.serverTime,
            " Next Time ",
            nextRecord.serverTime,
            " des time ",
            serverTime,
            " frac ",
            frac
        )
    end

    self.temporaryPositions = {}
    for userId, prevPlayerRecord in pairs(prevRecord.players) do
        if userId == playerRecord.userId then
            continue --Dont move us
        end

        local nextPlayerRecord = nextRecord.players[userId]
        if nextPlayerRecord == nil then
            continue
        end

        local otherPlayerRecord = players[userId]
        if otherPlayerRecord == nil then
            continue
        end

        if otherPlayerRecord.chickynoid == nil then
            continue
        end
        if otherPlayerRecord.chickynoid.hitBox then
            local oldPos = otherPlayerRecord.chickynoid.hitBox.Position
            self.temporaryPositions[userId] = oldPos --Store it

            local pos = prevPlayerRecord.position:Lerp(nextPlayerRecord.position, frac)
            local angle = lerp(prevPlayerRecord.angle, nextPlayerRecord.angle, frac)
            

            --place it just how it was when the server saw it
            otherPlayerRecord.chickynoid.hitBox.Position = pos
            otherPlayerRecord.chickynoid.hitBox.Rig:PivotTo(CFrame.new(pos) * CFrame.fromEulerAnglesXYZ(0, angle, 0))

            for _, state in pairs(animStates) do
                local counter = prevPlayerRecord.animations[state[1]]
		local num = prevPlayerRecord.animations[state[2]]

                local name = Animations:GetAnimation(num)

		if name then
			local channel = tonumber(string.sub(state[2], 8, 9))
					
			local totalTime = lerp(prevPlayerRecord.animTime[channel], nextPlayerRecord.animTime[channel], frac)
			local max = Keyframes.Animations[name].max
					
			Keyframes:SetTime(name, totalTime%max)
			Keyframes:SetWeight(name, 1)
		end
            end

            Keyframes:ApplyToRig(otherPlayerRecord.chickynoid.hitBox.Rig)

		Keyframes:ApplyToRig(otherPlayerRecord.chickynoid.hitBox.Rig)
			
		for _, name in pairs(Animations.animations) do
			if name == "Stop" then
				continue
			end
			Keyframes:SetWeight(name, 0.01)
		end
			
            if debugFlag == true then
                local event = {}
                event.t = Enums.EventType.DebugBox
                event.pos = pos
                event.text = debugText
                playerRecord:SendEventToClient(event)
            end
        end
    end
end

function module:Pop()
    local players = self.server:GetPlayers()

    for userId, pos in pairs(self.temporaryPositions) do
        local playerRecord = players[userId]

        if playerRecord and playerRecord.chickynoid then
            if playerRecord.chickynoid.hitBox then
                playerRecord.chickynoid.hitBox.Position = pos
            end
        end
    end

    self.temporaryPositions = {}
end

return module
