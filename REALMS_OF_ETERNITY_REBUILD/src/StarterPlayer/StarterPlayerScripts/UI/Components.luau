--!strict
--[[
	Components — reusable interface building blocks in the game's style.
	Every screen is built from these so the whole UI reads as one product.

	Panel, Window (animated open/close), Button (hover/press/disabled states), Label, Title,
	RuneDivider, Bar (smooth fill + damage ghost), IconSlot, Tooltip, Tabs, Toggle, Slider,
	ScrollList, Confirm modal helper.
]]

local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Theme = require(script.Parent.Theme)

local C = Theme.Colors

local Components = {}

local function make(className: string, props: { [string]: any }, children: { Instance }?): any
	local instance = Instance.new(className)
	local parent = props.Parent
	for key, value in props do
		if key ~= "Parent" then
			(instance :: any)[key] = value
		end
	end
	local list: { Instance } = children or {}
	for _, child in list do
		child.Parent = instance
	end
	if parent then
		instance.Parent = parent
	end
	return instance
end
Components.Make = make

function Components.Tween(instance: Instance, info: TweenInfo, goal: { [string]: any }): Tween
	local tween = TweenService:Create(instance, info, goal)
	tween:Play()
	return tween
end

function Components.Corner(parent: Instance, radius: UDim?): UICorner
	return make("UICorner", { CornerRadius = radius or Theme.Corner, Parent = parent })
end

function Components.Stroke(parent: Instance, color: Color3?, thickness: number?, transparency: number?): UIStroke
	return make("UIStroke", {
		Color = color or C.SilverDim,
		Thickness = thickness or 1,
		Transparency = transparency or 0.25,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Parent = parent,
	})
end

function Components.Padding(parent: Instance, px: number): UIPadding
	local u = UDim.new(0, px)
	return make("UIPadding", { PaddingTop = u, PaddingBottom = u, PaddingLeft = u, PaddingRight = u, Parent = parent })
end

-- Stone panel with subtle vertical gradient and an aged-silver hairline.
function Components.Panel(props: { [string]: any }): Frame
	local frame = make("Frame", {
		BackgroundColor3 = C.Stone800,
		BackgroundTransparency = props.Transparency or 0.06,
		BorderSizePixel = 0,
		Size = props.Size or UDim2.fromOffset(300, 200),
		Position = props.Position or UDim2.new(),
		AnchorPoint = props.AnchorPoint or Vector2.zero,
		Name = props.Name or "Panel",
		ZIndex = props.ZIndex or 1,
		Parent = props.Parent,
	})
	Components.Corner(frame, props.Corner)
	Components.Stroke(frame, props.StrokeColor or C.SilverDim, 1, 0.35)
	make("UIGradient", {
		Rotation = 90,
		Color = ColorSequence.new(C.Stone700, C.Stone900),
		Parent = frame,
	})
	return frame
end

-- Thin decorative divider: line — rune diamond — line.
function Components.RuneDivider(parent: Instance, width: UDim?, color: Color3?): Frame
	local holder = make("Frame", {
		Name = "RuneDivider",
		BackgroundTransparency = 1,
		Size = UDim2.new(width or UDim.new(1, 0), UDim.new(0, 10)),
		Parent = parent,
	})
	local tint = color or C.GoldDim
	for _, side in { -1, 1 } do
		local line = make("Frame", {
			BackgroundColor3 = tint,
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(if side < 0 then 1 else 0, 0.5),
			Position = UDim2.new(0.5, side * 9, 0.5, 0),
			Size = UDim2.new(0.5, -12, 0, 1),
			Parent = holder,
		})
		make("UIGradient", {
			Transparency = NumberSequence.new(if side < 0 then 1 else 0, if side < 0 then 0 else 1),
			Parent = line,
		})
	end
	make("Frame", {
		BackgroundColor3 = tint,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(7, 7),
		Rotation = 45,
		Parent = holder,
	})
	return holder
end

