--!strict

local Modules = script:WaitForChild("Modules")

local Helper = require(Modules.Helper)
local Signal = require(Modules.Signal)
local Custom = require(Modules.Custom)
local settings = require(Modules.settings)

-------------------------------------------------------------------------------------------------
-- SyncImpl is the Metamethods for the SyncTween class.
type SyncImpl = {
	__index: SyncImpl,

	-- // Methods
	new: (
		object: Instance, tweenInfo: (TweenInfo | Helper.TweenArray | string)?,
		properties: { [string]: any }?, players: { Player }?,
		replicate: boolean?, sync: (boolean | number)?, uuid: string?, start: number?,
		delta: number?, original: { [string]: any }?
	) -> Sync,

	get: (object: Instance, player: Player) -> { Sync },
	fps: (freq: number) -> (),

	Play: (self: Sync) -> (),
	Pause: (self: Sync) -> (),
	Cancel: (self: Sync, original: { [string]: any }?) -> (),
}

-- self is the SyncTween class.
type self = {
	-- Variables:
	sync: (boolean | number)?, -- Default: False
	object: Instance,
	replicate: boolean?, -- Default: True
	players: { Player }?, -- Default: Players:GetPlayers()
	UUID: string,
	tween: (TweenInfo | Helper.TweenArray | string)?,

	-- Time:
	start: number?,
	delta: number,

	-- Properties:
	original: { [string]: any },
	properties: { [string]: any }?,

	-- Signals:
	Played: Signal.RBXScriptSignal,
	Paused: Signal.RBXScriptSignal,
	Canceled: Signal.RBXScriptSignal,
	Completed: Signal.RBXScriptSignal,

	-- Workers:
	waiter: thread?,
	connection: RBXScriptConnection?,
	temporary: any?,
	animation: Tween?,
}

-- Sync is the SyncTween class, including the Metamethods.
export type Sync = typeof(
	setmetatable({} :: self, {} :: SyncImpl)
)

-- ControllerImpl is the Metamethods of the Controller class.
type ControllerImpl = {
	__newindex: (array: { [string]: Sync? }, index: string, value: Sync?, reset: boolean?) -> (),
}

-- Controller is a list of Syncs that have the ControllerImpl Metamethods.
type Controller = typeof(
	setmetatable({} :: { [string]: Sync? }, {} :: ControllerImpl)
)

-- Controls is the type that each Controllers will have.
-- "amount" is the amount of Syncs playing. "data" is the Syncs.
type Controls = {
	amount: number;
	data: Controller;
}
-------------------------------------------------------------------------------------------------

local SyncTween: SyncImpl = {} :: SyncImpl
SyncTween.__index = SyncTween

-------------------------------------------------------------------------------------------------

--[[

@creaco - October 30th 2024
(GNU GPLv3 License)

Welcome to SyncTween!
This is a tweening library that is designed to help with Server to Client animations.

This module supports a couple of things other modules don't:
    1- Syncing (synchronized on all clients) animations from the server to the client.
		-> The difference in this module is that "Synchronizing" isn't making all the Tweens end at the same time.
		-> This is default behavior in this module, all tweens will end at the same time.
		-> Synchronizing means that each client sees the same, some Tweens may start at a different position than the start.
    2- Custom animations defined on the client.
		-> Examples are provided inside of the Custom module.
    3- Support for Streaming Enabled and Streaming Out
		-> With the use of CollectionService.
	4- Support for Certain client only animations with the choice of Replication to the Server.
		-> The possibility to make certain modifications only visible to some people.
		-> For instance, making a door disappear for user X, but not replicating to the server after.

This module currently has some limitations:
    1- A player that receives a signal can know who else is receiving the signal.
	2- A "Custom" animation is not able to be "Paused".
--

Here is how you construct a SyncTween:
    - SyncTween.new(
        object: Instance,                                       -- 1. The object that you want to animate.
        tweenInfo: (TweenInfo | Helper.TweenArray | string)?,   -- 2. The TweenInfo of the animation.
        properties: { [string]: any }?,                         -- 3. The properties that you want to animate.
        players: { Player }?,                                   -- 4. The players that you want to animate.
		replicate: boolean?,                                    -- 5. Whether the animation should be replicated.
        sync: (boolean | number)?,                              -- 6. The synchronization of the animation.
		uuid: string?,                                          -- 7. The UUID of the animation. (Not needed)
    )

	Notes:
		2. (tweenInfo): You can send a TweenInfo, a Helper.TweenArray or a string.
			- If you send a string, it will be a custom animation.
			- A "TweenArray" Is something like the following:
				{ Time = 1, EasingStyle = Enum.EasingStyle.Linear, EasingDirection = Enum.EasingDirection.InOut }
			- I heavily encourage that you use the TweenInfo, it is less confusing but this change was needed for replication.

	Examples:
		1. SyncTween.new(workspace.Part, TweenInfo.new(1), { Position = Vector3.new(0, 10, 0) })
			-- Animates the part to the position (0, 10, 0) in 1 second.
		2. SyncTween.new(workspace.Part, nil, { Color = Color3.new(1,0,0) }, { Players.Player1 }, false)
			-- Turns the part to the color red for Player1.
		3. SyncTween.new(workspace.Part.Highlight, "Rainbow", nil, nil, nil, 10)
			-- Plays a rainbow animation @ 10 FPS.

The class contains global methods:
    - SyncTween.get(object: Instance, player: Player): { Sync } -- 1. Get all the animations that are playing.
    - SyncTween.fps(freq: number)                               -- 2. Set the FPS of the animations.

And here are the methods of the SyncTween class:
    - Play()                                                    -- 1. Play the animation.
    - Pause()                                                   -- 2. Pause the animation.
    - Cancel()                                                  -- 3. Cancel the animation.

Summary:
	You can create a SyncTween (Sync for short) using SyncTween.new().
	This function inheritates the normal methods from a tween (:Play() :Pause() :Cancel())
	Compared to TweenService, SyncTween offers multiple settings from the default behavior
		using the tweenInfo, players, replicate, sync and uuid parameters.
	The modules was written with --!strict mode, and the Sync type is exported.
--]]

