local Character = script.Parent
local Humanoid = Character:WaitForChild("Humanoid")
local pose = "Standing"

local function getRigScale()
	return Character:GetScale()
end

local AnimationSpeedDampeningObject = script:FindFirstChild("ScaleDampeningPercent")
local HumanoidHipHeight = 2

local FFlagUserAnimateRemoveEmoteChatHook
do
	local success, result = pcall(function()
		return UserSettings():IsUserFeatureEnabled("UserAnimateRemoveEmoteChatHook")
	end)
	FFlagUserAnimateRemoveEmoteChatHook = success and result
end

local EMOTE_TRANSITION_TIME = 0.1

local currentAnim = ""
local currentAnimInstance = nil
local currentAnimTrack = nil
local currentAnimKeyframeHandler = nil
local currentAnimSpeed = 1.0

local runAnimTrack = nil
local runAnimKeyframeHandler = nil

local PreloadedAnims = {}

local animTable = {}
local animNames = {
	idle =     {
		{ id = "http://www.roblox.com/asset/?id=507766666", weight = 1 },
		{ id = "http://www.roblox.com/asset/?id=507766951", weight = 1 },
		{ id = "http://www.roblox.com/asset/?id=507766388", weight = 9 }
	},
	walk =     {
		{ id = "http://www.roblox.com/asset/?id=73071221777791", weight = 10 }
	},
	run =     {
		{ id = "http://www.roblox.com/asset/?id=108504428656492", weight = 10 }
	},
	swim =     {
		{ id = "http://www.roblox.com/asset/?id=507784897", weight = 10 }
	},
	swimidle =     {
		{ id = "http://www.roblox.com/asset/?id=507785072", weight = 10 }
	},
	jump =     {
		{ id = "http://www.roblox.com/asset/?id=507765000", weight = 10 }
	},
	fall =     {
		{ id = "http://www.roblox.com/asset/?id=507767968", weight = 10 }
	},
	climb = {
		{ id = "http://www.roblox.com/asset/?id=507765644", weight = 10 }
	},
	sit =     {
		{ id = "http://www.roblox.com/asset/?id=2506281703", weight = 10 }
	},
	toolnone = {
		{ id = "http://www.roblox.com/asset/?id=507768375", weight = 10 }
	},
	toolslash = {
		{ id = "http://www.roblox.com/asset/?id=522635514", weight = 10 }
	},
	toollunge = {
		{ id = "http://www.roblox.com/asset/?id=522638767", weight = 10 }
	},
	wave = {
		{ id = "http://www.roblox.com/asset/?id=507770239", weight = 10 }
	},
	point = {
		{ id = "http://www.roblox.com/asset/?id=507770453", weight = 10 }
	},
	dance = {
		{ id = "http://www.roblox.com/asset/?id=507771019", weight = 10 },
		{ id = "http://www.roblox.com/asset/?id=507771955", weight = 10 },
		{ id = "http://www.roblox.com/asset/?id=507772104", weight = 10 }
	},
	dance2 = {
		{ id = "http://www.roblox.com/asset/?id=507776043", weight = 10 },
		{ id = "http://www.roblox.com/asset/?id=507776720", weight = 10 },
		{ id = "http://www.roblox.com/asset/?id=507776879", weight = 10 }
	},
	dance3 = {
		{ id = "http://www.roblox.com/asset/?id=507777268", weight = 10 },
		{ id = "http://www.roblox.com/asset/?id=507777451", weight = 10 },
		{ id = "http://www.roblox.com/asset/?id=507777623", weight = 10 }
	},
	laugh = {
		{ id = "http://www.roblox.com/asset/?id=507770818", weight = 10 }
	},
	cheer = {
		{ id = "http://www.roblox.com/asset/?id=507770677", weight = 10 }
	},
	-- ==================================================================
	-- 🔫 انميشنات السلاح (Weapon Animations)
	-- ==================================================================
	pistolHold = {
		{ id = "rbxassetid://89299192160513", weight = 10 }
	},
	pistolShoot = {
		{ id = "rbxassetid://97670980389357", weight = 10 }
	},
	pistolReload = {
		{ id = "rbxassetid://124051684058836", weight = 10 }
	},
	rifleHold = {
		{ id = "rbxassetid://120367139740949", weight = 10 }
	},
	rifleShoot = {
		{ id = "rbxassetid://86365425323397", weight = 10 }
	},
	rifleReload = {
		{ id = "rbxassetid://99720679547147", weight = 10 }
	},
	automaticSave = {
		{ id = "rbxassetid://99808373661425", weight = 10 }
	},
}

-- Existance in this list signifies that it is an emote, the value indicates if it is a looping emote
local emoteNames = { wave = false, point = false, dance = true, dance2 = true, dance3 = true, laugh = false, cheer = false}

-- Variables used in tracking if the character is using a ControllerManager.
local groundSensorChangedListener:RBXScriptSignal? = nil
local managerRootChangedListener:RBXScriptSignal? = nil
local managerParentChangedListener:RBXScriptSignal? = nil
local charGroundSensor:ControllerPartSensor? = nil
local charControllerManager:ControllerManager? = nil