function Components.Label(props: { [string]: any }): TextLabel
	return make("TextLabel", {
		BackgroundTransparency = 1,
		FontFace = props.Font or Theme.Fonts.Body,
		TextColor3 = props.Color or C.Text,
		TextSize = props.TextSize or Theme.TextSize.Body,
		Text = props.Text or "",
		TextWrapped = props.Wrapped ~= false,
		RichText = true,
		TextXAlignment = props.AlignX or Enum.TextXAlignment.Left,
		TextYAlignment = props.AlignY or Enum.TextYAlignment.Center,
		Size = props.Size or UDim2.new(1, 0, 0, (props.TextSize or Theme.TextSize.Body) + 6),
		Position = props.Position or UDim2.new(),
		AnchorPoint = props.AnchorPoint or Vector2.zero,
		AutomaticSize = props.AutomaticSize or Enum.AutomaticSize.None,
		Name = props.Name or "Label",
		LayoutOrder = props.LayoutOrder or 0,
		ZIndex = props.ZIndex or 1,
		TextTransparency = props.TextTransparency or 0,
		Parent = props.Parent,
	})
end

function Components.Title(parent: Instance, text: string, size: number?): TextLabel
	local label = Components.Label({
		Parent = parent,
		Text = text,
		Font = Theme.Fonts.Title,
		TextSize = size or Theme.TextSize.Title,
		Color = C.GoldBright,
		AlignX = Enum.TextXAlignment.Center,
		Name = "Title",
	})
	make("UIGradient", {
		Rotation = 90,
		Color = ColorSequence.new(C.GoldBright, C.Gold),
		Parent = label,
	})
	return label
end

export type ButtonStyle = "Primary" | "Secondary" | "Danger" | "Ghost"

local BUTTON_COLORS: { [string]: { Fill: Color3, Hover: Color3, Stroke: Color3, Text: Color3 } } = {
	Primary = { Fill = C.GreenDeep, Hover = C.Green, Stroke = C.Gold, Text = C.GoldBright },
	Secondary = { Fill = C.Stone700, Hover = C.Stone600, Stroke = C.SilverDim, Text = C.Text },
	Danger = {
		Fill = Color3.fromRGB(70, 26, 24),
		Hover = Color3.fromRGB(110, 36, 32),
		Stroke = C.Danger,
		Text = C.Text,
	},
	Ghost = { Fill = C.Stone900, Hover = C.Stone700, Stroke = C.Stone500, Text = C.TextDim },
}

export type Button = TextButton & { SetEnabled: any }

-- Styled button. `onClick` fires on activation. Returns the TextButton (attribute Enabled).
function Components.Button(props: { [string]: any }, onClick: (() -> ())?): TextButton
	local style = BUTTON_COLORS[props.Style or "Secondary"]
	local button = make("TextButton", {
		AutoButtonColor = false,
		BackgroundColor3 = style.Fill,
		BorderSizePixel = 0,
		Text = "",
		Size = props.Size or UDim2.fromOffset(220, 44),
		Position = props.Position or UDim2.new(),
		AnchorPoint = props.AnchorPoint or Vector2.zero,
		LayoutOrder = props.LayoutOrder or 0,
		Name = props.Name or "Button",
		ZIndex = props.ZIndex or 1,
		Parent = props.Parent,
	})
	Components.Corner(button)
	local stroke = Components.Stroke(button, style.Stroke, 1, 0.3)
	make("UIGradient", {
		Rotation = 90,
		Transparency = NumberSequence.new(0, 0.25),
		Parent = button,
	})
	local label = Components.Label({
		Parent = button,
		Text = props.Text or "",
		Font = props.Font or Theme.Fonts.UiBold,
		TextSize = props.TextSize or Theme.TextSize.Body,
		Color = style.Text,
		AlignX = Enum.TextXAlignment.Center,
		Size = UDim2.fromScale(1, 1),
		Name = "Text",
		ZIndex = (props.ZIndex or 1) + 1,
	})
	button:SetAttribute("Enabled", props.Enabled ~= false)
	local function refresh(hover: boolean)
		local enabled = button:GetAttribute("Enabled") == true
		Components.Tween(button, Theme.Tween.Fast, {
			BackgroundColor3 = if not enabled then C.Stone800 elseif hover then style.Hover else style.Fill,
		})
		label.TextTransparency = if enabled then 0 else 0.55
		stroke.Transparency = if hover and enabled then 0 else 0.3
	end
	refresh(false)
	button.MouseEnter:Connect(function()
		refresh(true)
	end)
	button.MouseLeave:Connect(function()
		refresh(false)
	end)
	button:GetAttributeChangedSignal("Enabled"):Connect(function()
		refresh(false)
	end)
	button.MouseButton1Down:Connect(function()
		if button:GetAttribute("Enabled") then
			local size = button.Size
			Components.Tween(button, Theme.Tween.Fast, { Size = size - UDim2.fromOffset(4, 2) })
			task.delay(0.1, function()
				Components.Tween(button, Theme.Tween.Fast, { Size = size })
			end)
		end
	end)
	button.Activated:Connect(function()
		if button:GetAttribute("Enabled") and onClick then
			onClick()
		end
	end)
	return button
