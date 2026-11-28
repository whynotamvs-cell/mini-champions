--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect

local TableUtil = require(ReplicatedStorage.Shared.Utilities.TableUtil)
local PlayerData = ServerScriptService.Server.Services.PlayerData
local Migrations = require(PlayerData.Migrations)
local Template = require(PlayerData.Template)

describe("Migrations (current chain)", function()
	it("current version is 5 and the template is already current", function()
		expect(Migrations.CURRENT_VERSION).toBe(5)
		local status, data = Migrations.migrate(TableUtil.deepCopy(Template))
		expect(status).toBe("ok")
		expect(data).toEqual(Template)
	end)

	it("refuses data from a newer version and leaves it untouched", function()
		local newer = TableUtil.deepCopy(Template) :: any
		newer.SchemaVersion = 6
		newer.Future = { x = 1 }
		local before = TableUtil.deepCopy(newer)
		local status, data = Migrations.migrate(newer)
		expect(status).toBe("newer")
		expect(data).toEqual(before)
	end)

	it("rejects invalid SchemaVersion values and non-tables", function()
		for _, bad in { "1", 0, -1, 1.5 } :: { any } do
			local d = TableUtil.deepCopy(Template) :: any
			d.SchemaVersion = bad
			expect((Migrations.migrate(d))).toBe("error")
		end
		expect((Migrations.migrate("nope"))).toBe("error")
	end)
end)

describe("Migration 1 -> 2 (second track)", function()
	-- A v1 profile as saved by the stage 1 code: no KeyDash record.
	local function v1Profile(): any
		local data = TableUtil.deepCopy(Template) :: any
		data.SchemaVersion = 1
		data.Minigames.KeyDash = nil
		data.Stars = 321
		data.Minigames.DeskDash = {
			Finishes = 4,
			BestTimeMs = 51_234,
			Medals = { Bronze = true, Silver = true, Gold = false },
		}
		return data
	end

	it("adds an empty KeyDash record and bumps the version", function()
		local status, data = Migrations.migrate(v1Profile())
		expect(status).toBe("ok")
		expect(data.SchemaVersion).toBe(5) -- the whole chain runs: v1 -> ... -> v5
		expect(data.Minigames.KeyDash).toEqual(Template.Minigames.KeyDash)
	end)

	it("keeps every existing value untouched", function()
		local before = v1Profile()
		local _, data = Migrations.migrate(TableUtil.deepCopy(before))
		expect(data.Stars).toBe(321)
		expect(data.Minigames.DeskDash).toEqual(before.Minigames.DeskDash)
		expect(data.Club).toEqual(before.Club)
		expect(data.Tutorial).toEqual(before.Tutorial)
		expect(data.Settings).toEqual(before.Settings)
	end)

	it("is safe to run on data that already has a KeyDash record (idempotent)", function()
		local d = v1Profile()
		d.Minigames.KeyDash =
			{ Finishes = 2, BestTimeMs = 44_000, Medals = { Bronze = true, Silver = false, Gold = false } }
		local _, data = Migrations.migrate(d)
		expect(data.Minigames.KeyDash.Finishes).toBe(2)
		expect(data.Minigames.KeyDash.BestTimeMs).toBe(44_000)
	end)

	it("fails (without throwing) when Minigames is not a table", function()
		local d = v1Profile()
		d.Minigames = "broken"
		local status = Migrations.migrate(d)
		expect(status).toBe("error")
	end)
end)