local CCLAnimationFixed
do
	local success, result = pcall(function()
		return UserSettings():IsUserFeatureEnabled("UserAnimationAbilityManagerFixed")
	end)
	CCLAnimationFixed = success and result
end

-- Clean up listeners associated with the character's ControllerManager
function resetManagerListeners()
	if groundSensorChangedListener then
		groundSensorChangedListener:Disconnect()
		groundSensorChangedListener = nil
	end
	if managerRootChangedListener then
		managerRootChangedListener:Disconnect()
		managerRootChangedListener = nil
	end
	if managerParentChangedListener then
		managerParentChangedListener:Disconnect()
		managerParentChangedListener = nil
	end
end

-- Clean up all listeners and reset state.
function teardownManager()
	resetManagerListeners()
	charGroundSensor = nil
	charControllerManager = nil
end

-- Returns true if checkManager controls the character associated with this script
function processIfManagerBelongsToCharacter(checkManager:ControllerManager):boolean
	if checkManager.RootPart == Character.PrimaryPart then
		if charControllerManager ~= checkManager then
			resetManagerListeners()
			charGroundSensor = checkManager.GroundSensor
			groundSensorChangedListener = checkManager:GetPropertyChangedSignal("GroundSensor"):Connect(function()
				if processIfManagerBelongsToCharacter(checkManager) then
					groundSensorChangedListener:Disconnect()
					groundSensorChangedListener = nil
				end
			end)
			managerRootChangedListener = checkManager:GetPropertyChangedSignal("RootPart"):Connect(function()
				if processIfManagerBelongsToCharacter(checkManager) then
					managerRootChangedListener:Disconnect()
					managerRootChangedListener = nil
				end
			end)
			managerParentChangedListener = checkManager.AncestryChanged:Connect(function(_, parent)
				if parent == nil then
					resetManagerListeners()
					lookForControllerManager()
				end
			end)
			charControllerManager = checkManager
		end
		return true
	end
	return false
end

-- Attach to a confirmed-valid manager
function setupManager(manager:ControllerManager)
	charControllerManager = manager
	charGroundSensor = manager.GroundSensor

	groundSensorChangedListener = manager:GetPropertyChangedSignal("GroundSensor"):Connect(function()
		charGroundSensor = charControllerManager.GroundSensor
	end)

	managerRootChangedListener = manager:GetPropertyChangedSignal("RootPart"):Connect(function()
		if manager.RootPart ~= Character.PrimaryPart then
			teardownManager()
			lookForControllerManager()
		end
	end)

	managerParentChangedListener = manager.AncestryChanged:Connect(function(_, parent)
		if parent == nil then
			teardownManager()
			lookForControllerManager()
		end
	end)
end

-- Looks for the first ControllerManager directly childed to the character
function lookForControllerManager()
	if CCLAnimationFixed then
		local child:ControllerManager? = Character:FindFirstChildOfClass("ControllerManager")
		if child then
			if child.RootPart == Character.PrimaryPart then
				setupManager(child)
			else
				local rootPartListener:RBXScriptSignal
				rootPartListener = child:GetPropertyChangedSignal("RootPart"):Connect(function()
					if child.RootPart == Character.PrimaryPart then
						rootPartListener:Disconnect()
						setupManager(child)
					end
				end)
			end
		else
			local managerAddedListener:RBXScriptSignal
			managerAddedListener = Character.ChildAdded:Connect(function(newChild)
				if newChild:IsA("ControllerManager") then
					managerAddedListener:Disconnect()
					lookForControllerManager()
				end
			end)
		end
	else
		charGroundSensor = nil
		charControllerManager = nil

		local child:ControllerManager? = Character:FindFirstChildOfClass("ControllerManager")
		if child then
			processIfManagerBelongsToCharacter(child)
		end
		if charControllerManager == nil then
			local managerAddedListener:RBXScriptSignal
			managerAddedListener = Character.ChildAdded:Connect(function(child)
				if child:IsA("ControllerManager") then
					if processIfManagerBelongsToCharacter(child) then
						managerAddedListener:Disconnect()
						managerAddedListener = nil
					end
				end
			end)
		end
	end
end
lookForControllerManager()

math.randomseed(tick())

function findExistingAnimationInSet(set, anim)
	if set == nil or anim == nil then
		return 0
	end

	for idx = 1, set.count, 1 do
		if set[idx].anim.AnimationId == anim.AnimationId then
			return idx
		end
	end

	return 0
end

