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
	it("current version is 1 and the template is already current", function()
		expect(Migrations.CURRENT_VERSION).toBe(1)
		local status, data = Migrations.migrate(TableUtil.deepCopy(Template))
		expect(status).toBe("ok")
		expect(data).toEqual(Template)
	end)

	it("refuses data from a newer version and leaves it untouched", function()
		local newer = TableUtil.deepCopy(Template) :: any
		newer.SchemaVersion = 2
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
