--!strict
--[[
	UIController — owns every ScreenGui and the screen registry.

	Screens are ModuleScripts under PlayerScripts.UI.Screens returning:
	  { Name: string, Layer: "Background"|"HUD"|"Menu"|"Modal"|"Overlay", Exclusive: boolean?,
	    Init: (api) -> (), Open: ((args: any?) -> ())?, Close: (() -> ())?, IsOpen: (() -> boolean)? }
	They are discovered automatically: adding a screen never requires editing this controller.

	API (UIController / passed to Init):
	  Gui(layer) -> ScreenGui · Open(name, args?) · Close(name) · Toggle(name, args?)
	  IsOpen(name) · CloseMenus() · Notify(text, kind?) · Confirm(text, onYes) · SetHUDVisible(bool)
	  Opened / Closed signals (name)
	Exclusive (Menu-layer) screens close each other; Escape closes the top menu.
]]

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Signal = require(ReplicatedStorage.Shared.Core.Signal)
local Components = require(script.Parent.Parent.UI.Components)
local Theme = require(script.Parent.Parent.UI.Theme)

type Screen = {
	Name: string,
	Layer: string,
	Exclusive: boolean?,
	Init: (any) -> (),
	Open: ((any?) -> ())?,
	Close: (() -> ())?,
	IsOpen: (() -> boolean)?,
}

local LAYERS = { Background = 1, HUD = 10, Menu = 20, Modal = 30, Overlay = 40 }

local UIController = {
	Priority = 50,
	Opened = Signal.new() :: Signal.Signal<string>,
	Closed = Signal.new() :: Signal.Signal<string>,
}

local guis: { [string]: ScreenGui } = {}
local screens: { [string]: Screen } = {}
local openState: { [string]: boolean } = {}
local menuStack: { string } = {}
local player = Players.LocalPlayer

local function applyScale(gui: ScreenGui)
	local scale = gui:FindFirstChildOfClass("UIScale") or Instance.new("UIScale")
	scale.Parent = gui
	local function update()
		local camera = Workspace.CurrentCamera
		local viewport = if camera then camera.ViewportSize else Vector2.new(1600, 900)
		local factor = math.min(viewport.X / 1600, viewport.Y / 900)
		-- phones get a floor so text stays readable; large monitors cap at 1.25
		local isTouch = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
		scale.Scale = math.clamp(factor, if isTouch then 0.62 else 0.7, 1.25)
	end
	update()
	local camera = Workspace.CurrentCamera
	if camera then
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(update)
	end
end

function UIController:Gui(layer: string): ScreenGui
	local gui = guis[layer]
	if gui then
		return gui
	end
	local created = Instance.new("ScreenGui")
	created.Name = `ROE_{layer}`
	created.ResetOnSpawn = false
	created.IgnoreGuiInset = true
	created.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	created.DisplayOrder = LAYERS[layer] or 10
	created.Parent = player:WaitForChild("PlayerGui")
	applyScale(created)
	guis[layer] = created
	return created
end

function UIController:IsOpen(name: string): boolean
	local screen = screens[name]
	if screen and screen.IsOpen then
		return screen.IsOpen()
	end
	return openState[name] == true
end

function UIController:Close(name: string)
	local screen = screens[name]
	if not screen or not self:IsOpen(name) then
		return
	end
	if screen.Close then
		screen.Close()
	end
	openState[name] = false
	local index = table.find(menuStack, name)
	if index then
		table.remove(menuStack, index)
	end
	self.Closed:Fire(name)
end

function UIController:Open(name: string, args: any?)
	local screen = screens[name]
	if not screen then
		warn(`[UI] unknown screen {name}`)
		return
	end
	if screen.Exclusive then
		for _, other in table.clone(menuStack) do
			if other ~= name then
				self:Close(other)
			end
		end
	end
	if screen.Open then
		screen.Open(args)
	end
	openState[name] = true
	if screen.Layer == "Menu" or screen.Layer == "Modal" then
		if not table.find(menuStack, name) then
			table.insert(menuStack, name)
		end
	end
	self.Opened:Fire(name)
end

function UIController:Toggle(name: string, args: any?)
	if self:IsOpen(name) then
		self:Close(name)
	else
		self:Open(name, args)
	end
end

function UIController:CloseMenus()
	for _, name in table.clone(menuStack) do
		self:Close(name)
	end
end

function UIController:AnyMenuOpen(): boolean
	return #menuStack > 0
end

