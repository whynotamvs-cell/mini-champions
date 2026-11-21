--!strict
-- Server entry point. Init() every service in order (no yields), then Start() each in its own thread.
-- See docs/ARCHITECTURE.md 4.

local Net = require(script.Parent.Net)

type Service = {
	Init: (self: any) -> (),
	Start: (self: any) -> (),
}

-- Order matters: a service may only call services listed before it during Init().
local SERVICE_ORDER: { string } = {
	"TelemetryService",
	"PlayerDataService",
	"RewardService",
	"MinigameService",
}

local function loadServices(): { Service }
	local folder = script.Parent:FindFirstChild("Services")
	local loaded: { Service } = {}
	for _, name in SERVICE_ORDER do
		local module = folder and folder:FindFirstChild(name)
		assert(module and module:IsA("ModuleScript"), `[Main] service module "{name}" not found`)
		table.insert(loaded, (require :: any)(module))
	end
	return loaded
end

Net.init()

local services = loadServices()
for _, service in services do
	service:Init()
end
for _, service in services do
	task.spawn(service.Start, service)
end
