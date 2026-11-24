--!strict
-- Minimal synchronous signal. Handlers run in connection order on the firing thread,
-- so a handler must not yield. Use task.spawn inside a handler if it needs to.

export type Connection = {
	Disconnect: (self: Connection) -> (),
	Connected: boolean,
}

export type Signal<T...> = {
	Connect: (self: Signal<T...>, handler: (T...) -> ()) -> Connection,
	Fire: (self: Signal<T...>, T...) -> (),
	DisconnectAll: (self: Signal<T...>) -> (),
}

local Signal = {}

function Signal.new<T...>(): Signal<T...>
	local handlers: { { fn: (T...) -> (), connection: Connection } } = {}

	local self = {} :: Signal<T...>

	function self.Connect(_: Signal<T...>, handler: (T...) -> ()): Connection
		local connection = { Connected = true } :: Connection
		local entry = { fn = handler, connection = connection }
		function connection.Disconnect(conn: Connection)
			if not conn.Connected then
				return
			end
			conn.Connected = false
			local index = table.find(handlers, entry)
			if index then
				table.remove(handlers, index)
			end
		end
		table.insert(handlers, entry)
		return connection
	end

	function self.Fire(_: Signal<T...>, ...: T...)
		-- Copy so handlers may disconnect while firing.
		local snapshot = table.clone(handlers)
		for _, entry in snapshot do
			if entry.connection.Connected then
				entry.fn(...)
			end
		end
	end

	function self.DisconnectAll(_: Signal<T...>)
		for _, entry in handlers do
			entry.connection.Connected = false
		end
		table.clear(handlers)
	end

	return self
end

return Signal
