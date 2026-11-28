--!strict
-- Pets screen: buy a pet with Stars at a fixed price, equip it or take it off. Sends only intents
-- ("buy X", "equip X"); the server checks ownership and the balance (docs/ECONOMY.md 10).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Pets = require(ReplicatedStorage.Shared.Config.Pets)
local Components = require(script.Parent.Parent.UI.Components)
local Juice = require(script.Parent.Parent.UI.Juice)
local PetModel = require(script.Parent.Parent.UI.PetModel)
local Net = require(script.Parent.Parent.Net)
local DataController = require(script.Parent.DataController)
local LocalizationController = require(script.Parent.LocalizationController)
local UIController = require(script.Parent.UIController)

local L = LocalizationController.L
local STAR = Components.STAR

local PetsMenuController = {}

type Ui = {
	open: TextButton,
	frame: Frame,
	title: TextLabel,
	note: TextLabel,
	close: TextButton,
}

local ROW_HEIGHT = 54

local ui: Ui? = nil
local rows: { [string]: { name: TextLabel, action: TextButton } } = {}
local pending = false
local previews: { PetModel.Built } = {}

local function snapshot()
	return DataController:Get()
end

local function nameOf(pet: Pets.Pet): string
	return L("Pets.Row", { name = L(`Pets.Item.{pet.Id}.Name`), bonus = pet.BonusPct })
end

-- Text, enabled and handler of an action button right now.
local function actionFor(pet: Pets.Pet, data: any): (string, boolean, () -> ())
	local pets = if data then data.Pets else nil
	if pets and pets.Owned[pet.Id] then
		local equipped = pets.Equipped == pet.Id
		return L(if equipped then "Pets.Equipped" else "Pets.Equip"),
			true,
			function()
				Net.fireServer("EquipPet", if equipped then Pets.ClearId else pet.Id)
			end
	end
	local affordable = data ~= nil and data.Stars >= pet.Price
	return `{STAR} {pet.Price}`,
		affordable and not pending,
		function()
			if pending then
				return
			end
			pending = true
			task.spawn(function()
				local ok, response = pcall(Net.invokeServer, "PurchasePet", pet.Id)
				pending = false
				if ok and type(response) == "table" and response.ok == true then
					UIController:Toast("Pets.Bought", { name = L(`Pets.Item.{pet.Id}.Name`) })
				elseif ok and type(response) == "table" and response.reason == "no_stars" then
					UIController:Toast("Pets.NoStars")
				else
					UIController:Toast("Error.PurchaseFailed")
				end
			end)
		end
end

local function render()
	local u = ui
	if u == nil then
		return
	end
	local data = snapshot()
	u.open.Text = L("Pets.Button")
	u.title.Text = L("Pets.Title")
	u.note.Text = L("Pets.Note")
	u.close.Text = L("UI.Close")
	for _, pet in Pets.Items do
		local row = rows[pet.Id]
		if row then
			row.name.Text = nameOf(pet)
			local text, enabled = actionFor(pet, data)
			row.action.Text = text
			Components.setEnabled(row.action, enabled)
		end
	end
end

