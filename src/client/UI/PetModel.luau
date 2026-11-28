--!strict
-- Builds and animates a desk pet from Config.Pets out of simple parts. Used for the pets that follow
-- players (PetController) and for the 3D previews in the Pets screen (PetsMenuController).
-- Display only. Parts are anchored; the caller moves the whole pet with PetModel.place.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Pets = require(ReplicatedStorage.Shared.Config.Pets)

local PetModel = {}

export type Entry = { part: Part, offset: CFrame, role: string }

export type Built = {
	model: Model,
	entries: { Entry },
	body: Part,
	height: number, -- rough top of the pet above its centre, for name tags
}

export type State = {
	moving: boolean,
	air: boolean,
	joy: boolean,
}

local function block(model: Model, name: string, size: Vector3, color: Color3, material: Enum.Material?): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = model
	return part
end

local function ball(model: Model, name: string, diameter: number, color: Color3, material: Enum.Material?): Part
	local part = block(model, name, Vector3.new(diameter, diameter, diameter), color, material)
	part.Shape = Enum.PartType.Ball
	return part
end

-- Builds the pet under `parent` (a Workspace folder or a ViewportFrame). The pet faces -Z.
function PetModel.build(pet: Pets.Pet, parent: Instance): Built
	local model = Instance.new("Model")
	model.Name = `Pet_{pet.Id}`
	local c = Color3.fromRGB(pet.Color[1], pet.Color[2], pet.Color[3])
	local dark = Color3.fromRGB(pet.Color[1] * 0.55, pet.Color[2] * 0.55, pet.Color[3] * 0.55)
	local light = Color3.fromRGB(
		math.min(255, pet.Color[1] + 50),
		math.min(255, pet.Color[2] + 50),
		math.min(255, pet.Color[3] + 50)
	)
	local s = pet.Size * 1.1
	local body = ball(model, "Body", 2.4 * s, c)
	model.PrimaryPart = body
	local entries: { Entry } = { { part = body, offset = CFrame.new(), role = "Body" } }
	local function add(part: Part, offset: CFrame, role: string)
		table.insert(entries, { part = part, offset = offset, role = role })
	end

	-- A lighter belly, big shiny eyes, rosy cheeks and a smile: the cute baseline of every pet.
	add(ball(model, "Belly", 1.5 * s, light), CFrame.new(0, -0.45 * s, -0.7 * s), "Body")
	for _, x in { -0.5, 0.5 } do
		add(ball(model, "Eye", 0.8 * s, Color3.new(1, 1, 1)), CFrame.new(x * s, 0.3 * s, -1.0 * s), "Eye")
		add(ball(model, "Pupil", 0.46 * s, Color3.fromRGB(20, 20, 40)), CFrame.new(x * s, 0.28 * s, -1.28 * s), "Eye")
		add(ball(model, "Shine", 0.16 * s, Color3.new(1, 1, 1)), CFrame.new((x + 0.1) * s, 0.45 * s, -1.46 * s), "Eye")
		add(
			ball(model, "Cheek", 0.42 * s, Color3.fromRGB(255, 140, 160)),
			CFrame.new(x * 1.1 * s, -0.25 * s, -0.98 * s),
			"Body"
		)
	end
	add(
		block(model, "Mouth", Vector3.new(0.5, 0.1, 0.1) * s, Color3.fromRGB(60, 30, 40)),
		CFrame.new(0, -0.3 * s, -1.2 * s),
		"Body"
	)

	local kind = pet.Kind
	if kind == "bunny" then
		for _, x in { -0.55, 0.55 } do
			add(
				block(model, "Ear", Vector3.new(0.6, 2.0, 0.45) * s, c),
				CFrame.new(x * s, 1.9 * s, 0) * CFrame.Angles(0, 0, math.rad(-x * 14)),
				"Ear"
			)
			add(
				block(model, "EarIn", Vector3.new(0.3, 1.5, 0.1) * s, Color3.fromRGB(255, 190, 205)),
				CFrame.new(x * s, 1.9 * s, -0.25 * s) * CFrame.Angles(0, 0, math.rad(-x * 14)),
				"Ear"
			)
		end
		add(ball(model, "Tail", 0.8 * s, Color3.new(1, 1, 1)), CFrame.new(0, -0.3 * s, 1.35 * s), "Tail")
	elseif kind == "pup" then
		for _, x in { -1, 1 } do
			add(
				block(model, "Ear", Vector3.new(0.6, 1.3, 0.8) * s, dark),
				CFrame.new(x * 1.2 * s, 0.8 * s, 0) * CFrame.Angles(0, 0, math.rad(x * 20)),
				"Ear"
			)
		end
		add(ball(model, "Nose", 0.55 * s, Color3.fromRGB(30, 30, 40)), CFrame.new(0, -0.05 * s, -1.3 * s), "Body")
		add(
			block(model, "Tail", Vector3.new(0.4, 0.4, 1.4) * s, c),
			CFrame.new(0, 0.2 * s, 1.5 * s) * CFrame.Angles(math.rad(25), 0, 0),
			"Tail"
		)
	elseif kind == "cat" then
		for _, x in { -0.7, 0.7 } do
			add(
				block(model, "Ear", Vector3.new(0.7, 1.0, 0.35) * s, c),
				CFrame.new(x * s, 1.35 * s, 0) * CFrame.Angles(0, 0, math.rad(-x * 25)),
				"Ear"
			)
		end
		for _, x in { -1, 1 } do
			for dz = -1, 1, 2 do
				add(
					block(model, "Whisker", Vector3.new(0.9, 0.05, 0.05) * s, Color3.fromRGB(240, 240, 240)),
					CFrame.new(x * 1.5 * s, -0.2 * s, -0.9 * s) * CFrame.Angles(0, 0, math.rad(dz * 8)),
					"Body"
				)
			end
		end
		add(
			block(model, "Tail", Vector3.new(0.4, 1.7, 0.4) * s, dark),
			CFrame.new(0, 0.4 * s, 1.5 * s) * CFrame.Angles(math.rad(-30), 0, 0),
			"Tail"
		)
	elseif kind == "dino" then
		for i = 1, 3 do
			add(
				block(model, "Spike", Vector3.new(0.4, 0.9, 0.6) * s, dark),
				CFrame.new(0, (1.2 - (i - 1) * 0.15) * s, (0.2 + (i - 1) * 0.5) * s),
				"Spike"
			)
		end
		add(block(model, "Tail", Vector3.new(0.8, 0.8, 1.6) * s, c), CFrame.new(0, -0.4 * s, 1.8 * s), "Tail")
		add(block(model, "Snout", Vector3.new(1.0, 0.7, 0.7) * s, light), CFrame.new(0, -0.1 * s, -1.4 * s), "Body")
	elseif kind == "bug" then
		for _, x in { -0.45, 0.45 } do
			add(
				block(model, "Antenna", Vector3.new(0.14, 1.5, 0.14) * s, dark),
				CFrame.new(x * s, 1.5 * s, -0.2 * s) * CFrame.Angles(0, 0, math.rad(-x * 40)),
				"Ear"
			)
			add(
				ball(model, "AntennaTip", 0.3 * s, Color3.fromRGB(255, 110, 120)),
				CFrame.new(x * 1.35 * s, 2.15 * s, -0.2 * s),
				"Ear"
			)
		end
		for _, x in { -1, 1 } do
			add(
				block(model, "Wing", Vector3.new(1.2, 0.1, 0.9) * s, Color3.fromRGB(210, 235, 255)),
				CFrame.new(x * 1.4 * s, 0.7 * s, 0.6 * s) * CFrame.Angles(0, math.rad(x * 25), math.rad(-x * 15)),
				"Wing"
			)
		end
	elseif kind == "dragon" then
		for _, x in { -0.65, 0.65 } do
			add(
				block(model, "Horn", Vector3.new(0.4, 1.1, 0.4) * s, Color3.fromRGB(255, 225, 130)),
				CFrame.new(x * s, 1.4 * s, -0.1 * s) * CFrame.Angles(0, 0, math.rad(-x * 22)),
				"Ear"
			)
			add(
				block(model, "Wing", Vector3.new(2.0, 0.15, 1.5) * s, dark),
				CFrame.new(x * 2.3 * s, 0.6 * s, 0.5 * s) * CFrame.Angles(0, math.rad(x * 25), math.rad(-x * 20)),
				"Wing"
			)
		end
		add(block(model, "Tail", Vector3.new(0.6, 0.6, 1.8) * s, c), CFrame.new(0, -0.5 * s, 1.8 * s), "Tail")
	end

	model.Parent = parent
	return { model = model, entries = entries, body = body, height = 2.4 * s }
end

-- Puts the pet at `base` and animates it for time `t`: tail wag, ear/antenna flutter, wing flaps.
function PetModel.place(built: Built, base: CFrame, t: number, state: State)
	local wagSpeed = if state.joy then 22 elseif state.moving then 14 else 5
	local wagSize = if state.joy then 0.9 elseif state.moving then 0.55 else 0.25
	for i, entry in built.entries do
		local role = entry.role
		local local_t = CFrame.new()
		if role == "Tail" then
			local_t = CFrame.Angles(0, math.sin(t * wagSpeed) * wagSize, 0)
		elseif role == "Ear" then
			local flutter = if state.moving or state.joy then 0.18 else 0.05
			local_t = CFrame.Angles(math.sin(t * 6 + i) * flutter, 0, 0)
		elseif role == "Wing" then
			local side = if entry.offset.X >= 0 then 1 else -1
			local flap = if state.air or state.joy then 0.7 else 0.12
			local_t = CFrame.Angles(0, 0, side * math.sin(t * (if state.air or state.joy then 20 else 4)) * flap)
		end
		entry.part.CFrame = base * entry.offset * local_t
	end
end

return PetModel
