--!strict

-- // Services
local RunService = game:GetService("RunService")
----------------------------------------------------

local Signal = require(script.Parent.Signal)

export type CustomImpl = {
	clk: (
		signal: Signal.RBXScriptSignal, object: Instance, original: { [string]: any }?,
		properties: { [string]: any }?, totalDelta: number, FPS: number
	) -> ...any,

	clear: ( (...any) -> () )?;
	orig: ( (object: Instance, original: { [string]: any }?, properties: { [string]: any }?) -> { [string]: any } )?
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

local function bindCallbackToSteppedWithFPS(callback: () -> (), FPS: number, deltaTime: number?)
	local last: number = os.clock()

	return RunService.RenderStepped:Connect(function()
		if (os.clock() - last) < 1/FPS then return end
		last = os.clock()

		callback()
	end)
end

Custom.Rainbow = {
	-- Example for an animated Highlight.
	clk = function(signal, object, original, properties, totalDelta, FPS)
		local start: number = os.clock() - totalDelta
		local callback = function()
			local hue = start % 1
			object.FillColor = Color3.fromHSV(hue, 1, 1)
		end

		local connection = bindCallbackToSteppedWithFPS(callback, FPS, totalDelta)

		signal:Once(function()
			connection:Disconnect()
		end)

		return connection
	end,

	clear = function(connection: RBXScriptConnection)
		connection:Disconnect()
	end,

	orig = function(object, properties, original)
		local object: Highlight = (object :: Highlight)

		return {FillColor = object.FillColor}
	end,
}

return Custom