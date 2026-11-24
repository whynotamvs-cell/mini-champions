--!nonstrict
-- Tiny subset of the Jest-Lua API (describe/it/test/beforeEach/expect) for running specs in Lune.
-- Only the matchers used by our specs are implemented; add more here when a spec needs them.

local JestShim = {}

local registered = {} -- { { file, name, fn, hooks } }
local describeStack = {}
local hookStack = { {} }
local currentFile = "?"

function JestShim.setFile(file)
	currentFile = file
end

local function fullName(name)
	local parts = table.clone(describeStack)
	table.insert(parts, name)
	return table.concat(parts, " > ")
end

local function describe(name, fn)
	table.insert(describeStack, name)
	table.insert(hookStack, {})
	fn()
	table.remove(hookStack)
	table.remove(describeStack)
end

local function it(name, fn)
	local hooks = {}
	for _, level in hookStack do
		for _, hook in level do
			table.insert(hooks, hook)
		end
	end
	table.insert(registered, { file = currentFile, name = fullName(name), fn = fn, hooks = hooks })
end

local function beforeEach(fn)
	table.insert(hookStack[#hookStack], fn)
end

local function deepEqual(a, b)
	if a == b then
		return true
	end
	if type(a) ~= "table" or type(b) ~= "table" then
		return false
	end
	for k, v in a do
		if not deepEqual(v, b[k]) then
			return false
		end
	end
	for k in b do
		if a[k] == nil then
			return false
		end
	end
	return true
end

local function show(value)
	if type(value) == "string" then
		return string.format("%q", value)
	elseif type(value) == "table" then
		local parts = {}
		for k, v in value do
			table.insert(parts, `{tostring(k)}={show(v)}`)
		end
		table.sort(parts)
		return "{" .. table.concat(parts, ", ") .. "}"
	end
	return tostring(value)
end

local function makeMatchers(actual, negate)
	local function check(pass, message)
		if negate then
			pass = not pass
			message = "not " .. message
		end
		if not pass then
			error(`expected {show(actual)} {message}`, 3)
		end
	end

	return {
		toBe = function(expected)
			check(rawequal(actual, expected) or (actual ~= actual and expected ~= expected), `to be {show(expected)}`)
		end,
		toEqual = function(expected)
			check(deepEqual(actual, expected), `to equal {show(expected)}`)
		end,
		toBeNil = function()
			check(actual == nil, "to be nil")
		end,
		toBeTruthy = function()
			check(not not actual, "to be truthy")
		end,
		toBeFalsy = function()
			check(not actual, "to be falsy")
		end,
		toBeGreaterThan = function(n)
			check(actual > n, `to be > {n}`)
		end,
		toBeGreaterThanOrEqual = function(n)
			check(actual >= n, `to be >= {n}`)
		end,
		toBeLessThan = function(n)
			check(actual < n, `to be < {n}`)
		end,
		toBeLessThanOrEqual = function(n)
			check(actual <= n, `to be <= {n}`)
		end,
		toContain = function(item)
			local found = false
			if type(actual) == "string" then
				found = string.find(actual, item, 1, true) ~= nil
			else
				found = table.find(actual, item) ~= nil
			end
			check(found, `to contain {show(item)}`)
		end,
		toHaveLength = function(n)
			check(#actual == n, `to have length {n} (got {#actual})`)
		end,
		toThrow = function()
			local ok = pcall(actual)
			check(not ok, "to throw")
		end,
	}
end

-- In Jest-Lua `.never` replaces `.not` (reserved word in Luau).
local function expect(actual)
	local matchers = makeMatchers(actual, false)
	matchers.never = makeMatchers(actual, true)
	return matchers
end

JestShim.globals = {
	describe = describe,
	it = it,
	test = it,
	beforeEach = beforeEach,
	expect = expect,
}

function JestShim.run()
	local passed, failed = 0, 0
	local lastFile = nil
	for _, test in registered do
		if test.file ~= lastFile then
			print(`\n{test.file}`)
			lastFile = test.file
		end
		local ok, err = pcall(function()
			for _, hook in test.hooks do
				hook()
			end
			test.fn()
		end)
		if ok then
			passed += 1
			print(`  ✓ {test.name}`)
		else
			failed += 1
			print(`  ✗ {test.name}\n      {err}`)
		end
	end
	return passed, failed
end

return JestShim
