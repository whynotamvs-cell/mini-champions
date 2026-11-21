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

		-- Server -> Client
		DataSnapshot = "Event" :: RemoteKind, -- (snapshot: ClientSnapshot)
		DashEvent = "Event" :: RemoteKind, -- (event: { kind: string, ... })
		Notify = "Event" :: RemoteKind, -- (key: string, args: { [string]: string | number }?)
	}),
})

return Remotes
