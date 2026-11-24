--!strict
-- Background music: one calm looping track (assets/audio/music.wav, composed and rendered by
-- tools/gen_music.py: own work, no samples or third-party audio). It plays through the "Music"
-- SoundGroup, so the music volume in Settings applies. While `asset` is "" nothing plays.

local Music = table.freeze({
	-- "rbxassetid://<id>" once the file is uploaded as an Audio asset.
	asset = "rbxassetid://122894863225960",
	-- Volume of the track itself (the player's Settings volume scales it further).
	volume = 0.55,
	-- Seconds of fade-in when the game starts.
	fadeInSec = 4,
})

return Music