end

function Components.SetButtonText(button: TextButton, text: string)
	local label = button:FindFirstChild("Text") :: TextLabel?
	if label then
		label.Text = text
	end
end

export type BarHandle = {
	Frame: Frame,
	Set: (value: number, max: number, instant: boolean?) -> (),
	SetText: (text: string) -> (),
}

-- Resource bar with smooth fill and a trailing "ghost" that shows recent loss.
function Components.Bar(props: { [string]: any }): BarHandle
	local frame = make("Frame", {
		BackgroundColor3 = C.Stone900,
		BorderSizePixel = 0,
		Size = props.Size or UDim2.fromOffset(260, 18),
		Position = props.Position or UDim2.new(),
		AnchorPoint = props.AnchorPoint or Vector2.zero,
		Name = props.Name or "Bar",
		LayoutOrder = props.LayoutOrder or 0,
		Parent = props.Parent,
	})
	Components.Corner(frame, UDim.new(0, 3))
	Components.Stroke(frame, C.SilverDim, 1, 0.4)
	local ghost = make("Frame", {
		BackgroundColor3 = props.GhostColor or C.SilverBright,
		BackgroundTransparency = 0.45,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		Name = "Ghost",
		Parent = frame,
	})
	Components.Corner(ghost, UDim.new(0, 3))
	local fill = make("Frame", {
		BackgroundColor3 = props.Color or C.Health,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		Name = "Fill",
		Parent = frame,
	})
	Components.Corner(fill, UDim.new(0, 3))
	make("UIGradient", {
		Rotation = 90,
		Color = ColorSequence.new(
			props.ColorBright or (props.Color or C.Health):Lerp(Color3.new(1, 1, 1), 0.25),
			props.Color or C.Health
		),
		Parent = fill,
	})
	local text = Components.Label({
		Parent = frame,
		Text = "",
		Font = Theme.Fonts.Numbers,
		TextSize = props.TextSize or 13,
		Color = C.Text,
		AlignX = Enum.TextXAlignment.Center,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 3,
		Name = "Value",
	})
	make("UIStroke", { Thickness = 1, Color = Color3.new(0, 0, 0), Transparency = 0.4, Parent = text })
	local last = 1
	local ghostThread: thread? = nil
	local handle: BarHandle = {
		Frame = frame,
		Set = function(value: number, max: number, instant: boolean?)
			local ratio = if max > 0 then math.clamp(value / max, 0, 1) else 0
			if instant then
				fill.Size = UDim2.fromScale(ratio, 1)
				ghost.Size = UDim2.fromScale(ratio, 1)
			else
				Components.Tween(fill, Theme.Tween.Fast, { Size = UDim2.fromScale(ratio, 1) })
				if ratio < last then
					if ghostThread then
						task.cancel(ghostThread)
					end
					ghostThread = task.delay(0.45, function()
						Components.Tween(ghost, Theme.Tween.Slow, { Size = UDim2.fromScale(ratio, 1) })
					end)
				else
					ghost.Size = UDim2.fromScale(ratio, 1)
				end
			end
			last = ratio
			if props.ShowValue ~= false then
				text.Text = `{math.floor(value + 0.5)} / {math.floor(max + 0.5)}`
			end
		end,
		SetText = function(value: string)
			text.Text = value
		end,
	}
	return handle