function configureAnimationSet(name, fileList)
	if (animTable[name] ~= nil) then
		for _, connection in pairs(animTable[name].connections) do
			connection:disconnect()
		end
	end
	animTable[name] = {}
	animTable[name].count = 0
	animTable[name].totalWeight = 0
	animTable[name].connections = {}

	local allowCustomAnimations = true

	local success, msg = pcall(function() allowCustomAnimations = game:GetService("StarterPlayer").AllowCustomAnimations end)
	if not success then
		allowCustomAnimations = true
	end

	-- check for config values
	local config = script:FindFirstChild(name)
	if (allowCustomAnimations and config ~= nil) then
		table.insert(animTable[name].connections, config.ChildAdded:connect(function(child) configureAnimationSet(name, fileList) end))
		table.insert(animTable[name].connections, config.ChildRemoved:connect(function(child) configureAnimationSet(name, fileList) end))

		local idx = 0
		for _, childPart in pairs(config:GetChildren()) do
			if (childPart:IsA("Animation")) then
				local newWeight = 1
				local weightObject = childPart:FindFirstChild("Weight")
				if (weightObject ~= nil) then
					newWeight = weightObject.Value
				end
				animTable[name].count = animTable[name].count + 1
				idx = animTable[name].count
				animTable[name][idx] = {}
				animTable[name][idx].anim = childPart
				animTable[name][idx].weight = newWeight
				animTable[name].totalWeight = animTable[name].totalWeight + animTable[name][idx].weight
				table.insert(animTable[name].connections, childPart.Changed:connect(function(property) configureAnimationSet(name, fileList) end))
				table.insert(animTable[name].connections, childPart.ChildAdded:connect(function(property) configureAnimationSet(name, fileList) end))
				table.insert(animTable[name].connections, childPart.ChildRemoved:connect(function(property) configureAnimationSet(name, fileList) end))
			end
		end
	end

	-- fallback to defaults
	if (animTable[name].count <= 0) then
		for idx, anim in pairs(fileList) do
			animTable[name][idx] = {}
			animTable[name][idx].anim = Instance.new("Animation")
			animTable[name][idx].anim.Name = name
			animTable[name][idx].anim.AnimationId = anim.id
			animTable[name][idx].weight = anim.weight
			animTable[name].count = animTable[name].count + 1
			animTable[name].totalWeight = animTable[name].totalWeight + anim.weight
		end
	end

	-- preload anims
	for i, animType in pairs(animTable) do
		for idx = 1, animType.count, 1 do
			if PreloadedAnims[animType[idx].anim.AnimationId] == nil then
				Humanoid:LoadAnimation(animType[idx].anim)
				PreloadedAnims[animType[idx].anim.AnimationId] = true
			end
		end
	end
end

function configureAnimationSetOld(name, fileList)
	if (animTable[name] ~= nil) then
		for _, connection in pairs(animTable[name].connections) do
			connection:disconnect()
		end
	end
	animTable[name] = {}
	animTable[name].count = 0
	animTable[name].totalWeight = 0
	animTable[name].connections = {}

	local allowCustomAnimations = true

	local success, msg = pcall(function() allowCustomAnimations = game:GetService("StarterPlayer").AllowCustomAnimations end)
	if not success then
		allowCustomAnimations = true
	end

	-- check for config values
	local config = script:FindFirstChild(name)
	if (allowCustomAnimations and config ~= nil) then
		table.insert(animTable[name].connections, config.ChildAdded:connect(function(child) configureAnimationSet(name, fileList) end))
		table.insert(animTable[name].connections, config.ChildRemoved:connect(function(child) configureAnimationSet(name, fileList) end))
		local idx = 1
		for _, childPart in pairs(config:GetChildren()) do
			if (childPart:IsA("Animation")) then
				table.insert(animTable[name].connections, childPart.Changed:connect(function(property) configureAnimationSet(name, fileList) end))
				animTable[name][idx] = {}
				animTable[name][idx].anim = childPart
				local weightObject = childPart:FindFirstChild("Weight")
				if (weightObject == nil) then
					animTable[name][idx].weight = 1
				else
					animTable[name][idx].weight = weightObject.Value
				end
				animTable[name].count = animTable[name].count + 1
				animTable[name].totalWeight = animTable[name].totalWeight + animTable[name][idx].weight
				idx = idx + 1
			end
		end
	end

	-- fallback to defaults
	if (animTable[name].count <= 0) then
		for idx, anim in pairs(fileList) do
			animTable[name][idx] = {}
			animTable[name][idx].anim = Instance.new("Animation")
			animTable[name][idx].anim.Name = name
			animTable[name][idx].anim.AnimationId = anim.id
			animTable[name][idx].weight = anim.weight
			animTable[name].count = animTable[name].count + 1
			animTable[name].totalWeight = animTable[name].totalWeight + anim.weight
		end
	end

	-- preload anims
	for i, animType in pairs(animTable) do
		for idx = 1, animType.count, 1 do
			Humanoid:LoadAnimation(animType[idx].anim)
		end
	end
end

-- Setup animation objects
function scriptChildModified(child)
	local fileList = animNames[child.Name]
	if (fileList ~= nil) then
		configureAnimationSet(child.Name, fileList)
	end
end

script.ChildAdded:connect(scriptChildModified)
script.ChildRemoved:connect(scriptChildModified)

-- Clear any existing animation tracks
local animator = if Humanoid then Humanoid:FindFirstChildOfClass("Animator") else nil
if animator then
	local animTracks = animator:GetPlayingAnimationTracks()
	for i,track in ipairs(animTracks) do
		track:Stop(0)
		track:Destroy()
	end
end

for name, fileList in pairs(animNames) do
	configureAnimationSet(name, fileList)
end

