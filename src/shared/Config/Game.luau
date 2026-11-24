--!strict
-- Global game settings and environment flags.

local Game = table.freeze({
	MaxPlayers = 6, -- decision D2; must match the experience's server size setting
	PlotCount = 6,

	-- Private test experience (decision D3, docs/ARCHITECTURE.md 14.1)
	TestUniverseId = 10778182955,
	TestPlaceId = 137418142134310,

	-- When false, TelemetryService only prints in Studio and never calls AnalyticsService.
	TelemetryInStudio = false,

	Studio = table.freeze({
		-- Real DataStore in Studio is used only when this is true AND game.PlaceId == TestPlaceId.
		UseRealDataStore = false,
		-- Simulates a profile load failure (TEST_PLAN S-10).
		SimulateLoadFailure = false,
	}),

	LoadTimeoutSec = 30, -- client gives up waiting for the first data snapshot
})

return Game