end

-- Square slot for items/skills with rarity edge.
function Components.Slot(props: { [string]: any }): ImageButton
	local slot = make("ImageButton", {
		AutoButtonColor = false,
		BackgroundColor3 = C.Stone900,
		BorderSizePixel = 0,
		Image = "",
		Size = props.Size or UDim2.fromOffset(56, 56),
		Position = props.Position or UDim2.new(),
		LayoutOrder = props.LayoutOrder or 0,
		Name = props.Name or "Slot",
		Parent = props.Parent,
	})
	Components.Corner(slot)
	local stroke = Components.Stroke(slot, props.EdgeColor or C.Stone500, 1.5, 0)
	stroke.Name = "Edge"
	Components.Label({
		Parent = slot,
		Name = "Glyph",
		Text = props.Glyph or "",
		Font = Theme.Fonts.UiBold,
		TextSize = props.GlyphSize or 26,
		AlignX = Enum.TextXAlignment.Center,
		Size = UDim2.fromScale(1, 1),
		Color = props.GlyphColor or C.Text,
	})
	Components.Label({
		Parent = slot,
		Name = "Count",
		Text = props.Count or "",
		Font = Theme.Fonts.Numbers,
		TextSize = 13,
		AlignX = Enum.TextXAlignment.Right,
		AlignY = Enum.TextYAlignment.Bottom,
		Size = UDim2.new(1, -4, 1, -2),
		ZIndex = 3,
	})
	slot.MouseEnter:Connect(function()
		Components.Tween(slot, Theme.Tween.Fast, { BackgroundColor3 = C.Stone700 })
	end)
	slot.MouseLeave:Connect(function()
		Components.Tween(slot, Theme.Tween.Fast, { BackgroundColor3 = C.Stone900 })
	end)
	return slot
end