-- ==================================================================
-- 1️⃣ الجري (Sprint) عبر زر Shift + سرعة انميشن المشي/الجري
-- ==================================================================
local UserInputService = game:GetService("UserInputService")

local isSprinting = false
local WALK_ANIM_SPEED_MULTIPLIER = 1.0
local RUN_ANIM_SPEED_MULTIPLIER  = 0.8
local WALK_RUN_BLEND_FADE_TIME = 0.25
local SPRINT_WALKSPEED_MULTIPLIER = 1.6
local CROUCH_WALKSPEED_MULTIPLIER = 0.5
local NORMAL_WALKSPEED = 10
Humanoid.WalkSpeed = NORMAL_WALKSPEED

local JUMP_HEIGHT_MULTIPLIER = 0.6
if Humanoid.UseJumpPower then
	Humanoid.JumpPower = Humanoid.JumpPower * JUMP_HEIGHT_MULTIPLIER
else
	Humanoid.JumpHeight = Humanoid.JumpHeight * JUMP_HEIGHT_MULTIPLIER
end

local baseWalkSpeed = Humanoid.WalkSpeed
local isCrouching = false

Humanoid:GetPropertyChangedSignal("WalkSpeed"):Connect(function()
	if not isSprinting and not isCrouching then
		baseWalkSpeed = Humanoid.WalkSpeed
	end
end)

local function updateMovementSpeed()
	if isCrouching then
		Humanoid.WalkSpeed = baseWalkSpeed * CROUCH_WALKSPEED_MULTIPLIER
	elseif isSprinting then
		Humanoid.WalkSpeed = baseWalkSpeed * SPRINT_WALKSPEED_MULTIPLIER
	else
		Humanoid.WalkSpeed = baseWalkSpeed
	end
end

local walkSound = Instance.new("Sound")
walkSound.Name = "WalkSound"
walkSound.SoundId = "rbxassetid://4416041299"
walkSound.Looped = true
walkSound.Volume = 1
walkSound.PlaybackSpeed = 1
walkSound.Parent = Character:WaitForChild("HumanoidRootPart")

local WALK_SOUND_NORMAL_SPEED = 1
local WALK_SOUND_RUN_SPEED = 1.6

local hrp = Character:WaitForChild("HumanoidRootPart")

local DEFAULT_SOUND_NAMES = {
	Running = true,
	Climbing = true,
	Splash = true,
	Swimming = true,
	GettingUp = true,
	FreeFalling = true,
	Jumping = true,
	Landing = true,
}

local function muteIfDefaultSound(child)
	if child:IsA("Sound") and child ~= walkSound and DEFAULT_SOUND_NAMES[child.Name] then
		child.Volume = 0
	end
end

for _, child in ipairs(hrp:GetChildren()) do
	muteIfDefaultSound(child)
end

hrp.ChildAdded:Connect(muteIfDefaultSound)

local function updateWalkSound()
	local isMoving = (pose == "Running")

	if isMoving then
		walkSound.PlaybackSpeed = isSprinting and WALK_SOUND_RUN_SPEED or WALK_SOUND_NORMAL_SPEED
		if not walkSound.IsPlaying then
			walkSound:Play()
		end
	else
		if walkSound.IsPlaying then
			walkSound:Stop()
		end
	end
end

local function setSprinting(sprintOn)
	if isCrouching then
		return
	end
	if isSprinting == sprintOn then
		return
	end
	isSprinting = sprintOn
	updateMovementSpeed()
	updateWalkSound()
end

UserInputService.InputBegan:Connect(function(input, gameProcessedEvent)
	if gameProcessedEvent then return end
	if input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.RightShift then
		setSprinting(true)
	end
end)

UserInputService.InputEnded:Connect(function(input, gameProcessedEvent)
	if input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.RightShift then
		setSprinting(false)
	end
end)

-- ==================================================================
-- 2️⃣ الكراوش (Crouch) عبر زر Ctrl
-- ==================================================================

local crouchIdleAnim = Instance.new("Animation")
crouchIdleAnim.Name = "crouchidle"
crouchIdleAnim.AnimationId = "rbxassetid://94277814492381"

local crouchWalkAnim = Instance.new("Animation")
crouchWalkAnim.Name = "crouchwalk"
crouchWalkAnim.AnimationId = "rbxassetid://92329278290188"

Humanoid:LoadAnimation(crouchIdleAnim)
Humanoid:LoadAnimation(crouchWalkAnim)

local crouchIdleSet = { count = 1, totalWeight = 10, connections = {}, [1] = { anim = crouchIdleAnim, weight = 10 } }
local crouchWalkSet = { count = 1, totalWeight = 10, connections = {}, [1] = { anim = crouchWalkAnim, weight = 10 } }

local originalIdleSet = animTable["idle"]
local originalWalkSet = animTable["walk"]

