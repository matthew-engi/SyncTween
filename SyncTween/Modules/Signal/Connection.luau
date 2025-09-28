--!strict
local Connection = {}

-- Types ----------------
export type Callback<T...> = (T...) -> ()

type ConnectionData<T...> = {
	persist: boolean,
	callback: Callback<T...>?
}

type ConnectionMethods<T...> = {
	Disconnect: (self: Connection<T...>) -> (),
}

-- Metamethods ----------
Connection.__index = Connection

export type Connection<T...> = ConnectionData<T...> & ConnectionMethods<T...>

----------------------------------------------------------------------

-- Creates a new signal class.
function Connection.new<T...>(callback: Callback<T...>, persist: boolean): Connection<T...>
	local self = {
		persist = persist,
		callback = callback;
	} :: ConnectionData<T...>

	return setmetatable(self, Connection) :: any
end

-- Connects a function to the specified signal.
function Connection.Disconnect<T...>(self: Connection<T...>)
	self.persist = false
	self.callback = nil
end

----------------------------------------------------------------------

return Connection