local function buildRow(list: ScrollingFrame, pet: Pets.Pet, order: number)
	local frame = Components.panel({
		Name = pet.Id,
		Size = UDim2.new(1, -8, 0, ROW_HEIGHT),
		LayoutOrder = order,
		BackgroundColor3 = Components.Theme.PanelDark,
		ZIndex = 41,
		Parent = list,
	})
	-- A small 3D preview that turns slowly, so a pet is recognisable before buying it.
	local viewport = Instance.new("ViewportFrame")
	viewport.Size = UDim2.fromOffset(58, 46)
	viewport.Position = UDim2.fromOffset(6, 4)
	viewport.BackgroundColor3 = Components.Theme.Panel
	viewport.BackgroundTransparency = 0.3
	viewport.Ambient = Color3.fromRGB(150, 150, 160)
	viewport.LightColor = Color3.fromRGB(255, 255, 255)
	viewport.LightDirection = Vector3.new(-0.4, -0.7, 0.5)
	viewport.ZIndex = 42
	viewport.Parent = frame
	local vpCorner = Instance.new("UICorner")
	vpCorner.CornerRadius = UDim.new(0, 10)
	vpCorner.Parent = viewport
	local built = PetModel.build(pet, viewport)
	local camera = Instance.new("Camera")
	camera.FieldOfView = 45
	camera.CFrame = CFrame.lookAt(Vector3.new(0, 1.1, -6.3 * pet.Size), Vector3.new(0, 0.5, 0))
	camera.Parent = viewport
	viewport.CurrentCamera = camera
	table.insert(previews, built)
	local name = Components.label({
		Size = UDim2.new(1, -220, 1, -10),
		Position = UDim2.fromOffset(72, 5),
		TextXAlignment = Enum.TextXAlignment.Left,
		MaxTextSize = 22,
		ZIndex = 42,
		Parent = frame,
	})
	local action = Components.button({
		Size = UDim2.fromOffset(130, 42),
		Position = UDim2.new(1, -8, 0.5, 0),
		AnchorPoint = Vector2.new(1, 0.5),
		MaxTextSize = 20,
		ZIndex = 42,
		Parent = frame,
	}, function()
		local _, enabled, run = actionFor(pet, snapshot())
		if enabled then
			run()
		end
	end)
	rows[pet.Id] = { name = name, action = action }
end

local function build(canvas: Frame): Ui
	local open = Components.button({
		Name = "PetsButton",
		Size = UDim2.fromOffset(120, 52),
		Position = UDim2.new(0, 12, 1, -72),
		AnchorPoint = Vector2.new(0, 1),
		BackgroundColor3 = Components.Theme.Blue,
		ZIndex = 20,
		Parent = canvas,
	}, function()
		PetsMenuController:Toggle()
	end)
	local frame = Components.panel({
		Name = "PetsMenu",
		Size = UDim2.fromOffset(500, 340),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Visible = false,
		ZIndex = 40,
		Parent = canvas,
	})
	local title = Components.label({
		Size = UDim2.new(1, -24, 0, 34),
		Position = UDim2.fromOffset(12, 8),
		MaxTextSize = 30,
		ZIndex = 41,
		Parent = frame,
	})
	local note = Components.label({
		Size = UDim2.new(1, -24, 0, 30),
		Position = UDim2.fromOffset(12, 44),
		MaxTextSize = 16,
		ZIndex = 41,
		Parent = frame,
	})
	local list = Instance.new("ScrollingFrame")
	list.Name = "Items"
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.Size = UDim2.new(1, -24, 1, -150)
	list.Position = UDim2.fromOffset(12, 80)
	list.CanvasSize = UDim2.new(0, 0, 0, 0)
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.ScrollBarThickness = 6
	list.ZIndex = 41
	list.Parent = frame
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 6)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = list
	local close = Components.button({
		Size = UDim2.fromOffset(160, 52),
		Position = UDim2.new(0.5, 0, 1, -10),
		AnchorPoint = Vector2.new(0.5, 1),
		BackgroundColor3 = Components.Theme.Muted,
		ZIndex = 41,
		Parent = frame,
	}, function()
		frame.Visible = false
	end)
	for order, pet in Pets.Items do
		buildRow(list, pet, order)
	end
	return { open = open, frame = frame, title = title, note = note, close = close }
end

function PetsMenuController:Init()
	DataController.Changed:Connect(render)
	LocalizationController.Changed:Connect(render)
end

function PetsMenuController:Start()
	ui = build(UIController:GetCanvas())
	render()
	-- Turn the previews, only while the screen is open.
	RunService.RenderStepped:Connect(function()
		local u = ui
		if u == nil or not u.frame.Visible then
			return
		end
		local t = os.clock()
		for _, built in previews do
			PetModel.place(
				built,
				CFrame.Angles(0, math.sin(t * 1.2) * 0.9 + t * 0.4, 0),
				t,
				{ moving = true, air = false, joy = false }
			)
		end
	end)
end

function PetsMenuController:Toggle()
	local u = ui
	if u then
		u.frame.Visible = not u.frame.Visible
		if u.frame.Visible then
			Juice.pop(u.frame, 0.85, 0.3)
		end
		render()
	end
end

return PetsMenuController
