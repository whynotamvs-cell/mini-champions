--!strict
-- Client entry point. Init() every controller in order (no yields), then Start() each in its own thread.

type Controller = {
	Init: (self: any) -> (),
	Start: (self: any) -> (),
}

local CONTROLLER_ORDER: { string } = {
	"ChatController",
	"DataController",
	"LocalizationController",
	"UIController",
	"DashController",
	"ClubMenuController",
	"HudController",
	"TutorialController",
	"BoardController",
	"TrackSignController",
	"HazardController",
	"BannerController",
	"WorldFxController",
	"RecordsController",
	"ShopController",
	"PetsMenuController",
	"PetController",
	"FallController",
	"SettingsController",
	"EmoteController",
	"FxController",
	"MusicController",
}

local function loadControllers(): { Controller }
	local folder = script.Parent:FindFirstChild("Controllers")
	local loaded: { Controller } = {}
	for _, name in CONTROLLER_ORDER do
		local module = folder and folder:FindFirstChild(name)
		assert(module and module:IsA("ModuleScript"), `[Main] controller module "{name}" not found`)
		table.insert(loaded, (require :: any)(module))
	end
	return loaded
end

local controllers = loadControllers()
for _, controller in controllers do
	controller:Init()
end
for _, controller in controllers do
	task.spawn(controller.Start, controller)
end