local function setCrouching(crouchOn)
	if isCrouching == crouchOn then
		return
	end
	isCrouching = crouchOn

	if isCrouching then
		if isSprinting then
			isSprinting = false
		end
		animTable["idle"] = crouchIdleSet
		animTable["walk"] = crouchWalkSet
	else
		animTable["idle"] = originalIdleSet
		animTable["walk"] = originalWalkSet
	end

	updateMovementSpeed()
	updateWalkSound()

	if pose == "Standing" then
		playAnimation("idle", 0.2, Humanoid)
	elseif pose == "Running" then
		playAnimation("walk", 0.2, Humanoid)
	end
end

UserInputService.InputBegan:Connect(function(input, gameProcessedEvent)
	if gameProcessedEvent then return end
	if input.KeyCode == Enum.KeyCode.LeftControl or input.KeyCode == Enum.KeyCode.RightControl then
		setCrouching(not isCrouching)
	end
end)

-- ==================================================================
-- 3️⃣ ضربة اليد (Punch) عبر زر F مع cooldown 3 ثواني
-- ⚠️ لا تعمل في الكراوش
-- ==================================================================

local punchAnim = Instance.new("Animation")
punchAnim.Name = "punch"
punchAnim.AnimationId = "rbxassetid://72277313295368"

local punchTrack = Humanoid:LoadAnimation(punchAnim)
punchTrack.Priority = Enum.AnimationPriority.Action
punchTrack.Looped = false

local punchSound = Instance.new("Sound")
punchSound.Name = "PunchSound"
punchSound.SoundId = "rbxassetid://132176641904643"
punchSound.Volume = 1
punchSound.Parent = hrp

local isPunching = false
local PUNCH_COOLDOWN = 3

punchTrack.Stopped:Connect(function()
	isPunching = false
end)

local function playPunch()
	if isCrouching then
		return
	end

	if isPunching then
		return
	end
	isPunching = true
	punchTrack:Play()
	punchSound:Play()

	task.wait(PUNCH_COOLDOWN)
	isPunching = false
end

UserInputService.InputBegan:Connect(function(input, gameProcessedEvent)
	if gameProcessedEvent then return end
	if input.KeyCode == Enum.KeyCode.F then
		playPunch()
	end
end)

-- ==================================================================
-- 🔫 نظام السلاح (Weapon System)
-- ==================================================================

local currentWeapon = nil
local currentWeaponTrack = nil
local isWeaponEquipped = false

local weaponSounds = {
	pistolShoot = Instance.new("Sound"),
	rifleShoot = Instance.new("Sound"),
	reload = Instance.new("Sound"),
}

for soundName, sound in pairs(weaponSounds) do
	sound.Name = soundName
	sound.Volume = 1
	sound.Parent = hrp
end

local function playWeaponAnimation(animName)
	if not animTable[animName] then
		return
	end

	if currentWeaponTrack then
		currentWeaponTrack:Stop(0.1)
		currentWeaponTrack:Destroy()
	end

	local idx = 1
	if animTable[animName].count > 0 then
		idx = math.random(1, animTable[animName].count)
	else
		return
	end

	local anim = animTable[animName][idx].anim
	currentWeaponTrack = Humanoid:LoadAnimation(anim)
	currentWeaponTrack.Priority = Enum.AnimationPriority.Action
	currentWeaponTrack:Play(0.1)

	return currentWeaponTrack
end

local function equipWeapon(weaponType)
	if currentWeapon == weaponType then
		return
	end

	currentWeapon = weaponType
	isWeaponEquipped = true

	if weaponType == "pistol" then
		playWeaponAnimation("pistolHold")
	elseif weaponType == "rifle" then
		playWeaponAnimation("rifleHold")
	end
end

local function unequipWeapon()
	if currentWeaponTrack then
		currentWeaponTrack:Stop(0.2)
		currentWeaponTrack:Destroy()
		currentWeaponTrack = nil
	end
	currentWeapon = nil
	isWeaponEquipped = false
end

local function shootWeapon()
	if not isWeaponEquipped then
		return
	end

	if currentWeapon == "pistol" then
		playWeaponAnimation("pistolShoot")
		weaponSounds.pistolShoot:Play()
	elseif currentWeapon == "rifle" then
		playWeaponAnimation("rifleShoot")
		weaponSounds.rifleShoot:Play()
	end
end

local function reloadWeapon()
	if not isWeaponEquipped then
		return
	end

	if currentWeapon == "pistol" then
		playWeaponAnimation("pistolReload")
	elseif currentWeapon == "rifle" then
		playWeaponAnimation("rifleReload")
	end

	weaponSounds.reload:Play()
end

-- تحكم أسلحة من لوحة المفاتيح
UserInputService.InputBegan:Connect(function(input, gameProcessedEvent)
	if gameProcessedEvent then return end

	if input.KeyCode == Enum.KeyCode.One then
		equipWeapon("pistol")
	elseif input.KeyCode == Enum.KeyCode.Two then
		equipWeapon("rifle")
	elseif input.KeyCode == Enum.KeyCode.Three then
		unequipWeapon()
	elseif input.KeyCode == Enum.KeyCode.R then
		reloadWeapon()
	elseif input.KeyCode == Enum.KeyCode.Mouse1 or input.KeyCode == Enum.KeyCode.E then
		shootWeapon()
	end
end)

-- ==================================================================
-- ANIMATION SYSTEM
-- ==================================================================