-------------------------------------------------------------------------------------------------

-- // Required Services
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local TweenService = game:GetService("TweenService")
local CollectionService = game:GetService("CollectionService")

-- // Required Variables
local getTween: RemoteFunction = script.getTween -- Get all the tween information from the server
local signalTween: RemoteEvent = script.signalTween -- Signal the tween information to the client

-- // Cache
local Controllers: { [Instance]: Controls } = {} -- A table of all the animations that are currently playing

-------------------------------------------------------------------------------------------------
if RunService:IsServer() then
	-- Here, we are creating a metatable that will allow us to listen to new objects.
	setmetatable(Controllers, {
		__newindex = function(array: { [Instance]: { Sync } }, index: Instance, value: { Sync })
			rawset(array, index, value)  -- This is the default behavior.

			if value then index:AddTag(settings.COLLECTION_TAG)
			else index:RemoveTag(settings.COLLECTION_TAG) end
		end
	})
end

local Controller = {
	__newindex = function(array, index, value, reset)
		-- Everytime a new controller is added, we do our magic.
		local self: Sync

		if value then
			self = value
			-- Here, we are adding a new controller to the list of controllers (Playing).
			-------------------------------------------------------------------------------------------------
			-- Verifications before proceeding:
			if self.properties then
				for _, controller in pairs(array) do
					if not controller then continue end

					for property in self.properties do
						if self.properties[property] then
							controller:Pause() -- Another Controller is modifying this property.
						end
					end
				end
			end
			-------------------------------------------------------------------------------------------------

			self.Played:Fire()

			-- Cache the original properties.
			if self.properties then

				for property in self.properties do
					if self.original[property] then continue end

					local current = Helper.getProperty(self.object, property)

					if current then
						self.original[property] = current
					end
				end
			end

			-------------------------------------------------------------------------------------------------
			-- Here, depending on the environment, we will handle this addition differently.
			if RunService:IsServer() then
				-- On the server, we take care of distributing the tween to the clients.
				self.start = workspace:GetServerTimeNow()
				for _, player in self.players or Players:GetPlayers() do
					signalTween:FireClient(player, self, true)
				end

				-------------------------------------------------------------------------------------------------
                --[[
                    2 SCENARIOS:
                        1. The animation has no set time. (Other)
                        2. The animation has a set time regardless of synchronization. (stepped/animation)

                    In scenario 1, we will not be able to keep track of when the animation will end.
                    In scenario 2-3, we can use the Helper module to know how long the animation will last.

                    On the server, we use a clock.
                --]]
				-------------------------------------------------------------------------------------------------

				-- 1. No set time.
				if self.tween then
					if typeof(self.tween) == "string" then
						local Implementation: Custom.CustomImpl = Custom[self.tween]
						if Implementation and Implementation.orig then
							self.original = Implementation.orig(self.object, self.original)
						end
					else
						-- 2-3. Set time.
						local deltaLeft: number = Helper.getFullTweenTime(self.tween) - self.delta
						self.waiter = coroutine.create(function()
							task.wait(deltaLeft)

							self.Completed:Fire()
							self:Pause()
						end)
						if self.waiter then coroutine.resume(self.waiter) end
					end
				end

			else

				-------------------------------------------------------------------------------------------------
                --[[
                    3 SCENARIOS:
                        1. The tween is a string (Custom Animation). (Other)
                        2. The animation needs to be synchronized with the server. (stepped)
                        3. The animation does not need to be synchronized with the server. (animation)

                    On the client, we use a signal.
                --]]
				-------------------------------------------------------------------------------------------------

				-- Listen to the completion of the tween.
				local Finished: Signal.RBXScriptSignal = Signal.new()

				self.waiter = coroutine.create(function()
					Finished:Wait()

					self.Completed:Fire()
					self:Pause()
				end)
				if self.waiter then coroutine.resume(self.waiter) end

				-- On the client, we take care of animating this tween.
				if not self.tween then -- If there's no tween, apply the settings immediately.
					Finished:Fire()
					return
				end
				
				local FPS = settings.FPS
				if typeof(self.sync) == "number" then
					FPS = self.sync
				end

				-- 1. Custom Animation
				if typeof(self.tween) == "string" then
					-- Custom animation here.
					local Implementation: Custom.CustomImpl = Custom[self.tween]
					if Implementation then
						self.temporary = Implementation.clk(Finished, self.object, self.delta, FPS)
					end
				else

					-- If the animation is not a string, and has no properties, we can't animate it.
					if not self.properties then
						Finished:Fire()
						return
					end

					-- 2-3. Synchronized / Unsynchronized Animation
					if self.sync then
						-- The animation needs to be synchronized with the server.

						local clk: number = os.clock()
						local saturated: boolean = false
						self.connection = RunService.RenderStepped:Connect(function(deltaTime)
							if saturated then return end -- The animation has ended.
							if not self.object then saturated = true return end -- The object has been destroyed.

							self.delta += deltaTime

							if (os.clock() - clk) < 1/FPS then
								return -- Prevent running too fast.
							end
							clk = os.clock()

							local alpha: number, overflow: boolean = Helper.getAlpha(self.tween, self.delta)
							saturated = overflow

							for property, value in self.properties do
								Helper.changeProperty(
									self.object, property,
									Helper.lerp(alpha, self.original[property], value)
								)
							end

							-- Check if the saturation has been reached.
							if saturated then
								Finished:Fire()
							end
						end)
					else
						-- The animation does not need to be synchronized with the server.
						self.tween = Helper.modifyTween(self.tween, "Time", self.tween.Time - self.delta)
						self.animation = TweenService:Create(self.object, self.tween, self.properties)
						if self.animation then
							self.animation:Play()
							self.connection = self.animation.Completed:Once(function()
								Finished:Fire()
							end)
						end

					end
				end
			end
		else
			self = (array[index] :: Sync)
			-- Here, we are removing the controller from the list of controllers (Pausing).
			-------------------------------------------------------------------------------------------------
			-- Here, depending on the environment, we will handle this addition differently.
			if RunService:IsServer() then
				-- Here, we are cleaning up the server side.
				-------------------------------------------------------------------------------------------------
				-- Cleanup:
				if self.waiter and coroutine.status(self.waiter) == "suspended" then
					coroutine.close(self.waiter)
				end

				self.waiter = nil
				-------------------------------------------------------------------------------------------------

				-- On the server, we take care of distributing the tween to the clients.
				for _, player in self.players or Players:GetPlayers() do
					signalTween:FireClient(player, self, false, reset)
				end

				-- We will set the properties to the expected values.
				if not reset and self.replicate then
					self.delta = (workspace:GetServerTimeNow() - self.start) + self.delta

					if typeof(self.tween) ~= "string" then
						if self.properties and self.original then
							local alpha: number = (self.tween ~= nil) 
								and Helper.getAlpha(self.tween, self.delta)
								or 1

							for property, value in self.properties do
								Helper.changeProperty(
									self.object, property,
									Helper.lerp(
										alpha,
										self.original[property],
										value
									)
								)
							end
						end
					end
				end
			else
				-- Here, we are cleaning up the client side.
				-------------------------------------------------------------------------------------------------
				-- Cleanup:
				if self.connection then
					self.connection:Disconnect()
				end

				if self.animation then
					self.animation:Pause()
				end

				if typeof(self.tween) == "string" then
					local Implementation: Custom.CustomImpl = Custom[self.tween]
					if Implementation and Implementation.clear then
						Implementation.clear(self.temporary)
					end
				end

				self.animation = nil
				self.connection = nil
				self.temporary = nil
				-------------------------------------------------------------------------------------------------
			end

			self.Paused:Fire()
		end

		rawset(array, index, value)
	end,
} :: ControllerImpl

