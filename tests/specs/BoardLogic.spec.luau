--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect

local BoardLogic = require(ServerScriptService.Server.Services.Logic.BoardLogic)

local function fresh(): { BoardLogic.Entry }
	return {}
end

describe("BoardLogic.record", function()
	it("sorts fastest first", function()
		local board = fresh()
		BoardLogic.record(board, 1, "A", 50_000, "Gold")
		BoardLogic.record(board, 2, "B", 40_000, "Gold")
		BoardLogic.record(board, 3, "C", 60_000, "Silver")
		expect(board[1].userId).toBe(2)
		expect(board[2].userId).toBe(1)
		expect(board[3].userId).toBe(3)
	end)

	it("keeps one row per player with their best time", function()
		local board = fresh()
		BoardLogic.record(board, 1, "A", 50_000, "Gold")
		expect(BoardLogic.record(board, 1, "A", 55_000, "Gold")).toBe(false) -- slower: ignored
		expect(BoardLogic.record(board, 1, "A", 45_000, "Gold")).toBe(true) -- faster: replaces
		expect(#board).toBe(1)
		expect(board[1].timeMs).toBe(45_000)
	end)

	it("ties keep the earlier finisher first", function()
		local board = fresh()
		BoardLogic.record(board, 1, "A", 50_000, "Gold")
		BoardLogic.record(board, 2, "B", 50_000, "Gold")
		expect(board[1].userId).toBe(1)
		expect(board[2].userId).toBe(2)
	end)

	it("holds at most 5 rows and drops the slowest", function()
		local board = fresh()
		for i = 1, 7 do
			BoardLogic.record(board, i, `P{i}`, 40_000 + i * 1_000, "Bronze")
		end
		expect(#board).toBe(5)
		expect(board[5].userId).toBe(5)
		-- slower than everyone on a full board: does not get on
		expect(BoardLogic.record(board, 99, "Slow", 200_000, "Bronze")).toBe(false)
		-- faster: pushes the last one out
		expect(BoardLogic.record(board, 100, "Fast", 10_000, "Gold")).toBe(true)
		expect(#board).toBe(5)
		expect(board[1].userId).toBe(100)
		expect(board[5].userId).toBe(4)
	end)

	it("rejects NaN, infinity, zero and negative times", function()
		local board = fresh()
		for _, bad in { 0 / 0, math.huge, -math.huge, 0, -5 } do
			expect(BoardLogic.record(board, 1, "A", bad, "Gold")).toBe(false)
		end
		expect(#board).toBe(0)
	end)

	it("shortens long names and never stores invalid utf8", function()
		local board = fresh()
		BoardLogic.record(board, 1, ("x"):rep(100), 50_000, "Gold")
		expect(#board[1].name).toBe(24)
		BoardLogic.record(board, 2, ("я"):rep(30), 51_000, "Gold") -- 2 bytes per character
		expect(utf8.len(board[2].name)).toBe(24)
	end)
end)

describe("BoardLogic.snapshot", function()
	it("returns an independent copy", function()
		local board = fresh()
		BoardLogic.record(board, 1, "A", 50_000, "Gold")
		local copy = BoardLogic.snapshot(board)
		copy[1].timeMs = 1
		expect(board[1].timeMs).toBe(50_000)
	end)
end)