local toolAnim = "None"
local toolAnimTime = 0

local jumpAnimTime = 0
local jumpAnimDuration = 0.31

local toolTransitionTime = 0.1
local fallTransitionTime = 0.2

local currentlyPlayingEmote = false

function stopAllAnimations()
	local oldAnim = currentAnim

	if (emoteNames[oldAnim] ~= nil and emoteNames[oldAnim] == false) then
		oldAnim = "idle"
	end

	if currentlyPlayingEmote then
		oldAnim = "idle"
		currentlyPlayingEmote = false
	end

	currentAnim = ""
	currentAnimInstance = nil
	if (currentAnimKeyframeHandler ~= nil) then
		currentAnimKeyframeHandler:disconnect()
	end

	if (currentAnimTrack ~= nil) then
		currentAnimTrack:Stop()
		currentAnimTrack:Destroy()
		currentAnimTrack = nil
	end

	if (runAnimKeyframeHandler ~= nil) then
		runAnimKeyframeHandler:disconnect()
	end

	if (runAnimTrack ~= nil) then
		runAnimTrack:Stop()
		runAnimTrack:Destroy()
		runAnimTrack = nil
	end

	return oldAnim
end

function getHeightScale()
	if Humanoid then
		if not Humanoid.AutomaticScalingEnabled then
			return getRigScale()
		end

		local scale = Humanoid.HipHeight / HumanoidHipHeight
		if AnimationSpeedDampeningObject == nil then
			AnimationSpeedDampeningObject = script:FindFirstChild("ScaleDampeningPercent")
		end
		if AnimationSpeedDampeningObject ~= nil then
			scale = 1 + (Humanoid.HipHeight - HumanoidHipHeight) * AnimationSpeedDampeningObject.Value / HumanoidHipHeight
		end
		return scale
	end
	return getRigScale()
end

local function rootMotionCompensation(speed)
	local speedScaled = speed * 1.25
	local heightScale = getHeightScale()
	local runSpeed = speedScaled / heightScale
	return runSpeed
end

local smallButNotZero = 0.0001
local function setRunSpeed(speed)
	local normalizedWalkSpeed = 0.5
	local normalizedRunSpeed  = 1
	local runSpeed = rootMotionCompensation(speed)

	local walkAnimationWeight = smallButNotZero
	local runAnimationWeight = smallButNotZero
	local timeWarp = 1

	if not isSprinting then
		walkAnimationWeight = 1
		runAnimationWeight = smallButNotZero
		timeWarp = (runSpeed / normalizedWalkSpeed) * WALK_ANIM_SPEED_MULTIPLIER
	else
		walkAnimationWeight = smallButNotZero
		runAnimationWeight = 1
		timeWarp = (runSpeed / normalizedRunSpeed) * RUN_ANIM_SPEED_MULTIPLIER
	end

	currentAnimTrack:AdjustWeight(walkAnimationWeight, WALK_RUN_BLEND_FADE_TIME)
	runAnimTrack:AdjustWeight(runAnimationWeight, WALK_RUN_BLEND_FADE_TIME)
	currentAnimTrack:AdjustSpeed(timeWarp)
	runAnimTrack:AdjustSpeed(timeWarp)
end

function setAnimationSpeed(speed)
	if currentAnim == "walk" then
		setRunSpeed(speed)
	else
		if speed ~= currentAnimSpeed then
			currentAnimSpeed = speed
			currentAnimTrack:AdjustSpeed(currentAnimSpeed)
		end
	end
end

function keyFrameReachedFunc(frameName)
	if (frameName == "End") then
		if currentAnim == "walk" then
			if runAnimTrack.Looped ~= true then
				runAnimTrack.TimePosition = 0.0
			end
			if currentAnimTrack.Looped ~= true then
				currentAnimTrack.TimePosition = 0.0
			end
		else
			local repeatAnim = currentAnim
			if (emoteNames[repeatAnim] ~= nil and emoteNames[repeatAnim] == false) then
				repeatAnim = "idle"
			end

			if currentlyPlayingEmote then
				if currentAnimTrack.Looped then
					return
				end

				repeatAnim = "idle"
				currentlyPlayingEmote = false
			end

			local animSpeed = currentAnimSpeed
			playAnimation(repeatAnim, 0.15, Humanoid)
			setAnimationSpeed(animSpeed)
		end
	end
end

function rollAnimation(animName)
	local roll = math.random(1, animTable[animName].totalWeight)
	local origRoll = roll
	local idx = 1
	while (roll > animTable[animName][idx].weight) do
		roll = roll - animTable[animName][idx].weight
		idx = idx + 1
	end
	return idx
end