-- Escape: close the most recent menu; returns true if something was closed.
function UIController:Back(): boolean
	local top = menuStack[#menuStack]
	if top then
		self:Close(top)
		return true
	end
	return false
end

function UIController:SetHUDVisible(visible: boolean)
	local hud = guis.HUD
	if hud then
		hud.Enabled = visible
	end
end

-- Toast notifications (top-centre). kind: "Info" | "Success" | "Warning" | "Error" | "Quest" | "Loot"
local toastHolder: Frame? = nil
function UIController:Notify(text: string, kind: string?)
	local gui = self:Gui("Overlay")
	if not toastHolder then
		local holder = Components.Make("Frame", {
			Name = "Toasts",
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, 96),
			Size = UDim2.fromOffset(520, 300),
			Parent = gui,
		})
		Components.Make("UIListLayout", {
			Padding = UDim.new(0, 6),
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Parent = holder,
		})
		toastHolder = holder
	end
	local colors = {
		Info = Theme.Colors.SilverBright,
		Success = Theme.Colors.GreenBright,
		Warning = Theme.Colors.GoldBright,
		Error = Theme.Colors.DangerBright,
		Quest = Theme.Colors.GoldBright,
		Loot = Theme.Colors.GoldBright,
	}
	local toast = Components.Panel({
		Parent = toastHolder,
		Size = UDim2.fromOffset(460, 40),
		StrokeColor = colors[kind or "Info"] or Theme.Colors.SilverDim,
	})
	toast.AutomaticSize = Enum.AutomaticSize.Y
	toast.BackgroundTransparency = 1
	Components.Padding(toast, 10)
	local label = Components.Label({
		Parent = toast,
		Text = text,
		TextSize = 16,
		Color = colors[kind or "Info"],
		AlignX = Enum.TextXAlignment.Center,
		AutomaticSize = Enum.AutomaticSize.Y,
		Size = UDim2.new(1, 0, 0, 0),
		Font = Theme.Fonts.UiBold,
	})
	label.TextTransparency = 1
	Components.Tween(toast, Theme.Tween.Normal, { BackgroundTransparency = 0.1 })
	Components.Tween(label, Theme.Tween.Normal, { TextTransparency = 0 })
	task.delay(3.6, function()
		Components.Tween(toast, Theme.Tween.Slow, { BackgroundTransparency = 1 })
		Components.Tween(label, Theme.Tween.Slow, { TextTransparency = 1 })
		task.wait(0.5)
		toast:Destroy()
	end)
end

-- Confirmation modal (destroying rare items, deleting characters...).
function UIController:Confirm(text: string, onYes: () -> (), yesLabel: string?)
	local gui = self:Gui("Modal")
	local shade = Components.Make("TextButton", {
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = Theme.Colors.Overlay,
		BackgroundTransparency = 0.35,
		Size = UDim2.fromScale(1, 1),
		Parent = gui,
	})
	local window = Components.Panel({
		Parent = shade,
		Size = UDim2.fromOffset(460, 210),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		StrokeColor = Theme.Colors.GoldDim,
	})
	Components.Padding(window, 20)
	Components.Label({
		Parent = window,
		Text = text,
		Size = UDim2.new(1, 0, 1, -60),
		AlignX = Enum.TextXAlignment.Center,
	})
	Components.Button({
		Parent = window,
		Text = yesLabel or "Подтвердить",
		Style = "Danger",
		Size = UDim2.fromOffset(190, 42),
		Position = UDim2.new(0, 0, 1, -42),
	}, function()
		shade:Destroy()
		onYes()
	end)
	Components.Button({
		Parent = window,
		Text = "Отмена",
		Style = "Secondary",
		Size = UDim2.fromOffset(190, 42),
		Position = UDim2.new(1, -190, 1, -42),
	}, function()
		shade:Destroy()
	end)
end

function UIController:Init()
	GuiService.AutoSelectGuiEnabled = false
	local folder = script.Parent.Parent.UI:FindFirstChild("Screens")
	if not folder then
		return
	end
	local modules = {}
	for _, child in folder:GetDescendants() do
		if child:IsA("ModuleScript") then
			table.insert(modules, child)
		end
	end
	for _, module in modules do
		local ok, screen = pcall(require, module)
		if ok and type(screen) == "table" and type(screen.Name) == "string" then
			screens[screen.Name] = screen
		else
			warn(`[UI] failed to load screen {module.Name}: {screen}`)
		end
	end
end

function UIController:Start()
	for name, screen in screens do
		task.spawn(function()
			local ok, err: any = pcall(function()
				screen.Init(UIController)
			end)
			if not ok then
				warn(`[UI] {name}.Init failed: {err}`)
			end
		end)
	end
end

return UIController