function Components.ScrollList(props: { [string]: any }): ScrollingFrame
	local list = make("ScrollingFrame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = props.Size or UDim2.fromScale(1, 1),
		Position = props.Position or UDim2.new(),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 4,
		ScrollBarImageColor3 = C.GoldDim,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		Name = props.Name or "List",
		Parent = props.Parent,
	})
	if props.Grid then
		make("UIGridLayout", {
			CellSize = props.CellSize or UDim2.fromOffset(56, 56),
			CellPadding = props.CellPadding or UDim2.fromOffset(6, 6),
			SortOrder = Enum.SortOrder.LayoutOrder,
			Parent = list,
		})
	else
		make(
			"UIListLayout",
			{ Padding = UDim.new(0, props.Spacing or 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = list }
		)
	end
	Components.Padding(list, props.Padding or 4)
	return list
end

-- Simple switch; returns frame and a setter.
function Components.Toggle(
	parent: Instance,
	label: string,
	value: boolean,
	onChange: (boolean) -> ()
): (Frame, (boolean) -> ())
	local row = make("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 34), Parent = parent })
	Components.Label({ Parent = row, Text = label, Size = UDim2.new(1, -70, 1, 0), Font = Theme.Fonts.Ui })
	local track = make("TextButton", {
		Text = "",
		AutoButtonColor = false,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, 0, 0.5, 0),
		Size = UDim2.fromOffset(52, 24),
		BackgroundColor3 = C.Stone600,
		Parent = row,
	})
	Components.Corner(track, UDim.new(1, 0))
	Components.Stroke(track, C.SilverDim, 1, 0.4)
	local knob = make("Frame", {
		Size = UDim2.fromOffset(18, 18),
		AnchorPoint = Vector2.new(0, 0.5),
		BackgroundColor3 = C.SilverBright,
		Parent = track,
	})
	Components.Corner(knob, UDim.new(1, 0))
	local state = value
	local function set(newValue: boolean)
		state = newValue
		Components.Tween(
			knob,
			Theme.Tween.Fast,
			{ Position = if state then UDim2.new(1, -21, 0.5, 0) else UDim2.new(0, 3, 0.5, 0) }
		)
		Components.Tween(track, Theme.Tween.Fast, { BackgroundColor3 = if state then C.Green else C.Stone600 })
	end
	set(value)
	track.Activated:Connect(function()
		set(not state)
		onChange(state)
	end)
	return row, set
end

-- Horizontal slider 0..1 (mapped by caller).
function Components.Slider(parent: Instance, label: string, value: number, onChange: (number) -> ()): Frame
	local row = make("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 44), Parent = parent })
	local title =
		Components.Label({ Parent = row, Text = label, Size = UDim2.new(1, -60, 0, 20), Font = Theme.Fonts.Ui })
	local valueLabel = Components.Label({
		Parent = row,
		Text = "",
		Size = UDim2.new(0, 60, 0, 20),
		Position = UDim2.new(1, -60, 0, 0),
		AlignX = Enum.TextXAlignment.Right,
		Font = Theme.Fonts.Numbers,
		Color = C.GoldBright,
	})
	local _ = title
	local track = make("Frame", {
		Position = UDim2.new(0, 0, 0, 28),
		Size = UDim2.new(1, 0, 0, 6),
		BackgroundColor3 = C.Stone600,
		BorderSizePixel = 0,
		Parent = row,
	})
	Components.Corner(track, UDim.new(1, 0))
	local fill = make(
		"Frame",
		{ Size = UDim2.fromScale(value, 1), BackgroundColor3 = C.Gold, BorderSizePixel = 0, Parent = track }
	)
	Components.Corner(fill, UDim.new(1, 0))
	local knob = make("TextButton", {
		Text = "",
		AutoButtonColor = false,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(value, 0, 0.5, 0),
		Size = UDim2.fromOffset(16, 16),
		BackgroundColor3 = C.GoldBright,
		Parent = track,
	})
	Components.Corner(knob, UDim.new(1, 0))
	local dragging = false
	local function setFromX(x: number)
		local ratio = math.clamp((x - track.AbsolutePosition.X) / math.max(1, track.AbsoluteSize.X), 0, 1)
		fill.Size = UDim2.fromScale(ratio, 1)
		knob.Position = UDim2.new(ratio, 0, 0.5, 0)
		valueLabel.Text = `{math.floor(ratio * 100 + 0.5)}%`
		onChange(ratio)
	end
	valueLabel.Text = `{math.floor(value * 100 + 0.5)}%`
	knob.MouseButton1Down:Connect(function()
		dragging = true
	end)
	UserInputService.InputEnded:Connect(function(input)
		if
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			dragging = false
		end
	end)
	UserInputService.InputChanged:Connect(function(input)
		if
			dragging
			and (
				input.UserInputType == Enum.UserInputType.MouseMovement
				or input.UserInputType == Enum.UserInputType.Touch
			)
		then
			setFromX(input.Position.X)
		end
	end)
	return row
end

export type WindowHandle = {
	Root: Frame,
	Body: Frame,
	Open: () -> (),
	Close: () -> (),
	IsOpen: () -> boolean,
	OnClose: (() -> ())?,
}

-- Centered window with title bar, close button and scale/fade open animation.
function Components.Window(parent: Instance, title: string, size: UDim2): WindowHandle
	local root = Components.Panel({
		Parent = parent,
		Name = "Window",
		Size = size,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Corner = Theme.CornerLarge,
		StrokeColor = C.GoldDim,
	})
	root.Visible = false
	local scale = make("UIScale", { Scale = 1, Parent = root })
	local header =
		make("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 54), Name = "Header", Parent = root })
	local titleLabel = Components.Title(header, title, Theme.TextSize.Heading)
	titleLabel.Size = UDim2.new(1, -100, 0, 34)
	titleLabel.Position = UDim2.new(0, 50, 0, 10)
	local divider = Components.RuneDivider(header, UDim.new(1, -40))
	divider.Position = UDim2.new(0, 20, 1, -8)
	local body = make("Frame", {
		BackgroundTransparency = 1,
		Position = UDim2.new(0, 18, 0, 62),
		Size = UDim2.new(1, -36, 1, -78),
		Name = "Body",
		Parent = root,
	})
	local open = false
	local handle: WindowHandle
	local close = Components.Button({
		Parent = header,
		Text = "✕",
		Style = "Ghost",
		Size = UDim2.fromOffset(34, 34),
		Position = UDim2.new(1, -46, 0, 10),
	}, function()
		handle.Close()
	end)
	close.Name = "Close"
	handle = {
		Root = root,
		Body = body,
		Open = function()
			if open then
				return
			end
			open = true
			root.Visible = true
			scale.Scale = 0.92
			root.BackgroundTransparency = 0.6
			Components.Tween(scale, Theme.Tween.Open, { Scale = 1 })
			Components.Tween(root, Theme.Tween.Normal, { BackgroundTransparency = 0.06 })
		end,
		Close = function()
			if not open then
				return
			end
			open = false
			Components.Tween(scale, Theme.Tween.Close, { Scale = 0.94 })
			local tween = Components.Tween(root, Theme.Tween.Close, { BackgroundTransparency = 1 })
			tween.Completed:Once(function()
				if not open then
					root.Visible = false
				end
			end)
			if handle.OnClose then
				handle.OnClose()
			end
		end,
		IsOpen = function()
			return open
		end,
		OnClose = nil,
	}
	return handle
end

-- Tabs row: returns container and select function; onSelect(index).
function Components.Tabs(parent: Instance, labels: { string }, onSelect: (number) -> ()): (Frame, (number) -> ())
	local row =
		make("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 34), Name = "Tabs", Parent = parent })
	make("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = row,
	})
	local buttons: { TextButton } = {}
	local function select(index: number)
		for i, button in buttons do
			local active = i == index
			button.BackgroundColor3 = if active then C.GreenDeep else C.Stone800
			local text = button:FindFirstChild("Text") :: TextLabel?
			if text then
				text.TextColor3 = if active then C.GoldBright else C.TextDim
			end
		end
		onSelect(index)
	end
	for index, label in labels do
		local button = Components.Button({
			Parent = row,
			Text = label,
			Style = "Ghost",
			Size = UDim2.fromOffset(120, 32),
			LayoutOrder = index,
			TextSize = 14,
		}, function()
			select(index)
		end)
		table.insert(buttons, button)
	end
	return row, select
end

-- Tooltip singleton anchored to the mouse.
local tooltipFrame: Frame? = nil
local tooltipText: TextLabel? = nil

function Components.ShowTooltip(gui: Instance, text: string)
	if not tooltipFrame then
		local panel = Components.Panel({
			Parent = gui,
			Name = "Tooltip",
			Size = UDim2.fromOffset(280, 40),
			ZIndex = 50,
			StrokeColor = C.GoldDim,
		})
		panel.AutomaticSize = Enum.AutomaticSize.Y
		Components.Padding(panel, 10)
		tooltipText = Components.Label({
			Parent = panel,
			Text = "",
			TextSize = 14,
			ZIndex = 51,
			AutomaticSize = Enum.AutomaticSize.Y,
			Size = UDim2.new(1, 0, 0, 0),
		})
		tooltipFrame = panel
	end
	local frame = tooltipFrame :: Frame
	frame.Parent = gui;
	(tooltipText :: TextLabel).Text = text
	frame.Visible = true
	local mouse = UserInputService:GetMouseLocation()
	frame.Position = UDim2.fromOffset(mouse.X + 18, mouse.Y - 10)
end

function Components.HideTooltip()
	if tooltipFrame then
		tooltipFrame.Visible = false
	end
end

return Components