local function switchToAnim(anim, animName, transitionTime, humanoid)
	if (anim ~= currentAnimInstance) then

		if (currentAnimTrack ~= nil) then
			currentAnimTrack:Stop(transitionTime)
			currentAnimTrack:Destroy()
		end

		if (runAnimTrack ~= nil) then
			runAnimTrack:Stop(transitionTime)
			runAnimTrack:Destroy()
			runAnimTrack = nil
		end

		currentAnimSpeed = 1.0

		currentAnimTrack = humanoid:LoadAnimation(anim)
		currentAnimTrack.Priority = Enum.AnimationPriority.Core

		currentAnimTrack:Play(transitionTime)
		currentAnim = animName
		currentAnimInstance = anim

		if (currentAnimKeyframeHandler ~= nil) then
			currentAnimKeyframeHandler:disconnect()
		end
		currentAnimKeyframeHandler = currentAnimTrack.KeyframeReached:connect(keyFrameReachedFunc)

		if animName == "walk" then
			local runAnimName = "run"
			local runIdx = rollAnimation(runAnimName)

			runAnimTrack = humanoid:LoadAnimation(animTable[runAnimName][runIdx].anim)
			runAnimTrack.Priority = Enum.AnimationPriority.Core
			runAnimTrack:Play(transitionTime)

			if (runAnimKeyframeHandler ~= nil) then
				runAnimKeyframeHandler:disconnect()
			end
			runAnimKeyframeHandler = runAnimTrack.KeyframeReached:connect(keyFrameReachedFunc)
		end
	end
end

function playAnimation(animName, transitionTime, humanoid)
	local idx = rollAnimation(animName)
	local anim = animTable[animName][idx].anim

	switchToAnim(anim, animName, transitionTime, humanoid)
	currentlyPlayingEmote = false
end

function playEmote(emoteAnim, transitionTime, humanoid)
	switchToAnim(emoteAnim, emoteAnim.Name, transitionTime, humanoid)
	currentlyPlayingEmote = true
end

-------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------

local toolAnimName = ""
local toolAnimTrack = nil
local toolAnimInstance = nil
local currentToolAnimKeyframeHandler = nil

function toolKeyFrameReachedFunc(frameName)
	if (frameName == "End") then
		playToolAnimation(toolAnimName, 0.0, Humanoid)
	end
end


function playToolAnimation(animName, transitionTime, humanoid, priority)
	local idx = rollAnimation(animName)
	local anim = animTable[animName][idx].anim

	if (toolAnimInstance ~= anim) then

		if (toolAnimTrack ~= nil) then
			toolAnimTrack:Stop()
			toolAnimTrack:Destroy()
			transitionTime = 0
		end

		toolAnimTrack = humanoid:LoadAnimation(anim)
		if priority then
			toolAnimTrack.Priority = priority
		end

		toolAnimTrack:Play(transitionTime)
		toolAnimName = animName
		toolAnimInstance = anim

		currentToolAnimKeyframeHandler = toolAnimTrack.KeyframeReached:connect(toolKeyFrameReachedFunc)
	end
end

function stopToolAnimations()
	local oldAnim = toolAnimName

	if (currentToolAnimKeyframeHandler ~= nil) then
		currentToolAnimKeyframeHandler:disconnect()
	end

	toolAnimName = ""
	toolAnimInstance = nil
	if (toolAnimTrack ~= nil) then
		toolAnimTrack:Stop()
		toolAnimTrack:Destroy()
		toolAnimTrack = nil
	end

	return oldAnim
end

-------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------
-- STATE CHANGE HANDLERS

function onRunning(speed)
	local heightScale = getHeightScale()

	if charGroundSensor ~= nil and Humanoid.EvaluateStateMachine == false then
		local hrp = Humanoid.RootPart
		local sensedPart = charGroundSensor.SensedPart
		if sensedPart then
			local pos = charGroundSensor.HitFrame.Position
			local floorVel = sensedPart:GetVelocityAtPosition(pos)
			local assemblyVel = hrp.AssemblyLinearVelocity
			local relVel = Vector3.new(assemblyVel.X - floorVel.X, 0, assemblyVel.Z - floorVel.Z)
			local relSpeed = relVel.Magnitude
			local moveMag = charControllerManager.MovingDirection.Magnitude
			if moveMag < 0.1 then
				relSpeed = 0
				moveMag = 0
			elseif moveMag > 1.0 then
				moveMag = 1.0
			end
			speed = relSpeed * moveMag
		end
	end

	local movedDuringEmote = currentlyPlayingEmote and Humanoid.MoveDirection == Vector3.new(0, 0, 0)
	local speedThreshold = movedDuringEmote and (Humanoid.WalkSpeed / heightScale) or 0.75
	if speed > speedThreshold * heightScale then
		local scale = 16.0
		playAnimation("walk", 0.2, Humanoid)
		setAnimationSpeed(speed / scale)
		pose = "Running"
	else
		if emoteNames[currentAnim] == nil and not currentlyPlayingEmote then
			playAnimation("idle", 0.2, Humanoid)
			pose = "Standing"
		end
	end
	updateWalkSound()
end

function onDied()
	pose = "Dead"
end

function onJumping()
	playAnimation("jump", 0.1, Humanoid)
	jumpAnimTime = jumpAnimDuration
	pose = "Jumping"
end

function onClimbing(speed)
	speed /= getHeightScale()
	local scale = 5.0
	playAnimation("climb", 0.1, Humanoid)
	setAnimationSpeed(speed / scale)
	pose = "Climbing"
end

function onGettingUp()
	pose = "GettingUp"
