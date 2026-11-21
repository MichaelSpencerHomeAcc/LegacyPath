-- Shared namespace: a tiny event bus and helpers. No game API here, so it loads in tests.
local _, ns = ...

local listeners = {}

function ns.On(event, fn)
	listeners[event] = listeners[event] or {}
	table.insert(listeners[event], fn)
end

function ns.Fire(event, ...)
	for _, fn in ipairs(listeners[event] or {}) do
		fn(...)
	end
end

function ns.Print(msg)
	print("|cff66ccffLegacyPath|r: " .. tostring(msg))
end

-- Editorial estimates, never measurements.
ns.DIFFICULTY = { "Low", "Medium", "High" }
