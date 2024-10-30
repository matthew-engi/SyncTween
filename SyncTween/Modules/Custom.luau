--!strict

-- // Services
local RunService = game:GetService("RunService")
----------------------------------------------------

local Signal = require(script.Parent.Signal)

export type CustomImpl = {
	clk: (
		signal: Signal.RBXScriptSignal, object: Instance, totalDelta: number, FPS: number
	) -> any,

	clear: ( (any) -> () )?;
	orig: ( (object: Instance, original: { [string]: any }) -> { [string]: any } )?
}

local Custom = {} :: { [string]: CustomImpl }

local function bindCallbackToSteppedWithFPS(callback: () -> (), FPS: number, deltaTime: number?)
	local last: number = os.clock()

	return RunService.RenderStepped:Connect(function()
		if (os.clock() - last) < 1/FPS then return end
		last = os.clock()

		callback() -- Use unpack to pass the arguments
	end)
end

Custom.Rainbow = {
	clk = function(signal, object, totalDelta, FPS)
		local object: Highlight = (object :: Highlight)
		
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

	orig = function(object, original)
		local object: Highlight = (object :: Highlight)

		return {FillColor = object.FillColor}
	end,
}

return Custom