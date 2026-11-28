--!strict
-- Builds and animates a desk pet from Config.Pets out of simple parts. Style: a soft rounded cube body,
-- big glossy eyes with highlights, rosy cheeks, a tiny mouth, little feet and a species detail (ears,
-- horns, wings, tail). Used for the pets that follow players (PetController) and for the 3D previews
-- in the Pets screen (PetsMenuController). Display only; parts are anchored and moved by PetModel.place.
-- The look is our own: only the general "cute cube pet" genre style is shared with other games.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Pets = require(ReplicatedStorage.Shared.Config.Pets)

local PetModel = {}

export type Entry = { part: Part, offset: CFrame, role: string }

export type Built = {
	model: Model,
	entries: { Entry },
	body: Part,
	height: number, -- top of the pet above its centre, for name tags
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

local function ball(model: Model, name: string, diameter: number, color: Color3): Part
	local part = block(model, name, Vector3.new(diameter, diameter, diameter), color)
	part.Shape = Enum.PartType.Ball
	return part
end

-- A flat round disk (axis X) used on the front face: eyes, shines, cheeks, nose.
local function disk(model: Model, name: string, diameter: number, color: Color3): Part
	local part = block(model, name, Vector3.new(0.04, diameter, diameter), color)
	part.Shape = Enum.PartType.Cylinder
	return part
end

local FRONT = CFrame.Angles(0, math.rad(90), 0) -- turns a disk to face -Z

local function shade(c: { number }, f: number): Color3
	return Color3.fromRGB(math.min(255, c[1] * f), math.min(255, c[2] * f), math.min(255, c[3] * f))
end

-- Builds the pet under `parent` (a Workspace folder or a ViewportFrame). The pet faces -Z.
function PetModel.build(pet: Pets.Pet, parent: Instance): Built
	local model = Instance.new("Model")
	model.Name = `Pet_{pet.Id}`
	local color = Color3.fromRGB(pet.Color[1], pet.Color[2], pet.Color[3])
	local dark = shade(pet.Color, 0.6)
	local light = shade(pet.Color, 1.25)
	-- Sizes differ only a little (square root) and every pet stays smaller than its owner.
	local S = 2.0 * math.sqrt(pet.Size) * 0.8 -- the cube's side
	local r = S * 0.22 -- corner radius

	local entries: { Entry } = {}
	local function add(part: Part, offset: CFrame, role: string)
		table.insert(entries, { part = part, offset = offset, role = role })
	end

	-- Rounded cube: three slabs, twelve edge rods and eight corner balls.
	local body = block(model, "Body", Vector3.new(S, S - 2 * r, S - 2 * r), color)
	model.PrimaryPart = body
	add(body, CFrame.new(), "Body")
	add(block(model, "BodyY", Vector3.new(S - 2 * r, S, S - 2 * r), color), CFrame.new(), "Body")
	add(block(model, "BodyZ", Vector3.new(S - 2 * r, S - 2 * r, S), color), CFrame.new(), "Body")
	local h = S / 2 - r
	for _, sx in { -1, 1 } do
		for _, sy in { -1, 1 } do
			for _, sz in { -1, 1 } do
				add(ball(model, "Corner", 2 * r, color), CFrame.new(sx * h, sy * h, sz * h), "Body")
			end
		end
	end
	for _, a in { -1, 1 } do
		for _, b in { -1, 1 } do
			local rodX = block(model, "EdgeX", Vector3.new(S - 2 * r, 2 * r, 2 * r), color)
			rodX.Shape = Enum.PartType.Cylinder
			add(rodX, CFrame.new(0, a * h, b * h), "Body")
			local rodY = block(model, "EdgeY", Vector3.new(S - 2 * r, 2 * r, 2 * r), color)
			rodY.Shape = Enum.PartType.Cylinder
			add(rodY, CFrame.new(a * h, 0, b * h) * CFrame.Angles(0, 0, math.rad(90)), "Body")
			local rodZ = block(model, "EdgeZ", Vector3.new(S - 2 * r, 2 * r, 2 * r), color)
			rodZ.Shape = Enum.PartType.Cylinder
			add(rodZ, CFrame.new(a * h, b * h, 0) * CFrame.Angles(0, math.rad(90), 0), "Body")
		end
	end

	-- Face on the -Z side: big dark eyes with two highlights, rosy cheeks, a tiny nose and mouth.
	local front = -S / 2 - 0.03
	for _, x in { -1, 1 } do
		add(
			disk(model, "Eye", S * 0.42, Color3.fromRGB(25, 22, 45)),
			CFrame.new(x * S * 0.24, S * 0.08, front) * FRONT,
			"Eye"
		)
		add(
			disk(model, "ShineBig", S * 0.16, Color3.new(1, 1, 1)),
			CFrame.new(x * S * 0.24 - S * 0.06, S * 0.16, front - 0.02) * FRONT,
			"Eye"
		)
		add(
			disk(model, "ShineSmall", S * 0.07, Color3.new(1, 1, 1)),
			CFrame.new(x * S * 0.24 + S * 0.07, 0, front - 0.02) * FRONT,
			"Eye"
		)
		add(
			disk(model, "Cheek", S * 0.16, Color3.fromRGB(255, 140, 165)),
			CFrame.new(x * S * 0.38, -S * 0.12, front) * FRONT,
			"Body"
		)
	end
	add(
		disk(model, "Nose", S * 0.07, Color3.fromRGB(40, 30, 45)),
		CFrame.new(0, -S * 0.06, front - 0.01) * FRONT,
		"Body"
	)
	for _, x in { -1, 1 } do
		add(
			block(model, "Smile", Vector3.new(S * 0.09, 0.04, 0.04), Color3.fromRGB(40, 30, 45)),
			CFrame.new(x * S * 0.05, -S * 0.16, front - 0.01) * CFrame.Angles(0, 0, math.rad(x * 25)),
			"Body"
		)
	end

	-- Four little feet.
	for _, x in { -1, 1 } do
		for _, z in { -1, 1 } do
			add(ball(model, "Foot", S * 0.3, dark), CFrame.new(x * S * 0.28, -S / 2 - 0.02, z * S * 0.25), "Foot")
		end
	end

	-- A pointed ear is a diamond half buried in the head.
	local function ear(name: string, x: number, size: number, col: Color3)
		add(
			block(model, name, Vector3.new(size, size, S * 0.12), col),
			CFrame.new(x * S * 0.3, S / 2 + size * 0.1, 0) * CFrame.Angles(0, 0, math.rad(45)),
			"Ear"
		)
	end

	local top = S / 2 + S * 0.3
	local kind = pet.Kind
	if kind == "bunny" then
		for _, x in { -1, 1 } do
			add(
				block(model, "Ear", Vector3.new(S * 0.2, S * 0.75, S * 0.14), color),
				CFrame.new(x * S * 0.22, S / 2 + S * 0.32, 0) * CFrame.Angles(0, 0, math.rad(-x * 8)),
				"Ear"
			)
			add(
				block(model, "EarIn", Vector3.new(S * 0.1, S * 0.55, S * 0.04), Color3.fromRGB(255, 185, 200)),
				CFrame.new(x * S * 0.22, S / 2 + S * 0.32, -S * 0.06) * CFrame.Angles(0, 0, math.rad(-x * 8)),
				"Ear"
			)
		end
		add(ball(model, "Tail", S * 0.3, Color3.new(1, 1, 1)), CFrame.new(0, -S * 0.1, S / 2 + S * 0.1), "Tail")
		top = S / 2 + S * 0.7
	elseif kind == "pup" then
		for _, x in { -1, 1 } do
			add(
				block(model, "Ear", Vector3.new(S * 0.16, S * 0.5, S * 0.3), dark),
				CFrame.new(x * (S / 2 + S * 0.06), S * 0.2, 0) * CFrame.Angles(0, 0, math.rad(x * 14)),
				"Ear"
			)
		end
		add(
			block(model, "Tongue", Vector3.new(S * 0.09, S * 0.11, 0.04), Color3.fromRGB(255, 120, 150)),
			CFrame.new(0, -S * 0.23, front - 0.01),
			"Body"
		)
		add(
			block(model, "Tail", Vector3.new(S * 0.12, S * 0.12, S * 0.4), color),
			CFrame.new(0, S * 0.1, S / 2 + S * 0.15) * CFrame.Angles(math.rad(25), 0, 0),
			"Tail"
		)
	elseif kind == "cat" then
		ear("EarL", -1, S * 0.32, color)
		ear("EarR", 1, S * 0.32, color)
		for _, x in { -1, 1 } do
			for _, dy in { -1, 0, 1 } do
				add(
					block(model, "Whisker", Vector3.new(S * 0.3, 0.03, 0.03), Color3.fromRGB(230, 230, 235)),
					CFrame.new(x * S * 0.62, -S * 0.12 + dy * S * 0.05, front)
						* CFrame.Angles(0, 0, math.rad(x * dy * 12)),
					"Body"
				)
			end
		end
		add(
			block(model, "Tail", Vector3.new(S * 0.12, S * 0.12, S * 0.5), dark),
			CFrame.new(0, -S * 0.1, S / 2 + S * 0.22) * CFrame.Angles(math.rad(-25), 0, 0),
			"Tail"
		)
		top = S / 2 + S * 0.4
	elseif kind == "dino" then
		for i = 1, 3 do
			add(
				block(model, "Spike", Vector3.new(S * 0.2, S * 0.2, S * 0.1), dark),
				CFrame.new(0, S / 2 + S * 0.04, (i - 2) * S * 0.28) * CFrame.Angles(math.rad(45), 0, 0),
				"Spike"
			)
		end
		add(
			block(model, "Tail", Vector3.new(S * 0.3, S * 0.3, S * 0.55), color),
			CFrame.new(0, -S * 0.2, S / 2 + S * 0.22),
			"Tail"
		)
		for _, x in { -1, 1 } do
			add(
				block(model, "Arm", Vector3.new(S * 0.14, S * 0.14, S * 0.34), light),
				CFrame.new(x * (S / 2 + S * 0.06), -S * 0.1, -S * 0.08) * CFrame.Angles(0, 0, math.rad(x * 14)),
				"Wing"
			)
		end
		top = S / 2 + S * 0.25
	elseif kind == "bug" then
		for _, x in { -1, 1 } do
			add(
				block(model, "Antenna", Vector3.new(S * 0.06, S * 0.5, S * 0.06), dark),
				CFrame.new(x * S * 0.22, S / 2 + S * 0.22, 0) * CFrame.Angles(0, 0, math.rad(-x * 20)),
				"Ear"
			)
			add(
				ball(model, "AntennaTip", S * 0.14, Color3.fromRGB(255, 110, 120)),
				CFrame.new(x * S * 0.3, S / 2 + S * 0.5, 0),
				"Ear"
			)
			add(
				block(model, "Wing", Vector3.new(S * 0.5, 0.05, S * 0.4), Color3.fromRGB(215, 238, 255)),
				CFrame.new(x * (S / 2 + S * 0.2), S * 0.15, S * 0.1)
					* CFrame.Angles(0, math.rad(x * 20), math.rad(-x * 18)),
				"Wing"
			)
		end
		top = S / 2 + S * 0.6
	elseif kind == "dragon" then
		for _, x in { -1, 1 } do
			add(
				block(model, "Horn", Vector3.new(S * 0.15, S * 0.3, S * 0.15), Color3.fromRGB(255, 225, 130)),
				CFrame.new(x * S * 0.28, S / 2 + S * 0.12, 0) * CFrame.Angles(0, 0, math.rad(-x * 18)),
				"Ear"
			)
			add(
				block(model, "Wing", Vector3.new(S * 0.7, 0.07, S * 0.5), dark),
				CFrame.new(x * (S / 2 + S * 0.32), S * 0.2, S * 0.1)
					* CFrame.Angles(0, math.rad(x * 22), math.rad(-x * 16)),
				"Wing"
			)
		end
		for i = 1, 3 do
			add(
				block(model, "Spike", Vector3.new(S * 0.16, S * 0.16, S * 0.1), light),
				CFrame.new(0, S / 2 + S * 0.03, (i - 2) * S * 0.26) * CFrame.Angles(math.rad(45), 0, 0),
				"Spike"
			)
		end
		add(
			block(model, "Tail", Vector3.new(S * 0.2, S * 0.2, S * 0.6), color),
			CFrame.new(0, -S * 0.2, S / 2 + S * 0.25),
			"Tail"
		)
		top = S / 2 + S * 0.35
	end

	model.Parent = parent
	return { model = model, entries = entries, body = body, height = top * 2 }
end

-- Puts the pet at `base` and animates it for time `t`: tail wag, ear flutter, wing flaps, stepping feet.
function PetModel.place(built: Built, base: CFrame, t: number, state: State)
	local wagSpeed = if state.joy then 22 elseif state.moving then 14 else 5
	local wagSize = if state.joy then 0.9 elseif state.moving then 0.55 else 0.25
	for i, entry in built.entries do
		local role = entry.role
		local localT = CFrame.new()
		if role == "Tail" then
			localT = CFrame.Angles(0, math.sin(t * wagSpeed) * wagSize, 0)
		elseif role == "Ear" then
			local flutter = if state.moving or state.joy then 0.18 else 0.05
			localT = CFrame.Angles(math.sin(t * 6 + i) * flutter, 0, 0)
		elseif role == "Wing" then
			local side = if entry.offset.X >= 0 then 1 else -1
			local flap = if state.air or state.joy then 0.7 else 0.12
			localT = CFrame.Angles(0, 0, side * math.sin(t * (if state.air or state.joy then 20 else 4)) * flap)
		elseif role == "Foot" then
			if state.moving or state.joy then
				local phase = if (entry.offset.X > 0) == (entry.offset.Z > 0) then 0 else math.pi
				localT = CFrame.new(0, math.max(0, math.sin(t * 14 + phase)) * 0.18, 0)
			end
		end
		entry.part.CFrame = base * entry.offset * localT
	end
end

return PetModel
