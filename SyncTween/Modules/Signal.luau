--!strict
local Signal = {}

-- Dependencies ----------------
local Connection = require(script.Connection)

-- Types ----------------
type Callback<T...> 	= Connection.Callback<T...>
type Connection<T...> 	= Connection.Connection<T...>

type SignalData<T...> 	= {
	connections: { [Callback<T...>]: Connection<T...> }
}

type SignalMethods<T...> = {
	Connect: (self: Signal<T...>, callback: Callback<T...>) -> Connection<T...>,
	Once: 	 (self: Signal<T...>, callback: Callback<T...>) -> Connection<T...>,
	Wait: 	 (self: Signal<T...>) 		-> (T...),
	Fire: 	 (self: Signal<T...>, T...) -> (),
	Clear: 	 (self: Signal<T...>) 		-> (),
}

-- Metamethods ----------
Signal.__index = Signal

export type Signal<T...> = SignalData<T...> & SignalMethods<T...>

----------------------------------------------------------------------

-- Creates a new signal class.
function Signal.new<T...>(): Signal<T...>
	local self = {
		connections = {};
	} :: SignalData<T...>

	return setmetatable(self, Signal) :: any
end

-- Connects a function to the specified signal.
function Signal.Connect<T...>(self: Signal<T...>, callback: Callback<T...>)
	local connection = Connection.new(callback, true)
	self.connections[callback] = connection
	return connection
end

-- Connects a function to the specified signal, and disconnects once completed.
function Signal.Once<T...>(self: Signal<T...>, callback: Callback<T...>)
	local connection = Connection.new(callback, false)
	self.connections[callback] = connection
	return connection
end

-- Waits for a signal to fire, and returns the parameters it was given.
function Signal.Wait<T...>(self: Signal<T...>): T...
	local thread = coroutine.running()
	self:Once(function(...)
		coroutine.resume(thread, ...)
	end)
	return coroutine.yield()
end

-- Clears all connections to a signal.
function Signal.Clear<T...>(self: Signal<T...>)
	for _, connection in self.connections do
		connection:Disconnect()
	end
end

-- Fires the signal with the given arguments.
function Signal.Fire<T...>(self: Signal<T...>, ...: T...)
	for rawCallback, rawConnection in self.connections do
		local connection = rawConnection :: Connection<T...>

		if connection then
			if connection.callback then
				task.defer(connection.callback, ...)
			end

			if not connection.persist then
				connection:Disconnect()
				self.connections[rawCallback] = nil
			end
		end
	end
end

----------------------------------------------------------------------

return Signal