--!nonstrict
-- nonstrict: this harness builds a dynamic fake DataModel; strict typing would add noise only.
--
-- Runs tests/specs/*.spec.luau outside Roblox with Lune.
-- Pure-logic specs only: modules are loaded from src/ through a virtual instance tree that
-- mirrors default.project.json, and JestGlobals is replaced by a small compatible shim.
--
-- Usage: lune run tests/lune/run.luau [filter]

local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")

local JestShim = require("./JestShim")
local LocalizationCheck = require("./LocalizationCheck")

local filter = process.args[1]

-- Virtual instance tree ---------------------------------------------------------------

local VInstance = {}
VInstance.__index = function(self, key)
	local method = rawget(VInstance, key)
	if method then
		return method
	end
	local child = self:FindFirstChild(key)
	if child == nil then
		error(`{key} is not a valid member of {self:GetFullName()}`, 2)
	end
	return child
end

local function newNode(name, parent, props)
	local node = setmetatable({
		Name = name,
		Parent = parent,
		_path = props.path, -- filesystem path for dirs/files
		_isDir = props.isDir == true,
		_value = props.value, -- for virtual modules
		_children = props.children, -- for virtual containers
		_cache = {},
	}, VInstance)
	return node
end

local function instanceNameForFile(fileName)
	for _, suffix in { ".server.luau", ".client.luau", ".luau", ".lua" } do
		if string.sub(fileName, -#suffix) == suffix then
			return string.sub(fileName, 1, -#suffix - 1)
		end
	end
	return nil -- not a script (csv, gitkeep...), ignored here
end

function VInstance:GetFullName()
	local parts = {}
	local node = self
	while node do
		table.insert(parts, 1, node.Name)
		node = rawget(node, "Parent")
	end
	return table.concat(parts, ".")
end

-- Directory listings are read eagerly (fs calls yield, and metamethods cannot yield).
local function scanDir(dir)
	local children = {}
	for _, entry in fs.readDir(dir) do
		local full = `{dir}/{entry}`
		if fs.isDir(full) then
			children[entry] = { path = full, isDir = true, children = scanDir(full) }
		else
			local name = instanceNameForFile(entry)
			if name then
				children[name] = { path = full }
			end
		end
	end
	return children
end

function VInstance:FindFirstChild(name)
	local cache = rawget(self, "_cache")
	if cache[name] ~= nil then
		return cache[name] or nil
	end
	local found = nil
	local children = rawget(self, "_children")
	local spec = children and children[name]
	if spec then
		found = newNode(name, self, spec)
	end
	cache[name] = found or false
	return found
end

function VInstance:WaitForChild(name)
	return self:FindFirstChild(name) or error(`Infinite yield: {name} in {self:GetFullName()}`)
end

function VInstance:GetService(name)
	return self:FindFirstChild(name) or error(`Service {name} is not available in the Lune harness`)
end

function VInstance:IsA(className)
	return className == "ModuleScript" and rawget(self, "_path") ~= nil and not rawget(self, "_isDir")
end

-- Module loading --------------------------------------------------------------------

local game
local moduleCache = {}

local function virtualRequire(target)
	if type(target) == "string" then
		error(`string require "{target}" is not supported in specs; require instances`, 2)
	end
	local value = rawget(target, "_value")
	if value ~= nil then
		return value
	end
	local path = rawget(target, "_path")
	if rawget(target, "_isDir") then
		local init = target:FindFirstChild("init")
		if init == nil then
			error(`{target:GetFullName()} is a folder, not a module`, 2)
		end
		path = rawget(init, "_path")
	end
	if moduleCache[path] ~= nil then
		return moduleCache[path]
	end
	local source = fs.readFile(path)
	local chunk = luau.load(source, {
		debugName = path,
		environment = { script = target, require = virtualRequire, game = game },
	})
	local result = chunk()
	moduleCache[path] = result
	return result
end

game = newNode("game", nil, {
	children = {
		ReplicatedStorage = {
			children = {
				Shared = { path = "src/shared", isDir = true, children = scanDir("src/shared") },
				DevPackages = {
					children = {
						JestGlobals = { value = JestShim.globals },
					},
				},
			},
		},
		ServerScriptService = {
			children = {
				Server = { path = "src/server", isDir = true, children = scanDir("src/server") },
			},
		},
		ServerStorage = {
			children = {
				Tests = { path = "tests/specs", isDir = true, children = scanDir("tests/specs") },
			},
		},
	},
})

-- Run -------------------------------------------------------------------------------

local specFiles = {}
for _, entry in fs.readDir("tests/specs") do
	if string.sub(entry, -#".spec.luau") == ".spec.luau" and (filter == nil or string.find(entry, filter, 1, true)) then
		table.insert(specFiles, entry)
	end
end
table.sort(specFiles)

local tests = game.ServerStorage.Tests
local loadErrors = 0
for _, file in specFiles do
	JestShim.setFile(file)
	local ok, err = pcall(virtualRequire, tests:FindFirstChild(instanceNameForFile(file)))
	if not ok then
		loadErrors += 1
		print(`LOAD ERROR {file}: {err}`)
	end
end

local passed, failed = JestShim.run()

local locProblems = if filter == nil then LocalizationCheck.run() else {}
if filter == nil then
	print("\nLocalization check")
	if #locProblems == 0 then
		print("  ✓ UI.csv: all keys present, en and ru filled, params match")
	end
	for _, problem in locProblems do
		print(`  ✗ {problem}`)
	end
end

print(
	`\n{#specFiles} spec files, {passed} passed, {failed} failed, {loadErrors} load errors, {#locProblems} localization problems`
)
process.exit(if failed == 0 and loadErrors == 0 and #locProblems == 0 then 0 else 1)
