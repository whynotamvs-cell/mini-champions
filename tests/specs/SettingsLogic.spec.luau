--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect

local TableUtil = require(ReplicatedStorage.Shared.Utilities.TableUtil)
local Validators = require(ReplicatedStorage.Shared.Net.Validators)
local Services = ServerScriptService.Server.Services
local Template = require(Services.PlayerData.Template)
local Validate = require(Services.PlayerData.Validate)
local SettingsLogic = require(Services.Logic.SettingsLogic)

describe("SettingsLogic.sanitize (TEST_PLAN X-06)", function()
	it("keeps valid values", function()
		local changes =
			SettingsLogic.sanitize({ MusicVolume = 0.3, SfxVolume = 1, Language = "ru", ReducedMotion = true })
		expect(changes.MusicVolume).toBe(0.3)
		expect(changes.SfxVolume).toBe(1)
		expect(changes.Language).toBe("ru")
		expect(changes.ReducedMotion).toBe(true)
	end)

	it("accepts ShowPets only as a boolean and applies it", function()
		expect(SettingsLogic.sanitize({ ShowPets = false }).ShowPets).toBe(false)
		expect(SettingsLogic.sanitize({ ShowPets = true }).ShowPets).toBe(true)
		expect(SettingsLogic.isEmpty(SettingsLogic.sanitize({ ShowPets = "no" } :: any))).toBe(true)
		local data = TableUtil.deepCopy(Template)
		expect(data.Settings.ShowPets).toBe(true) -- on by default
		SettingsLogic.apply(data, SettingsLogic.sanitize({ ShowPets = false }))
		expect(data.Settings.ShowPets).toBe(false)
		expect(#Validate.issues(data)).toBe(0)
	end)

	it("clamps volumes to 0..1", function()
		local changes = SettingsLogic.sanitize({ MusicVolume = 999, SfxVolume = -5 })
		expect(changes.MusicVolume).toBe(1)
		expect(changes.SfxVolume).toBe(0)
	end)

	it("drops NaN, infinity and wrong types", function()
		local bad: any = { MusicVolume = 0 / 0, SfxVolume = math.huge, Language = 5, ReducedMotion = "yes" }
		expect(SettingsLogic.isEmpty(SettingsLogic.sanitize(bad))).toBe(true)
	end)

	it("rejects unsupported languages", function()
		expect(SettingsLogic.isEmpty(SettingsLogic.sanitize({ Language = "xx" }))).toBe(true)
		expect(SettingsLogic.isEmpty(SettingsLogic.sanitize({ Language = ("a"):rep(500) }))).toBe(true)
	end)

	it("ignores extra keys and non-table input", function()
		local changes = SettingsLogic.sanitize({ Stars = 999999, MusicVolume = 0.5, Admin = true })
		expect((changes :: any).Stars).toBe(nil)
		expect((changes :: any).Admin).toBe(nil)
		expect(changes.MusicVolume).toBe(0.5)
		for _, bad in { "x", 5, true } :: { any } do
			expect(SettingsLogic.isEmpty(SettingsLogic.sanitize(bad))).toBe(true)
		end
	end)
end)

describe("SettingsLogic.apply", function()
	it("writes only the changed keys and never touches other data", function()
		local data = TableUtil.deepCopy(Template)
		data.Stars = 42
		SettingsLogic.apply(data, SettingsLogic.sanitize({ SfxVolume = 0.2, Stars = 1_000_000 }))
		expect(data.Settings.SfxVolume).toBe(0.2)
		expect(data.Settings.MusicVolume).toBe(Template.Settings.MusicVolume)
		expect(data.Stars).toBe(42)
		expect(#Validate.issues(data)).toBe(0)
	end)
end)

describe("Validators.plainTable", function()
	local check = Validators.plainTable()

	it("accepts plain tables only", function()
		expect((check({}))).toBe(true)
		expect((check({ a = 1 }))).toBe(true)
		for _, bad in { "x", 1, true, setmetatable({}, {}) } :: { any } do
			expect((check(bad))).toBe(false)
		end
	end)
end)
