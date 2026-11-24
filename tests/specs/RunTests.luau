--!strict
-- Runs the specs inside Studio with Jest-Lua. Requires the FFlagEnableLoadModule Studio flag
-- (see README, "Tests"). Usage, in the Studio command bar while a Play session is running
-- on the server view:
--     require(game.ServerStorage.Tests.RunTests)()
-- The same specs run outside Studio with: lune run tests/lune/run.luau

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

return function(): boolean
	local DevPackages = ReplicatedStorage:FindFirstChild("DevPackages")
	assert(DevPackages, "DevPackages missing: run `wally install` and restart rojo serve")
	local Jest = (require :: any)(DevPackages:WaitForChild("Jest"))
	local tests = ServerStorage:WaitForChild("Tests")
	local status, result = Jest.runCLI(tests, { verbose = false, ci = false }, { tests }):awaitStatus()
	if status == "Rejected" then
		warn("[RunTests] Jest failed to run:", result)
		return false
	end
	local results = result.results
	print(`[RunTests] {results.numPassedTests} passed, {results.numFailedTests} failed`)
	return results.numFailedTests == 0 and results.numRuntimeErrorTestSuites == 0
end
