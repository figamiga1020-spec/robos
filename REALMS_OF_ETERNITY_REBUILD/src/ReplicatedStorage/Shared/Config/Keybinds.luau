--!strict
--[[
	Keybinds — default PC layout. Players can rebind every action in Settings; the saved map
	(Profile.Settings.Keybinds) overrides these. Values are Enum.KeyCode / Enum.UserInputType names.
]]

export type BindDef = { Action: string, Label: string, Default: string, Group: string }

local Binds: { BindDef } = {
	{ Action = "Light", Label = "Основная атака", Default = "MouseButton1", Group = "Бой" },
	{ Action = "Secondary", Label = "Блок / прицел / защита", Default = "MouseButton2", Group = "Бой" },
	{ Action = "Heavy", Label = "Тяжёлая атака", Default = "Z", Group = "Бой" },
	{ Action = "Skill1", Label = "Способность 1", Default = "Q", Group = "Бой" },
	{ Action = "Skill2", Label = "Способность 2", Default = "E", Group = "Бой" },
	{ Action = "Skill3", Label = "Способность 3", Default = "R", Group = "Бой" },
	{ Action = "Skill4", Label = "Способность 4", Default = "F", Group = "Бой" },
	{ Action = "Ultimate", Label = "Высшая способность", Default = "X", Group = "Бой" },
	{ Action = "Dodge", Label = "Уклонение", Default = "LeftShift", Group = "Бой" },
	{ Action = "Sprint", Label = "Бег (удерживать)", Default = "LeftControl", Group = "Движение" },
	{ Action = "TargetCycle", Label = "Сменить цель", Default = "Tab", Group = "Бой" },
	{ Action = "LockOn", Label = "Захват цели", Default = "MouseButton3", Group = "Бой" },
	{ Action = "Hotbar1", Label = "Слот 1", Default = "One", Group = "Предметы" },
	{ Action = "Hotbar2", Label = "Слот 2", Default = "Two", Group = "Предметы" },
	{ Action = "Hotbar3", Label = "Слот 3", Default = "Three", Group = "Предметы" },
	{ Action = "Hotbar4", Label = "Слот 4", Default = "Four", Group = "Предметы" },
	{ Action = "Interact", Label = "Взаимодействие", Default = "G", Group = "Мир" },
	{ Action = "Inventory", Label = "Инвентарь", Default = "I", Group = "Меню" },
	{ Action = "Character", Label = "Персонаж", Default = "C", Group = "Меню" },
	{ Action = "Skills", Label = "Навыки и таланты", Default = "K", Group = "Меню" },
	{ Action = "Journal", Label = "Журнал заданий", Default = "J", Group = "Меню" },
	{ Action = "Map", Label = "Карта", Default = "M", Group = "Меню" },
	{ Action = "Party", Label = "Группа", Default = "P", Group = "Меню" },
	{ Action = "Menu", Label = "Меню / настройки", Default = "Escape", Group = "Меню" },
}

local ByAction: { [string]: BindDef } = {}
for _, bind in Binds do
	ByAction[bind.Action] = bind
end

return {
	Binds = Binds,
	ByAction = ByAction,
}