-------------------------------------------------------------------------------------------------

-- // Constructor
function SyncTween.new(object, tweenInfo, properties, players, replicate, sync, uuid, start, delta, original): Sync
	local self = {}

	-- Define:
	self.sync = sync
	self.object = object
	self.players = players
	self.replicate = true
	self.UUID = uuid or HttpService:GenerateGUID(false)

	-- Time:
	self.delta = delta or 0
	self.start = start or workspace:GetServerTimeNow()

	-- Properties:
	self.original = original or {}
	self.properties = properties

	-- Signals:
	self.Played = Signal.new()
	self.Paused = Signal.new()
	self.Canceled = Signal.new()
	self.Completed = Signal.new()

	-- Modifications:
	-------------------------------------------------------------------------------------------------

    --[[
        Unfortunately, ROBLOX does not allow developers to transfer TweenInfos through remotes.
        This means that we have to convert the TweenInfo into a table and then convert it back.
    --]]

	local transformation: unknown
	if tweenInfo then
		if RunService:IsServer() then
			if typeof(tweenInfo) == "TweenInfo" then
				transformation = Helper.tweenToArray(
					(tweenInfo :: TweenInfo)
				)
			end
		else
			if typeof(tweenInfo) == "table" then
				transformation = Helper.arrayToTween(
					(tweenInfo :: { [string]: any })
				)
			end
		end
	end

	self.tween = (
		(transformation or tweenInfo) :: (TweenInfo | Helper.TweenArray | string)?
	)

	if replicate ~= nil then
		self.replicate = replicate
	end

	-------------------------------------------------------------------------------------------------

	return setmetatable(self, SyncTween)
