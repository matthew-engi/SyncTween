--!strict

type SignalImpl = {
	__index: SignalImpl,
	new: () -> RBXScriptSignal,
	Connect: (self: RBXScriptSignal, callback: (...any) -> ()) -> (),
	Once: (self: RBXScriptSignal, callback: (...any) -> ()) -> (),
	Repeat: (self: RBXScriptSignal, amount: number, callback: (...any) -> ()) -> (),
	Disconnect: (self: RBXScriptSignal, callback: (...any) -> ()) -> (),
	Wait: (self: RBXScriptSignal) -> ();
	Fire: (...any) -> (),
}

type self = {
	connections: { [(...any) -> ()]: boolean | number },
}

export type RBXScriptSignal = typeof(
	setmetatable({} :: self, {} :: SignalImpl)
)
-------------------------------------------------------------------------------------------------

local Signal: SignalImpl = {} :: SignalImpl
Signal.__index = Signal

-------------------------------------------------------------------------------------------------
function Signal.new(): RBXScriptSignal
	local self = {}
	self.connections = {}

	return setmetatable(self, Signal)
end

function Signal:Connect(callback: (...any) -> ())
	self.connections[callback] = true
end

function Signal:Once(callback: (...any) -> ())
	self.connections[callback] = 1
end

function Signal:Repeat(amount: number, callback: (...any) -> ())
	self.connections[callback] = amount
end

function Signal:Disconnect(callback: (...any) -> ())
	self.connections[callback] = nil
end

function Signal:Wait()
	local thread = coroutine.running()
	self:Once(function(...)
		coroutine.resume(thread, ...)
	end)
	return coroutine.yield()
end

function Signal:Fire(...)
	for callback, counter in self.connections do
		callback(...)
		if counter == true then
			continue
		end

		self.connections[callback] = counter - 1
		if self.connections[callback] == 0 then
			self.connections[callback] = nil
		end
	end
end

return Signal