describe("Migration 2 -> 3 (shop)", function()
	local function v2Profile(): any
		local data = TableUtil.deepCopy(Template) :: any
		data.SchemaVersion = 2
		data.Shop = nil
		data.Stars = 777
		data.Club.UpgradesOwned = 3
		return data
	end

	it("adds an empty Shop and bumps the version", function()
		local status, data = Migrations.migrate(v2Profile())
		expect(status).toBe("ok")
		expect(data.SchemaVersion).toBe(5)
		expect(data.Shop).toEqual(Template.Shop)
	end)

	it("keeps every existing value untouched", function()
		local before = v2Profile()
		local _, data = Migrations.migrate(TableUtil.deepCopy(before))
		expect(data.Stars).toBe(777)
		expect(data.Club).toEqual(before.Club)
		expect(data.Minigames).toEqual(before.Minigames)
		expect(data.Settings).toEqual(before.Settings)
	end)

	it("does not overwrite a Shop that already exists (idempotent)", function()
		local d = v2Profile()
		d.Shop = { SkipTokens = 5, SpringBoots = true, SpringOn = false, Owned = {}, Trail = "", Finish = "" }
		local _, data = Migrations.migrate(d)
		expect(data.Shop.SkipTokens).toBe(5)
		expect(data.Shop.SpringBoots).toBe(true)
	end)
end)

describe("Migration 3 -> 4 (pets)", function()
	local function v3Profile(): any
		local data = TableUtil.deepCopy(Template) :: any
		data.SchemaVersion = 3
		data.Pets = nil
		data.Stars = 640
		data.Shop.SkipTokens = 4
		return data
	end

	it("adds an empty Pets record and bumps the version", function()
		local status, data = Migrations.migrate(v3Profile())
		expect(status).toBe("ok")
		expect(data.SchemaVersion).toBe(5)
		expect(data.Pets).toEqual(Template.Pets)
	end)

	it("keeps every existing value untouched", function()
		local before = v3Profile()
		local _, data = Migrations.migrate(TableUtil.deepCopy(before))
		expect(data.Stars).toBe(640)
		expect(data.Shop).toEqual(before.Shop)
		expect(data.Minigames).toEqual(before.Minigames)
	end)

	it("does not overwrite pets that already exist (idempotent)", function()
		local d = v3Profile()
		d.Pets = { Owned = { eraser_bunny = true }, Equipped = "eraser_bunny" }
		local _, data = Migrations.migrate(d)
		expect(data.Pets.Equipped).toBe("eraser_bunny")
	end)
end)

describe("Migration 4 -> 5 (show pets setting)", function()
	local function v4Profile(): any
		local data = TableUtil.deepCopy(Template) :: any
		data.SchemaVersion = 4
		data.Settings.ShowPets = nil
		data.Settings.MusicVolume = 0.3
		data.Pets = { Owned = { eraser_bunny = true }, Equipped = "eraser_bunny" }
		return data
	end

	it("adds ShowPets = true and keeps every other setting and pet", function()
		local status, data = Migrations.migrate(v4Profile())
		expect(status).toBe("ok")
		expect(data.SchemaVersion).toBe(5)
		expect(data.Settings.ShowPets).toBe(true)
		expect(data.Settings.MusicVolume).toBe(0.3)
		expect(data.Pets.Equipped).toBe("eraser_bunny")
	end)

	it("keeps a ShowPets value that is already there (idempotent)", function()
		local d = v4Profile()
		d.Settings.ShowPets = false
		local _, data = Migrations.migrate(d)
		expect(data.Settings.ShowPets).toBe(false)
	end)
end)

describe("Migrations.run (chain mechanics)", function()
	local chain = {
		[1] = function(d: any)
			d.Added2 = true
			return d
		end,
		[2] = function(d: any)
			d.Added3 = d.Added2 and "yes" or "no"
			return d
		end,
	}

	it("applies every step from 1 to current in order", function()
		local status, data = Migrations.run({ SchemaVersion = 1 }, 3, chain)
		expect(status).toBe("ok")
		expect(data.SchemaVersion).toBe(3)
		expect(data.Added2).toBe(true)
		expect(data.Added3).toBe("yes")
	end)

	it("starts from the stored version", function()
		local status, data = Migrations.run({ SchemaVersion = 2, Added2 = false }, 3, chain)
		expect(status).toBe("ok")
		expect(data.Added3).toBe("no")
	end)

	it("reports a missing step or a failing migration as error", function()
		expect((Migrations.run({ SchemaVersion = 1 }, 4, chain))).toBe("error")
		local failing = {
			[1] = function(_d: any): any
				error("boom")
			end,
		}
		expect((Migrations.run({ SchemaVersion = 1 }, 2, failing))).toBe("error")
	end)
end)

return nil