end

function onFreeFall()
	if (jumpAnimTime <= 0) then
		playAnimation("fall", fallTransitionTime, Humanoid)
	end
	pose = "FreeFall"
end

function onFallingDown()
	pose = "FallingDown"
end

function onSeated()
	pose = "Seated"
end

function onPlatformStanding()
	pose = "PlatformStanding"
end

-------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------

function onSwimming(speed)
	speed /= getHeightScale()
	if speed > 1.00 then
		local scale = 10.0
		playAnimation("swim", 0.4, Humanoid)
		setAnimationSpeed(speed / scale)
		pose = "Swimming"
	else
		playAnimation("swimidle", 0.4, Humanoid)
		pose = "Standing"
	end
end

function animateTool()
	if (toolAnim == "None") then
		playToolAnimation("toolnone", toolTransitionTime, Humanoid, Enum.AnimationPriority.Idle)
		return
	end

	if (toolAnim == "Slash") then
		playToolAnimation("toolslash", 0, Humanoid, Enum.AnimationPriority.Action)
		return
	end

	if (toolAnim == "Lunge") then
		playToolAnimation("toollunge", 0, Humanoid, Enum.AnimationPriority.Action)
		return
	end
end

function getToolAnim(tool)
	for _, c in ipairs(tool:GetChildren()) do
		if c.Name == "toolanim" and c.className == "StringValue" then
			return c
		end
	end
	return nil
end

local lastTick = 0

function stepAnimate(currentTime)
	local amplitude = 1
	local frequency = 1
	local deltaTime = currentTime - lastTick
	lastTick = currentTime

	local climbFudge = 0
	local setAngles = false

	updateWalkSound()

	if (jumpAnimTime > 0) then
		jumpAnimTime = jumpAnimTime - deltaTime
	end

	if (pose == "FreeFall" and jumpAnimTime <= 0) then
		playAnimation("fall", fallTransitionTime, Humanoid)
	elseif (pose == "Seated") then
		playAnimation("sit", 0.5, Humanoid)
		return
	elseif (pose == "Running") then
		playAnimation("walk", 0.2, Humanoid)
	elseif (pose == "Dead" or pose == "GettingUp" or pose == "FallingDown" or pose == "Seated" or pose == "PlatformStanding") then
		stopAllAnimations()
		amplitude = 0.1
		frequency = 1
		setAngles = true
	end

	-- Tool Animation handling
	local tool = Character:FindFirstChildOfClass("Tool")
	if tool and tool:FindFirstChild("Handle") then
		local animStringValueObject = getToolAnim(tool)

		if animStringValueObject then
			toolAnim = animStringValueObject.Value
			animStringValueObject.Parent = nil
			toolAnimTime = currentTime + .3
		end

		if currentTime > toolAnimTime then
			toolAnimTime = 0
			toolAnim = "None"
		end

		animateTool()
	else
		stopToolAnimations()
		toolAnim = "None"
		toolAnimInstance = nil
		toolAnimTime = 0
	end
end

-- connect events
Humanoid.Died:connect(onDied)
Humanoid.Running:connect(onRunning)
Humanoid.Jumping:connect(onJumping)
Humanoid.Climbing:connect(onClimbing)
Humanoid.GettingUp:connect(onGettingUp)
Humanoid.FreeFalling:connect(onFreeFall)
Humanoid.FallingDown:connect(onFallingDown)
Humanoid.Seated:connect(onSeated)
Humanoid.PlatformStanding:connect(onPlatformStanding)
Humanoid.Swimming:connect(onSwimming)

if not FFlagUserAnimateRemoveEmoteChatHook then
	-- setup emote chat hook
	game:GetService("Players").LocalPlayer.Chatted:connect(function(msg)
		local emote = ""
		if (string.sub(msg, 1, 3) == "/e ") then
			emote = string.sub(msg, 4)
		elseif (string.sub(msg, 1, 7) == "/emote ") then
			emote = string.sub(msg, 8)
		end

		if (pose == "Standing" and emoteNames[emote] ~= nil) then
			playAnimation(emote, EMOTE_TRANSITION_TIME, Humanoid)
		end
	end)
end

-- emote bindable hook
script:WaitForChild("PlayEmote").OnInvoke = function(emote)
	-- Only play emotes when idling
	if pose ~= "Standing" then
		return
	end

	if emoteNames[emote] ~= nil then
		-- Default emotes
		playAnimation(emote, EMOTE_TRANSITION_TIME, Humanoid)

		return true, currentAnimTrack
	elseif typeof(emote) == "Instance" and emote:IsA("Animation") then
		-- Non-default emotes
		playEmote(emote, EMOTE_TRANSITION_TIME, Humanoid)

		return true, currentAnimTrack
	end

	-- Return false to indicate that the emote could not be played
	return false
end

if Character.Parent ~= nil then
	-- initialize to idle
	playAnimation("idle", 0.1, Humanoid)
	pose = "Standing"
end

-- loop to handle timed state transitions and tool animations
while Character.Parent ~= nil do
	local _, currentGameTime = wait(0.1)
	stepAnimate(currentGameTime)
end