end

-- // Public Methods
function SyncTween.get(object: Instance, player: Player): { Sync }
	if RunService:IsServer() then
		local running: { Sync } = {}

		-- Only return the tweens that are running for the player
		local objectControllers = Controllers[object]
		if objectControllers then
			for _, sync in pairs(objectControllers.data) do
				if not sync then continue end

				if not sync.players or table.find(sync.players, player) then
					table.insert(running, sync)
				end
			end
		end

		return running
	else
		return getTween:InvokeServer(object)
	end
end

function SyncTween.fps(freq: number) -- Sets the FPS to default sync.
	settings.FPS = freq
end

-- // Private Methods
local function addSync(data: Sync)
	local objectControls: Controls = Controllers[data.object]

	-- Check if the objectControllers exist.
	if not objectControls then
		objectControls = {
			amount = 0;
			data = setmetatable({} :: { [string]: Sync }, Controller);
		} :: Controls

		Controllers[data.object] = objectControls
	else
		if objectControls.data[data.UUID] then
			return
		end
	end

	objectControls.amount += 1
	objectControls.data[data.UUID] = data
end

local function removeSync(data: Sync, reset: boolean?)
	local objectControls: Controls = Controllers[data.object]
	if not objectControls then return end

	local metatable: ControllerImpl = getmetatable(objectControls.data)
	metatable.__newindex(
		rawget(objectControls, "data"), data.UUID, nil, reset
	)

	objectControls.amount -= 1

	if objectControls.amount <= 0 then
		Controllers[data.object] = nil -- This will fire the list metatable.
	end
end

-- // Class Methods
function SyncTween:Play()
	addSync(self)
end

function SyncTween:Pause()
	removeSync(self)
end

function SyncTween:Cancel(original: { [string]: any }?)
	removeSync(self, true)

	-- Reset the properties to the original ones
	if original or self.original then
		for property, value in original or self.original do
			Helper.changeProperty(
				self.object, property, value
			)
		end
	end

	self.delta = 0
	table.clear(self.original)
end

-------------------------------------------------------------------------------------------------
-- // Connections
if RunService:IsServer() then
	getTween.OnServerInvoke = function(player: Player, object: Instance)
		return SyncTween.get(object, player)
	end
else
	local function createSyncObject(data: self): Sync
		return SyncTween.new(data.object, data.tween, data.properties, data.players,
			data.replicate, data.sync, data.UUID, data.start, data.delta, data.original
		):Play()
	end

	signalTween.OnClientEvent:Connect(function(data: self, creation: boolean, reset: boolean?)
		if creation then
			createSyncObject(data):Play()
		else
			local objectControllers = Controllers[data.object]
			if objectControllers then
				local Potential: Sync? = objectControllers.data[data.UUID]
				if Potential then
					if reset then
						Potential:Cancel(data.original)
					else
						Potential:Pause()
					end
				end
			end
		end
	end)

	CollectionService:GetInstanceAddedSignal(settings.COLLECTION_TAG):Connect(function(instance)
		local tweens = SyncTween.get(instance, Players.LocalPlayer)
		for _, data in tweens do
			createSyncObject(data):Play()
		end
	end)

	CollectionService:GetInstanceRemovedSignal(settings.COLLECTION_TAG):Connect(function(instance)
		local objectControllers = Controllers[instance]
		if objectControllers then
			for _, self in pairs(objectControllers.data) do
				if not self then continue end
				self:Pause()
			end
		end
	end)
end
-------------------------------------------------------------------------------------------------

return SyncTween