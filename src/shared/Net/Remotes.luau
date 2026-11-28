--!strict
-- Manifest of every remote (docs/ARCHITECTURE.md 6.1). The server creates them in
-- ReplicatedStorage.Remotes during Init(); the client only looks them up.

export type RemoteKind = "Event" | "Function"

local Remotes = table.freeze({
	FolderName = "Remotes",

	Definitions = table.freeze({
		-- Client -> Server (intents only, never results)
		PurchaseUpgrade = "Function" :: RemoteKind, -- (index: number) -> PurchaseResult
		RequestRestart = "Event" :: RemoteKind, -- ()
		RequestSnapshot = "Event" :: RemoteKind, -- (); client asks for the first snapshot once its listeners exist
		TutorialAck = "Event" :: RemoteKind, -- (step: number); only step 3 "opened the club menu" is accepted
		RequestBoard = "Event" :: RemoteKind, -- (); client asks for the current results board
		SendEmote = "Event" :: RemoteKind, -- (emoteId: string)
		UpdateSettings = "Event" :: RemoteKind, -- (changes: { MusicVolume?, SfxVolume?, Language?, ReducedMotion? })
		PurchasePet = "Function" :: RemoteKind, -- (petId: string) -> { ok: boolean, reason: string? }
		EquipPet = "Event" :: RemoteKind, -- (petId: string); an owned pet id or "none"
		UseSkip = "Event" :: RemoteKind, -- (); spends a skip token during a run (the run then earns nothing)
		SetSpring = "Event" :: RemoteKind, -- (on: boolean); Spring Boots owners only
		EquipCosmetic = "Event" :: RemoteKind, -- (id: string); an owned trail/finish effect id, or none_trail / none_finish

		-- Server -> Client
		DataSnapshot = "Event" :: RemoteKind, -- (snapshot: ClientSnapshot)
		DashEvent = "Event" :: RemoteKind, -- (event: { kind: string, ... })
		Notify = "Event" :: RemoteKind, -- (key: string, args: { [string]: string | number }?)
		EmoteShown = "Event" :: RemoteKind, -- (userId: number, emoteId: string)
		BoardUpdate = "Event" :: RemoteKind, -- (trackId: string, entries: { { userId, name, timeMs, medal } }) fastest first
	}),
})

return Remotes
