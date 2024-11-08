--!strict

-- // Services
local RunService = game:GetService("RunService")
----------------------------------------------------

local Signal = require(script.Parent.Signal)

export type CustomImpl = {
	clk: (
		signal: Signal.RBXScriptSignal, object: Instance, original: { [string]: any }?,
		properties: { [string]: any }?, additional: { [string]: any }, totalDelta: number, FPS: number
	) -> ...any,

	clear: ( (...any) -> () )?;
	orig: ( (object: Instance, original: { [string]: any }?, properties: { [string]: any }?, additional: { [string]: any }) -> { [string]: any } )?
}
----------------------------------------------------

--[[
-- // Notes:
	- These are custom implementations for animations.
	- In the case where the animation is custom, it is possible to pass anything through the `properties` parameter.

-- // Example:
	SyncTween.new(workspace.Part.Highlight, "Rainbow") -> This will use the `Rainbow` implementation.
--]]

----------------------------------------------------


local Custom = {} :: { [string]: CustomImpl }

local function bindCallbackToSteppedWithFPS(callback: (delta: number) -> (), FPS: number, deltaTime: number?)
	local start: number = os.clock()
	local last: number = os.clock()

	return RunService.RenderStepped:Connect(function()
		if (os.clock() - last) < 1/FPS then return end
		last = os.clock()

		callback(os.clock() - start)
	end)
end

Custom.Rainbow = {
	-- Example for an animated Highlight.
	clk = function(signal, object, original, properties, additional, totalDelta, FPS)
		local object: Highlight = (object :: Highlight)

		local callback = function(delta: number)
			local hue = delta % 1
			object.FillColor = Color3.fromHSV(hue, 1, 1)
		end

		return bindCallbackToSteppedWithFPS(callback, FPS, totalDelta)
	end,

	clear = function(connection: RBXScriptConnection)
		connection:Disconnect()
	end,

	orig = function(object, properties, original, additional)
		local object: Highlight = (object :: Highlight)

		return {FillColor = object.FillColor}
	end,
}

Custom.Rotation = {
	clk = function(signal, object, original, properties, additional, totalDelta, FPS)
		local object: BasePart = (object :: BasePart)

		local callback = function(delta: number)
			local ydir = delta % 360
			object.Orientation = Vector3.new(0, math.sin(ydir)*360, 0)
		end

		return bindCallbackToSteppedWithFPS(callback, FPS, totalDelta)
	end,

	clear = function(connection: RBXScriptConnection)
		connection:Disconnect()
	end,

	orig = function(object, properties, original, additional)
		local object: BasePart = (object :: BasePart)

		return {Orientation = object.Orientation}
	end,
}

Custom.cRotation = {
	clk = function(signal, object, original, properties, additional, totalDelta, FPS)
		local object: BasePart = (object :: BasePart)

		local callback = function(delta: number)
			local ydir = delta % 360
			object.Orientation = Vector3.new(0, ydir*additional.Speed, 0)
		end

		return bindCallbackToSteppedWithFPS(callback, FPS, totalDelta)
	end,

	clear = function(connection: RBXScriptConnection)
		connection:Disconnect()
	end,

	orig = function(object, properties, original, additional)
		local object: BasePart = (object :: BasePart)

		return {Orientation = object.Orientation}
	end,
}

return Custom