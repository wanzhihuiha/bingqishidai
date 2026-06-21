extends Control

const RESOURCE_ORDER: Array[String] = ["wood", "food", "coal", "medicine", "parts", "hope"]
const RESOURCE_NAMES: Dictionary = {
	"wood": "木材",
	"food": "食物",
	"coal": "煤炭",
	"medicine": "药品",
	"parts": "零件",
	"hope": "希望值"
}
const HERO_SPECIALTY_NAMES: Dictionary = {
	"scout": "侦察",
	"gather": "采集",
	"explore": "开路",
	"repair": "修复",
	"outpost": "前哨建设",
	"guard": "护卫",
	"escort": "护送",
	"intercept": "拦截",
	"medical": "医疗支援",
	"rescue": "搜救"
}
const HERO_INJURY_STATE_NAMES: Dictionary = {
	"healthy": "健康",
	"light_wound": "轻伤",
	"heavy_wound": "重伤",
	"dead": "死亡"
}
const JOB_ORDER: Array[String] = ["worker", "hunter", "cook", "medic", "engineer"]
const NIGHT_SETTLEMENT_POPUP_SCRIPT: Script = preload("res://scripts/ui/NightSettlementPopup.gd")
const EVENT_POPUP_SCRIPT: Script = preload("res://scripts/ui/EventPopup.gd")
const BATTLE_REPORT_PANEL_SCRIPT: Script = preload("res://scripts/battle/BattleReportPanel.gd")
const BUILDING_PANEL_SCRIPT: Script = preload("res://scripts/shelter/BuildingPanel.gd")
const EXPEDITION_MANAGER_SCRIPT: Script = preload("res://scripts/managers/ExpeditionManager.gd")
const COLLECT_BUILDINGS: Array[Dictionary] = [
	{
		"title": "伐木棚",
		"body": "点击收取木材",
		"resource_id": "wood",
		"amount": 5
	},
	{
		"title": "猎屋",
		"body": "点击收取食物",
		"resource_id": "food",
		"amount": 5
	},
	{
		"title": "煤堆",
		"body": "点击收取煤炭",
		"resource_id": "coal",
		"amount": 5
	}
]

var day_label: Label
var resource_labels: Dictionary = {}
var population_label: Label
var healthy_label: Label
var sick_label: Label
var temperature_label: Label
var building_panel: Control
var collect_cards: Dictionary = {}
var quest_title_label: Label
var quest_progress_label: Label
var quest_reward_label: Label
var quest_hint_label: Label
var status_health_label: Label
var status_sick_label: Label
var status_morale_label: Label
var status_hope_label: Label
var status_text_label: Label
var building_status_labels: Dictionary = {}
var action_message_label: Label
var squad_button: Button
var end_day_confirm_dialog: ConfirmationDialog
var report_labels: Array[Label] = []
var hero_panel: PanelContainer
var hero_list_box: VBoxContainer
var hero_empty_label: Label
var equipment_inventory_label: Label
var hero_rows: Dictionary = {}
var squad_list_box: VBoxContainer
var squad_rows: Dictionary = {}
var expedition_panel: PanelContainer
var expedition_list_box: VBoxContainer
var expedition_empty_label: Label
var expedition_rows: Dictionary = {}
var expedition_selected_squad_id: String = ""
var expedition_selected_id: String = ""
var pending_battle_reports: Array[Dictionary] = []
var job_total_label: Label
var job_assignable_label: Label
var job_rows: Dictionary = {}
var job_preview_labels: Dictionary = {}


# 作用：Godot 自动回调；避难所场景加载完成后初始化游戏、连接信号、构建 UI 并刷新显示。
# 参数：无。
# 返回：无。
func _ready() -> void:
	print("[ShelterView] ready")
	GameState.ensure_started()
	if not GameState.state_changed.is_connected(_refresh_hud):
		GameState.state_changed.connect(_refresh_hud)
	if not GameState.resources_changed.is_connected(_refresh_hud):
		GameState.resources_changed.connect(_refresh_hud)
	if not GameState.temperature_changed.is_connected(_refresh_hud):
		GameState.temperature_changed.connect(_refresh_hud)
	if not GameState.quest_relevant_state_changed.is_connected(_refresh_quest_panel):
		GameState.quest_relevant_state_changed.connect(_refresh_quest_panel)
	if not GameState.state_changed.is_connected(_refresh_expedition_panel):
		GameState.state_changed.connect(_refresh_expedition_panel)
	_build_ui()
	_refresh_hud()


# 作用：动态创建避难所主界面。
# 参数：无。
# 返回：无。会创建资源栏、状态面板、岗位/建筑/收取区域、操作栏和目标面板。
func _build_ui() -> void:
	var root: MarginContainer = MarginContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("margin_left", 24)
	root.add_theme_constant_override("margin_top", 24)
	root.add_theme_constant_override("margin_right", 24)
	root.add_theme_constant_override("margin_bottom", 24)
	add_child(root)

	var layout: VBoxContainer = VBoxContainer.new()
	layout.add_theme_constant_override("separation", 18)
	root.add_child(layout)

	var content: HBoxContainer = HBoxContainer.new()
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 16)
	layout.add_child(content)

	var left_column: VBoxContainer = VBoxContainer.new()
	left_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_column.add_theme_constant_override("separation", 16)
	content.add_child(left_column)

	left_column.add_child(_make_hud())
	left_column.add_child(_make_status_panel())
	left_column.add_child(_make_main_scroll())
	left_column.add_child(_make_action_bar())
	content.add_child(_make_quest_panel())
	_create_end_day_confirm_dialog()


# 作用：创建顶部 HUD 资源和状态栏。
# 参数：无。
# 返回：GridContainer，包含天数、资源、人口和温度标签。
func _make_hud() -> GridContainer:
	var hud: GridContainer = GridContainer.new()
	hud.columns = 6
	hud.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hud.add_theme_constant_override("h_separation", 16)
	hud.add_theme_constant_override("v_separation", 8)
	day_label = _make_hud_label("")
	hud.add_child(day_label)

	var resource_order: Array[String] = GameState.get_resource_order()
	if resource_order.is_empty():
		resource_order = RESOURCE_ORDER
	for resource_id: String in resource_order:
		var label: Label = _make_hud_label("")
		resource_labels[resource_id] = label
		hud.add_child(label)

	population_label = _make_hud_label("")
	hud.add_child(population_label)

	healthy_label = _make_hud_label("")
	hud.add_child(healthy_label)

	sick_label = _make_hud_label("")
	hud.add_child(sick_label)

	temperature_label = _make_hud_label("")
	hud.add_child(temperature_label)

	return hud


# 作用：创建 HUD 中使用的统一文本标签。
# 参数：text 是初始显示文本。
# 返回：配置好字号和最小宽度的 Label。
func _make_hud_label(text: String) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 18)
	label.custom_minimum_size = Vector2(150, 0)
	return label


# 作用：创建中部可滚动主内容区域。
# 参数：无。
# 返回：ScrollContainer，内部放置岗位面板和中心建筑/资源面板。
func _make_main_scroll() -> ScrollContainer:
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0, 0)

	var row: HBoxContainer = HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 16)
	scroll.add_child(row)

	row.add_child(_make_job_panel())
	var center_column: VBoxContainer = VBoxContainer.new()
	center_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center_column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	center_column.add_theme_constant_override("separation", 16)
	center_column.add_child(_make_center_panel())
	center_column.add_child(_make_hero_panel())
	center_column.add_child(_make_expedition_panel())
	row.add_child(center_column)
	return scroll


# 作用：创建营地状态面板。
# 参数：无。
# 返回：PanelContainer，展示健康、病患、士气、希望值和综合状态文本。
func _make_status_panel() -> PanelContainer:
	var panel: PanelContainer = PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var box: HBoxContainer = HBoxContainer.new()
	box.add_theme_constant_override("separation", 18)
	panel.add_child(box)

	var title: Label = Label.new()
	title.text = "营地状态"
	title.add_theme_font_size_override("font_size", 22)
	title.custom_minimum_size = Vector2(110, 0)
	box.add_child(title)

	var grid: GridContainer = GridContainer.new()
	grid.columns = 4
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 6)
	box.add_child(grid)

	status_health_label = Label.new()
	grid.add_child(status_health_label)

	status_sick_label = Label.new()
	grid.add_child(status_sick_label)

	status_morale_label = Label.new()
	grid.add_child(status_morale_label)

	status_hope_label = Label.new()
	grid.add_child(status_hope_label)

	var divider: VSeparator = VSeparator.new()
	box.add_child(divider)

	status_text_label = Label.new()
	status_text_label.custom_minimum_size = Vector2(240, 0)
	status_text_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status_text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(status_text_label)

	return panel


# 作用：创建岗位分配面板。
# 参数：无。
# 返回：PanelContainer，包含岗位人数调整按钮和预计每日产出。
func _make_job_panel() -> PanelContainer:
	var panel: PanelContainer = PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.custom_minimum_size = Vector2(460, 0)

	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)

	var title: Label = Label.new()
	title.text = "岗位分配"
	title.add_theme_font_size_override("font_size", 24)
	box.add_child(title)

	job_total_label = Label.new()
	box.add_child(job_total_label)

	job_assignable_label = Label.new()
	job_assignable_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(job_assignable_label)

	for job_id: String in JOB_ORDER:
		box.add_child(_make_job_row(job_id))

	var preview_title: Label = Label.new()
	preview_title.text = "预计每日产出"
	preview_title.add_theme_font_size_override("font_size", 20)
	box.add_child(preview_title)

	for job_id: String in JOB_ORDER:
		var preview_label: Label = Label.new()
		preview_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(preview_label)
		job_preview_labels[job_id] = preview_label

	return panel


# 作用：创建单个岗位调整行。
# 参数：job_id 是岗位 id。
# 返回：HBoxContainer，包含岗位名、加减按钮、人数和效果说明。
func _make_job_row(job_id: String) -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)

	var name_label: Label = Label.new()
	name_label.custom_minimum_size = Vector2(90, 0)
	name_label.text = JobManager.get_job_name(job_id)
	row.add_child(name_label)

	var minus_button: Button = Button.new()
	minus_button.text = "-"
	minus_button.custom_minimum_size = Vector2(32, 32)
	minus_button.pressed.connect(_on_job_adjust_pressed.bind(job_id, -1))
	row.add_child(minus_button)

	var count_label: Label = Label.new()
	count_label.custom_minimum_size = Vector2(40, 0)
	count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(count_label)

	var plus_button: Button = Button.new()
	plus_button.text = "+"
	plus_button.custom_minimum_size = Vector2(32, 32)
	plus_button.pressed.connect(_on_job_adjust_pressed.bind(job_id, 1))
	row.add_child(plus_button)

	var note_label: Label = Label.new()
	note_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(note_label)

	job_rows[job_id] = {
		"count": count_label,
		"plus": plus_button,
		"minus": minus_button,
		"note": note_label
	}
	return row


# 作用：创建中间建筑管理和资源收取区域。
# 参数：无。
# 返回：PanelContainer，内部包含 BuildingPanel 和资源收取卡片。
func _make_center_panel() -> PanelContainer:
	var panel: PanelContainer = PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)

	building_panel = BUILDING_PANEL_SCRIPT.new() as Control
	if building_panel != null:
		building_panel.custom_minimum_size = Vector2(0, 360)
		if building_panel.has_signal("action_finished"):
			building_panel.connect("action_finished", _on_building_action_finished)
		box.add_child(building_panel)

	var collect_title: Label = Label.new()
	collect_title.text = "资源收取"
	collect_title.add_theme_font_size_override("font_size", 22)
	box.add_child(collect_title)

	var grid: GridContainer = GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	box.add_child(grid)

	for config_value: Dictionary in COLLECT_BUILDINGS:
		grid.add_child(_make_collect_card(config_value))

	return panel


# 作用：创建英雄子面板。
# 参数：无。
# 返回：PanelContainer，内部按训练场入口状态展示英雄列表和固定三队编成。
func _make_hero_panel() -> PanelContainer:
	hero_panel = PanelContainer.new()
	hero_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hero_panel.custom_minimum_size = Vector2(0, 420)

	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	hero_panel.add_child(box)

	var title: Label = Label.new()
	title.text = "英雄小队"
	title.add_theme_font_size_override("font_size", 22)
	box.add_child(title)

	hero_empty_label = Label.new()
	hero_empty_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(hero_empty_label)

	equipment_inventory_label = Label.new()
	equipment_inventory_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(equipment_inventory_label)

	hero_list_box = VBoxContainer.new()
	hero_list_box.add_theme_constant_override("separation", 10)
	box.add_child(hero_list_box)

	for hero_id: String in DataLoader.get_hero_order():
		hero_list_box.add_child(_make_hero_card(hero_id))

	var squad_title: Label = Label.new()
	squad_title.text = "小队编成"
	squad_title.add_theme_font_size_override("font_size", 22)
	box.add_child(squad_title)

	squad_list_box = VBoxContainer.new()
	squad_list_box.add_theme_constant_override("separation", 10)
	box.add_child(squad_list_box)

	for squad_id: String in DataLoader.get_squad_order():
		squad_list_box.add_child(_make_squad_card(squad_id))

	return hero_panel


# 作用：创建探险任务子面板。
# 参数：无。
# 返回：PanelContainer，包含可派遣小队、可选任务和预览信息。
func _make_expedition_panel() -> PanelContainer:
	expedition_panel = PanelContainer.new()
	expedition_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	expedition_panel.custom_minimum_size = Vector2(0, 360)

	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	expedition_panel.add_child(box)

	var title: Label = Label.new()
	title.text = "探险任务"
	title.add_theme_font_size_override("font_size", 22)
	box.add_child(title)

	expedition_empty_label = Label.new()
	expedition_empty_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	expedition_empty_label.text = "先选择一支小队和一个任务。"
	box.add_child(expedition_empty_label)

	expedition_list_box = VBoxContainer.new()
	expedition_list_box.add_theme_constant_override("separation", 8)
	box.add_child(expedition_list_box)

	for expedition_id: String in DataLoader.get_expedition_order():
		expedition_list_box.add_child(_make_expedition_card(expedition_id))

	return expedition_panel


# 作用：创建单个探险任务卡片。
# 参数：expedition_id 是探险模板 id。
# 返回：PanelContainer，包含任务信息、成功率、奖励、风险和派遣按钮。
func _make_expedition_card(expedition_id: String) -> PanelContainer:
	var card: PanelContainer = PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	card.add_child(box)

	var title_label: Label = Label.new()
	title_label.add_theme_font_size_override("font_size", 18)
	box.add_child(title_label)

	var info_label: Label = Label.new()
	info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(info_label)

	var preview_label: Label = Label.new()
	preview_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(preview_label)

	var actions: HBoxContainer = HBoxContainer.new()
	actions.add_theme_constant_override("separation", 8)
	box.add_child(actions)

	var dispatch_button: Button = Button.new()
	dispatch_button.text = "派遣"
	dispatch_button.custom_minimum_size = Vector2(90, 34)
	dispatch_button.pressed.connect(_on_dispatch_expedition_pressed.bind(expedition_id))
	actions.add_child(dispatch_button)

	expedition_rows[expedition_id] = {
		"card": card,
		"title": title_label,
		"info": info_label,
		"preview": preview_label,
		"dispatch": dispatch_button
	}
	return card


# 作用：创建单个英雄展示卡片。
# 参数：hero_id 是英雄 id。
# 返回：PanelContainer，包含头像占位、基础信息和当前状态。
func _make_hero_card(hero_id: String) -> PanelContainer:
	var card: PanelContainer = PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	card.add_child(row)

	var portrait: Label = Label.new()
	portrait.text = "头像"
	portrait.custom_minimum_size = Vector2(56, 56)
	portrait.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	portrait.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(portrait)

	var info_box: VBoxContainer = VBoxContainer.new()
	info_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_box.add_theme_constant_override("separation", 4)
	row.add_child(info_box)

	var name_label: Label = Label.new()
	name_label.add_theme_font_size_override("font_size", 18)
	info_box.add_child(name_label)

	var role_label: Label = Label.new()
	info_box.add_child(role_label)

	var tags_label: Label = Label.new()
	tags_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info_box.add_child(tags_label)

	var level_label: Label = Label.new()
	info_box.add_child(level_label)

	var exp_label: Label = Label.new()
	info_box.add_child(exp_label)

	var exp_bar_label: Label = Label.new()
	info_box.add_child(exp_bar_label)

	var equipment_label: Label = Label.new()
	equipment_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info_box.add_child(equipment_label)

	var status_label: Label = Label.new()
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info_box.add_child(status_label)

	var equip_actions: HBoxContainer = HBoxContainer.new()
	equip_actions.add_theme_constant_override("separation", 6)
	info_box.add_child(equip_actions)

	var unequip_button: Button = Button.new()
	unequip_button.text = "卸下"
	unequip_button.custom_minimum_size = Vector2(74, 30)
	unequip_button.pressed.connect(_on_unequip_item_pressed.bind(hero_id))
	equip_actions.add_child(unequip_button)

	var warm_coat_button: Button = Button.new()
	warm_coat_button.text = "暖衣"
	warm_coat_button.custom_minimum_size = Vector2(74, 30)
	warm_coat_button.pressed.connect(_on_equip_item_pressed.bind(hero_id, "warm_coat"))
	equip_actions.add_child(warm_coat_button)

	var crossbow_button: Button = Button.new()
	crossbow_button.text = "猎弩"
	crossbow_button.custom_minimum_size = Vector2(74, 30)
	crossbow_button.pressed.connect(_on_equip_item_pressed.bind(hero_id, "hunting_crossbow"))
	equip_actions.add_child(crossbow_button)

	var toolkit_button: Button = Button.new()
	toolkit_button.text = "工具包"
	toolkit_button.custom_minimum_size = Vector2(74, 30)
	toolkit_button.pressed.connect(_on_equip_item_pressed.bind(hero_id, "toolkit"))
	equip_actions.add_child(toolkit_button)

	hero_rows[hero_id] = {
		"card": card,
		"portrait": portrait,
		"name": name_label,
		"role": role_label,
		"tags": tags_label,
		"level": level_label,
		"exp": exp_label,
		"exp_bar": exp_bar_label,
		"equipment": equipment_label,
		"status": status_label,
		"unequip": unequip_button,
		"warm_coat": warm_coat_button,
		"crossbow": crossbow_button,
		"toolkit": toolkit_button
	}
	return card


# 作用：创建单个固定小队编成卡片。
# 参数：squad_id 是小队 id。
# 返回：PanelContainer，包含小队说明、当前成员和编成按钮。
func _make_squad_card(squad_id: String) -> PanelContainer:
	var card: PanelContainer = PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	card.add_child(box)

	var title_label: Label = Label.new()
	title_label.add_theme_font_size_override("font_size", 18)
	box.add_child(title_label)

	var desc_label: Label = Label.new()
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(desc_label)

	var meta_label: Label = Label.new()
	meta_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(meta_label)

	var heroes_label: Label = Label.new()
	heroes_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(heroes_label)

	var actions: HBoxContainer = HBoxContainer.new()
	actions.add_theme_constant_override("separation", 8)
	box.add_child(actions)

	var select_button: Button = Button.new()
	select_button.text = "选中"
	select_button.custom_minimum_size = Vector2(90, 34)
	select_button.pressed.connect(_on_select_expedition_squad_pressed.bind(squad_id))
	actions.add_child(select_button)

	var add_button: Button = Button.new()
	add_button.text = "编入英雄"
	add_button.custom_minimum_size = Vector2(110, 34)
	add_button.pressed.connect(_on_add_hero_to_squad_pressed.bind(squad_id))
	actions.add_child(add_button)

	var remove_button: Button = Button.new()
	remove_button.text = "移除末位"
	remove_button.custom_minimum_size = Vector2(110, 34)
	remove_button.pressed.connect(_on_remove_last_hero_from_squad_pressed.bind(squad_id))
	actions.add_child(remove_button)

	var clear_button: Button = Button.new()
	clear_button.text = "清空编队"
	clear_button.custom_minimum_size = Vector2(110, 34)
	clear_button.pressed.connect(_on_clear_squad_pressed.bind(squad_id))
	actions.add_child(clear_button)

	var dispatch_button: Button = Button.new()
	dispatch_button.text = "出发"
	dispatch_button.custom_minimum_size = Vector2(90, 34)
	dispatch_button.pressed.connect(_on_dispatch_squad_pressed.bind(squad_id))
	actions.add_child(dispatch_button)

	var recall_button: Button = Button.new()
	recall_button.text = "召回"
	recall_button.custom_minimum_size = Vector2(90, 34)
	recall_button.pressed.connect(_on_recall_squad_pressed.bind(squad_id))
	actions.add_child(recall_button)

	squad_rows[squad_id] = {
		"card": card,
		"title": title_label,
		"description": desc_label,
		"meta": meta_label,
		"heroes": heroes_label,
		"select": select_button,
		"add": add_button,
		"remove": remove_button,
		"clear": clear_button,
		"dispatch": dispatch_button,
		"recall": recall_button
	}
	return card


# 作用：创建单个资源收取卡片。
# 参数：config 是资源点配置 Dictionary，包含 title、body、resource_id、amount。
# 返回：PanelContainer，包含资源点文本、状态和收取按钮。
func _make_collect_card(config: Dictionary) -> PanelContainer:
	var panel: PanelContainer = PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.custom_minimum_size = Vector2(220, 140)

	var box: VBoxContainer = VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)

	var title: Label = Label.new()
	title.text = str(config.get("title", "资源点"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	box.add_child(title)

	var body: Label = Label.new()
	body.text = str(config.get("body", "点击收取资源"))
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(body)

	var status: Label = Label.new()
	status.text = "可收取"
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(status)

	var button: Button = Button.new()
	button.text = "收取"
	button.custom_minimum_size = Vector2(130, 36)
	box.add_child(button)

	var resource_id: String = str(config.get("resource_id", ""))
	var amount: int = int(config.get("amount", 0))
	button.pressed.connect(_on_collect_pressed.bind(resource_id, amount))
	collect_cards[resource_id] = {
		"button": button,
		"status": status
	}

	return panel


# 作用：刷新所有资源收取卡片的按钮状态。
# 参数：无。
# 返回：无。会根据是否已在今天收取过来禁用按钮。
func _update_collect_cooldowns() -> void:
	for resource_id_value: Variant in collect_cards.keys():
		var resource_id: String = str(resource_id_value)
		_refresh_collect_card(resource_id)


# 作用：刷新单个资源收取卡片的按钮和状态文本。
# 参数：resource_id 是资源 id。
# 返回：无。
func _refresh_collect_card(resource_id: String) -> void:
	var card: Dictionary = collect_cards.get(resource_id, {}) as Dictionary
	var button: Button = card.get("button") as Button
	var status: Label = card.get("status") as Label
	if button == null or status == null:
		return

	if GameState.was_resource_collected_today(resource_id):
		button.disabled = true
		status.text = "今天已收取"
		return

	button.disabled = false
	if GameState.is_resource_near_max(resource_id):
		status.text = "仓库快满了"
	else:
		status.text = "可收取"


# 作用：响应资源收取按钮。
# 参数：resource_id 是资源 id；amount 是本次收取数量。
# 返回：无。成功收取后会增加资源、标记首次收取、进入冷却并播放反馈。
func _on_collect_pressed(resource_id: String, amount: int) -> void:
	if GameState.was_resource_collected_today(resource_id):
		return

	var before: int = GameState.get_resource_amount(resource_id)
	GameState.add_resource(resource_id, amount, "collect_resource")
	GameState.mark_resource_collected(resource_id, "collect_resource")
	GameState.mark_resource_collected_today(resource_id, "collect_resource")
	var after: int = GameState.get_resource_amount(resource_id)
	print("collect_resource resource_id=%s amount=%d before=%d after=%d" % [resource_id, amount, before, after])
	_refresh_collect_card(resource_id)
	_play_collect_feedback(resource_id, amount)


# 作用：播放资源收取后的浮字和按钮闪色反馈。
# 参数：resource_id 是资源 id；amount 是收取数量。
# 返回：无。反馈动画结束后会自动释放浮字标签。
func _play_collect_feedback(resource_id: String, amount: int) -> void:
	var card: Dictionary = collect_cards.get(resource_id, {}) as Dictionary
	var button: Button = card.get("button") as Button
	if button == null:
		return

	var resource_name: String = GameState.get_resource_name(resource_id)
	var feedback_label: Label = Label.new()
	feedback_label.text = "+%d %s" % [amount, resource_name]
	feedback_label.add_theme_font_size_override("font_size", 18)
	button.get_parent().add_child(feedback_label)

	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(feedback_label, "position:y", feedback_label.position.y - 24.0, 0.6)
	tween.tween_property(feedback_label, "modulate:a", 0.0, 0.6)
	tween.tween_property(button, "modulate", Color(1.0, 0.9, 0.45, 1.0), 0.1)
	tween.chain().tween_property(button, "modulate", Color.WHITE, 0.2)
	tween.chain().tween_callback(feedback_label.queue_free)


# 作用：自动分配 3 名幸存者到岗位，用于前期引导验证。
# 参数：无。
# 返回：无。会显示成功或失败提示并刷新目标面板。
func assign_three_jobs() -> void:
	GameState.assign_jobs_total(3, "assign_three_jobs")
	var assigned: int = GameState.assigned_jobs_total
	var success: bool = assigned >= 3
	if success:
		_show_action_message("已分配 3 名幸存者岗位", true)
	else:
		_show_action_message("可分配人口不足 3 名", false)
	_refresh_quest_panel()


# 作用：创建底部操作栏。
# 参数：无。
# 返回：VBoxContainer，包含进入地图、英雄小队、结束一天、自动分配岗位和提示文本。
func _make_action_bar() -> VBoxContainer:
	var actions: VBoxContainer = VBoxContainer.new()
	actions.add_theme_constant_override("separation", 8)

	var buttons: HBoxContainer = HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 12)
	actions.add_child(buttons)

	var world_button: Button = Button.new()
	world_button.text = "进入冰原地图"
	world_button.custom_minimum_size = Vector2(150, 42)
	world_button.pressed.connect(_on_world_map_pressed)
	buttons.add_child(world_button)

	squad_button = Button.new()
	squad_button.text = "英雄小队"
	squad_button.custom_minimum_size = Vector2(170, 42)
	squad_button.pressed.connect(_on_squad_pressed)
	buttons.add_child(squad_button)

	var end_day_button: Button = Button.new()
	end_day_button.text = "结束一天"
	end_day_button.custom_minimum_size = Vector2(150, 42)
	end_day_button.pressed.connect(_on_end_day_pressed)
	buttons.add_child(end_day_button)

	var job_button: Button = Button.new()
	job_button.text = "自动分配 3 人"
	job_button.custom_minimum_size = Vector2(150, 42)
	job_button.pressed.connect(_on_assign_jobs_pressed)
	buttons.add_child(job_button)

	action_message_label = Label.new()
	action_message_label.custom_minimum_size = Vector2(0, 28)
	action_message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	action_message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	actions.add_child(action_message_label)

	return actions


# 作用：创建“结束一天”确认弹窗。
# 参数：无。
# 返回：无。已创建过时不会重复创建。
func _create_end_day_confirm_dialog() -> void:
	if end_day_confirm_dialog != null:
		return
	end_day_confirm_dialog = ConfirmationDialog.new()
	end_day_confirm_dialog.title = "确认结束一天"
	end_day_confirm_dialog.dialog_text = "结束一天后会进入夜晚结算。\n是否继续？"
	end_day_confirm_dialog.confirmed.connect(_on_end_day_confirmed)
	add_child(end_day_confirm_dialog)

	var ok_button: Button = end_day_confirm_dialog.get_ok_button()
	if ok_button != null:
		ok_button.text = "确认结束"

	var cancel_button: Button = end_day_confirm_dialog.get_cancel_button()
	if cancel_button != null:
		cancel_button.text = "取消"


# 作用：创建右侧当前目标和建筑状态面板。
# 参数：无。
# 返回：PanelContainer，展示当前任务、奖励、建筑状态和近期日志。
func _make_quest_panel() -> PanelContainer:
	var panel: PanelContainer = PanelContainer.new()
	panel.custom_minimum_size = Vector2(300, 0)
	panel.size_flags_horizontal = Control.SIZE_SHRINK_END
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)

	var title: Label = Label.new()
	title.text = "当前目标"
	title.add_theme_font_size_override("font_size", 24)
	box.add_child(title)

	quest_title_label = Label.new()
	quest_title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(quest_title_label)

	quest_progress_label = Label.new()
	quest_progress_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(quest_progress_label)

	quest_reward_label = Label.new()
	quest_reward_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(quest_reward_label)

	quest_hint_label = Label.new()
	quest_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(quest_hint_label)

	var divider: HSeparator = HSeparator.new()
	box.add_child(divider)

	var building_title: Label = Label.new()
	building_title.text = "建筑状态"
	building_title.add_theme_font_size_override("font_size", 22)
	box.add_child(building_title)

	_add_building_status_row(box, "furnace")
	_add_building_status_row(box, "lumber_yard")
	_add_building_status_row(box, "hunter_lodge")
	_add_building_status_row(box, "kitchen")
	_add_building_status_row(box, "medical_tent")
	_add_building_status_row(box, "workshop")
	_add_building_status_row(box, "training_ground")
	_add_building_status_row(box, "outpost")

	var report_divider: HSeparator = HSeparator.new()
	box.add_child(report_divider)

	var report_title: Label = Label.new()
	report_title.text = "近期日志"
	report_title.add_theme_font_size_override("font_size", 22)
	box.add_child(report_title)

	for index: int in range(5):
		var report_label: Label = Label.new()
		report_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(report_label)
		report_labels.append(report_label)

	return panel


# 作用：在建筑状态面板中添加一行建筑状态标签。
# 参数：container 是目标容器；building_id 是建筑 id。
# 返回：无。创建的 Label 会记录到 building_status_labels 中。
func _add_building_status_row(container: VBoxContainer, building_id: String) -> void:
	var label: Label = Label.new()
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	container.add_child(label)
	building_status_labels[building_id] = label


# 作用：刷新避难所界面的所有 HUD 和子面板。
# 参数：无。
# 返回：无。资源、人口、温度、建筑、岗位、目标和日志都会同步更新。
func _refresh_hud() -> void:
	if day_label != null:
		day_label.text = "第 %d 天" % GameState.day

	_update_collect_cooldowns()

	# 资源栏按创建时记录的 resource_labels 刷新，显示名称来自 DataLoader 配置。
	for resource_id_value: Variant in resource_labels.keys():
		var resource_id: String = str(resource_id_value)
		var label: Label = resource_labels.get(resource_id) as Label
		if label == null:
			continue
		var resource_name: String = GameState.get_resource_name(resource_id)
		var amount: int = GameState.get_resource_amount(resource_id)
		label.text = "%s：%d" % [resource_name, amount]

	if population_label != null:
		population_label.text = "人口：%d" % GameState.get_alive_population()
	if healthy_label != null:
		healthy_label.text = "健康：%d" % GameState.get_healthy_population()
	if sick_label != null:
		sick_label.text = "病患：%d" % GameState.get_sick_population()
	if temperature_label != null:
		temperature_label.text = "温度评分：%d（%s）" % [
			GameState.temperature_score,
			GameState.get_temperature_status()
		]

	_refresh_status_panel()
	if building_panel != null and building_panel.has_method("refresh"):
		building_panel.call("refresh")
	_refresh_feature_buttons()
	_refresh_job_panel()
	_refresh_hero_panel()
	_refresh_expedition_panel()
	_refresh_quest_panel()
	_refresh_report_panel()


# 作用：响应“进入冰原地图”按钮。
# 参数：无。
# 返回：无。会切换到地图场景。
func _on_world_map_pressed() -> void:
	print("[ShelterView] button=world_map")
	SceneRouter.go_to_world_map()


# 作用：响应“结束一天”按钮，弹出确认窗口。
# 参数：无。
# 返回：无。确认后才会真正执行夜晚结算。
func _on_end_day_pressed() -> void:
	print("[ShelterView] button=end_day")
	if end_day_confirm_dialog == null:
		_create_end_day_confirm_dialog()
	end_day_confirm_dialog.dialog_text = "结束一天后会进入夜晚结算，并统一结算已派遣探险。\n是否继续？"
	end_day_confirm_dialog.popup_centered()


# 作用：响应结束一天确认。
# 参数：无。
# 返回：无。会执行夜晚结算、刷新界面并显示结算弹窗。
func _on_end_day_confirmed() -> void:
	print("[ShelterView] confirm=end_day")
	var result: Dictionary = NightSettlementManager.settle_night()
	var expeditions: Dictionary = result.get("expeditions", {}) as Dictionary
	pending_battle_reports = _extract_battle_results(expeditions.get("results", []))
	_refresh_hud()
	_show_night_settlement_popup(result)


# 作用：响应“英雄小队”按钮。
# 参数：无。
# 返回：无。当前功能只做解锁提示，正式编队后续接入。
func _on_squad_pressed() -> void:
	print("[ShelterView] button=hero_squad")
	if not BuildingManager.can_show_feature_unlocked("hero_squad"):
		_show_action_message("训练场 1 级后，点右侧建筑状态里的训练场查看英雄小队入口", false)
		return
	_show_action_message("英雄小队入口已解锁，下方会显示当前英雄状态。", true)


# 作用：刷新功能入口按钮状态。
# 参数：无。
# 返回：无。当前主要刷新英雄小队入口的提示文本。
func _refresh_feature_buttons() -> void:
	if squad_button == null:
		return

	if BuildingManager.can_show_feature_unlocked("hero_squad"):
		squad_button.text = "英雄小队"
		squad_button.tooltip_text = "英雄小队入口已解锁"
	else:
		squad_button.text = "英雄小队"
		squad_button.tooltip_text = "训练场 1 级解锁"


# 作用：刷新英雄子面板。
# 参数：无。
# 返回：无。会根据训练场入口状态和英雄加入状态更新展示，并刷新固定三队编成。
func _refresh_hero_panel() -> void:
	if hero_panel == null or hero_empty_label == null or hero_list_box == null or squad_list_box == null:
		return

	var can_show: bool = BuildingManager.can_show_feature_unlocked("hero_squad")
	hero_list_box.visible = can_show
	squad_list_box.visible = can_show
	if not can_show:
		hero_empty_label.text = "训练场 1 级后解锁英雄小队入口。"
		if equipment_inventory_label != null:
			equipment_inventory_label.text = ""
		return

	hero_empty_label.text = "已加入英雄会随天数逐步到位。这里会同步显示成长和轻量装备状态。"
	if equipment_inventory_label != null:
		equipment_inventory_label.text = "装备库存：%s" % _format_equipment_inventory_summary()
	for hero_id: String in DataLoader.get_hero_order():
		_refresh_hero_card(hero_id)
	for squad_id: String in DataLoader.get_squad_order():
		_refresh_squad_card(squad_id)
	_refresh_expedition_panel()


# 作用：刷新单个英雄卡片。
# 参数：hero_id 是英雄 id。
# 返回：无。未加入英雄会置灰并展示加入天数。
func _refresh_hero_card(hero_id: String) -> void:
	var row_info: Dictionary = hero_rows.get(hero_id, {}) as Dictionary
	if row_info.is_empty():
		return

	var config: Dictionary = DataLoader.get_hero_config(hero_id)
	var state: Dictionary = GameState.get_hero_state(hero_id)
	var card: PanelContainer = row_info.get("card") as PanelContainer
	var name_label: Label = row_info.get("name") as Label
	var role_label: Label = row_info.get("role") as Label
	var tags_label: Label = row_info.get("tags") as Label
	var level_label: Label = row_info.get("level") as Label
	var exp_label: Label = row_info.get("exp") as Label
	var exp_bar_label: Label = row_info.get("exp_bar") as Label
	var equipment_label: Label = row_info.get("equipment") as Label
	var status_label: Label = row_info.get("status") as Label
	var unequip_button: Button = row_info.get("unequip") as Button
	var warm_coat_button: Button = row_info.get("warm_coat") as Button
	var crossbow_button: Button = row_info.get("crossbow") as Button
	var toolkit_button: Button = row_info.get("toolkit") as Button
	if card == null or name_label == null or role_label == null or tags_label == null or level_label == null or exp_label == null or exp_bar_label == null or equipment_label == null or status_label == null or unequip_button == null or warm_coat_button == null or crossbow_button == null or toolkit_button == null:
		return

	var hero_name: String = str(config.get("name", hero_id))
	var role: String = str(config.get("role", "未知定位"))
	var join_day: int = int(config.get("join_day", 0))
	var specialty_tags: Array = config.get("specialty_tags", []) as Array
	var is_unlocked: bool = bool(state.get("is_unlocked", false))
	var is_available: bool = bool(state.get("is_available", false))
	var assigned_squad_id: String = str(state.get("assigned_squad_id", ""))
	var injury_state: String = str(state.get("injury_state", "healthy"))
	var level: int = int(state.get("level", 1))
	var current_exp: int = int(state.get("exp", 0))
	var exp_to_next: int = HeroGrowthManager.get_exp_to_next_level(level)
	var equipped_item_id: String = str(state.get("equipped_item_id", ""))
	var squad_status: String = "idle"
	if not assigned_squad_id.is_empty():
		squad_status = GameState.get_squad_status(assigned_squad_id)

	name_label.text = hero_name
	role_label.text = "定位：%s" % role
	tags_label.text = "专长：%s" % _format_hero_specialties(specialty_tags)
	level_label.text = "等级：%d 级" % level
	if exp_to_next > 0:
		exp_label.text = "经验：%d/%d" % [current_exp, exp_to_next]
	else:
		exp_label.text = "经验：已满级"
	exp_bar_label.text = "进度：%s" % _build_text_progress_bar(current_exp, exp_to_next)
	equipment_label.text = "装备槽：%s" % _format_equipped_item_name(equipped_item_id)

	var dispatch_text: String = "不可派遣"
	if is_available:
		dispatch_text = "可派遣"
	var squad_text: String = "未编队"
	if not assigned_squad_id.is_empty():
		squad_text = "编队：%s" % _get_squad_name(assigned_squad_id)

	if is_unlocked:
		status_label.text = "状态：已加入，%s，伤病：%s，%s" % [
			dispatch_text,
			_format_hero_injury_state(injury_state),
			squad_text
		]
		card.modulate = Color.WHITE
	else:
		status_label.text = "状态：第 %d 天加入，未加入，不可派遣" % join_day
		card.modulate = Color(0.65, 0.65, 0.65, 1.0)

	var can_operate_equipment: bool = is_unlocked and squad_status != "assigned" and squad_status != "returning"
	unequip_button.disabled = not can_operate_equipment or equipped_item_id.is_empty()
	warm_coat_button.disabled = not can_operate_equipment or GameState.get_equipment_inventory_amount("warm_coat") <= 0
	crossbow_button.disabled = not can_operate_equipment or GameState.get_equipment_inventory_amount("hunting_crossbow") <= 0
	toolkit_button.disabled = not can_operate_equipment or GameState.get_equipment_inventory_amount("toolkit") <= 0


# 作用：刷新单个固定小队编成卡片。
# 参数：squad_id 是小队 id。
# 返回：无。会显示小队说明、状态、补给和当前成员。
func _refresh_squad_card(squad_id: String) -> void:
	var row_info: Dictionary = squad_rows.get(squad_id, {}) as Dictionary
	if row_info.is_empty():
		return

	var config: Dictionary = DataLoader.get_squad_config(squad_id)
	var state: Dictionary = GameState.get_squad_state(squad_id)
	var title_label: Label = row_info.get("title") as Label
	var desc_label: Label = row_info.get("description") as Label
	var meta_label: Label = row_info.get("meta") as Label
	var heroes_label: Label = row_info.get("heroes") as Label
	var select_button: Button = row_info.get("select") as Button
	var add_button: Button = row_info.get("add") as Button
	var remove_button: Button = row_info.get("remove") as Button
	var clear_button: Button = row_info.get("clear") as Button
	var dispatch_button: Button = row_info.get("dispatch") as Button
	var recall_button: Button = row_info.get("recall") as Button
	if title_label == null or desc_label == null or meta_label == null or heroes_label == null or select_button == null or add_button == null or remove_button == null or clear_button == null or dispatch_button == null or recall_button == null:
		return

	var squad_name: String = str(config.get("name", squad_id))
	var description: String = str(config.get("description", ""))
	var max_heroes: int = int(config.get("max_heroes", 2))
	var food_cost: int = int(config.get("food_cost", 0))
	var status: String = str(state.get("status", "idle"))
	var assigned_task_id: String = str(state.get("assigned_task_id", ""))
	var acted_today: bool = bool(state.get("acted_today", false))
	var hero_ids: Array[String] = GameState.get_squad_hero_ids(squad_id)
	var acted_today_text: String = "未行动"
	if acted_today:
		acted_today_text = "已行动"
	var task_text: String = "无"
	if not assigned_task_id.is_empty():
		task_text = _format_task_name(assigned_task_id)

	title_label.text = squad_name
	desc_label.text = description
	meta_label.text = "状态：%s；补给：食物 %d；人数：%d / %d；今日行动：%s；任务：%s" % [
		_format_squad_status(status),
		food_cost,
		hero_ids.size(),
		max_heroes,
		acted_today_text,
		task_text
	]
	heroes_label.text = "成员：%s" % _format_squad_hero_names(hero_ids)
	select_button.disabled = status != "idle" or hero_ids.is_empty()
	if expedition_selected_squad_id == squad_id:
		select_button.text = "已选中"
	else:
		select_button.text = "选中"

	add_button.disabled = _get_next_assignable_hero_id_for_squad(squad_id).is_empty()
	remove_button.disabled = hero_ids.is_empty()
	clear_button.disabled = hero_ids.is_empty()
	dispatch_button.disabled = not GameState.can_dispatch_squad(squad_id)
	recall_button.disabled = status != "assigned"


# 作用：选中一个用于探险派遣的小队。
# 参数：squad_id 是小队 id。
# 返回：无。会刷新探险面板预览。
func _on_select_expedition_squad_pressed(squad_id: String) -> void:
	expedition_selected_squad_id = squad_id
	expedition_selected_id = ""
	_show_action_message("%s 已选中，用于探险派遣" % _get_squad_name(squad_id), true)
	_refresh_expedition_panel()


# 作用：刷新探险任务面板。
# 参数：无。
# 返回：无。会根据小队状态和任务条件更新展示。
func _refresh_expedition_panel() -> void:
	if expedition_panel == null or expedition_list_box == null or expedition_empty_label == null:
		return

	var can_show: bool = BuildingManager.can_show_feature_unlocked("hero_squad")
	expedition_panel.visible = can_show
	expedition_list_box.visible = can_show
	if not can_show:
		expedition_empty_label.text = "训练场 1 级后解锁探险任务。"
		return

	if expedition_rows.is_empty():
		expedition_empty_label.text = "暂无可用探险任务。"
		return

	expedition_empty_label.text = "先选小队，再点任务派遣。结算会在结束一天时统一完成。"
	for expedition_id: String in DataLoader.get_expedition_order():
		_refresh_expedition_card(expedition_id)


# 作用：刷新单个探险任务卡片。
# 参数：expedition_id 是探险模板 id。
# 返回：无。展示成功率、奖励、风险和派遣按钮状态。
func _refresh_expedition_card(expedition_id: String) -> void:
	var row_info: Dictionary = expedition_rows.get(expedition_id, {}) as Dictionary
	if row_info.is_empty():
		return

	var config: Dictionary = DataLoader.get_expedition_config(expedition_id)
	var title_label: Label = row_info.get("title") as Label
	var info_label: Label = row_info.get("info") as Label
	var preview_label: Label = row_info.get("preview") as Label
	var dispatch_button: Button = row_info.get("dispatch") as Button
	if title_label == null or info_label == null or preview_label == null or dispatch_button == null:
		return

	var title: String = str(config.get("title", expedition_id))
	var description: String = str(config.get("description", ""))
	var required_tags: Array = config.get("required_tags", []) as Array
	var reward_text: String = ExpeditionManager.get_reward_preview_text(expedition_id)
	var risk_text: String = ExpeditionManager.get_risk_preview_text(expedition_id)
	var success_rate_text: String = "成功率：--"
	if not expedition_selected_squad_id.is_empty():
		var success_rate: float = ExpeditionManager.get_success_rate_preview(expedition_selected_squad_id, expedition_id)
		success_rate_text = "成功率：%d%%" % int(round(success_rate * 100.0))

	title_label.text = title
	info_label.text = "说明：%s；标签：%s" % [description, _format_action_tags(required_tags)]
	preview_label.text = "%s；预计奖励：%s；可能风险：%s" % [
		success_rate_text,
		reward_text,
		risk_text
	]
	dispatch_button.disabled = expedition_selected_squad_id.is_empty() or not GameState.can_dispatch_expedition(expedition_selected_squad_id, expedition_id)
	if expedition_selected_id == expedition_id:
		dispatch_button.text = "已选任务"
	else:
		dispatch_button.text = "派遣"


# 作用：响应探险任务派遣按钮。
# 参数：expedition_id 是探险模板 id。
# 返回：无。会将当前选中小队派往对应任务。
func _on_dispatch_expedition_pressed(expedition_id: String) -> void:
	if expedition_selected_squad_id.is_empty():
		_show_action_message("请先选中一支小队", false)
		return
	if not GameState.can_dispatch_expedition(expedition_selected_squad_id, expedition_id):
		_show_action_message("当前小队不满足该任务条件", false)
		return

	var success: bool = ExpeditionManager.dispatch_expedition(expedition_selected_squad_id, expedition_id)
	if success:
		expedition_selected_id = expedition_id
		_show_action_message("%s 已派往 %s" % [
			_get_squad_name(expedition_selected_squad_id),
			str(DataLoader.get_expedition_config(expedition_id).get("title", expedition_id))
		], true)
	else:
		_show_action_message("派遣失败，请检查补给、状态或任务条件", false)
	_refresh_expedition_panel()


# 作用：响应“小队编入英雄”按钮。
# 参数：squad_id 是目标小队 id。
# 返回：无。当前按英雄配置顺序自动编入第一个符合条件的英雄。
func _on_add_hero_to_squad_pressed(squad_id: String) -> void:
	var hero_id: String = _get_next_assignable_hero_id_for_squad(squad_id)
	if hero_id.is_empty():
		_show_action_message("当前没有可编入该小队的英雄", false)
		return

	var success: bool = GameState.assign_hero_to_squad(hero_id, squad_id, "shelter_view_assign_squad")
	if success:
		var hero_config: Dictionary = DataLoader.get_hero_config(hero_id)
		_show_action_message("%s 已编入 %s" % [
			str(hero_config.get("name", hero_id)),
			_get_squad_name(squad_id)
		], true)
	else:
		_show_action_message("编队失败，请检查英雄状态", false)
	_refresh_hud()


# 作用：响应“小队移除末位英雄”按钮。
# 参数：squad_id 是目标小队 id。
# 返回：无。当前从该队最后一名英雄开始移除。
func _on_remove_last_hero_from_squad_pressed(squad_id: String) -> void:
	var hero_ids: Array[String] = GameState.get_squad_hero_ids(squad_id)
	if hero_ids.is_empty():
		_show_action_message("当前小队没有可移除的英雄", false)
		return

	var hero_id: String = hero_ids[hero_ids.size() - 1]
	var success: bool = GameState.remove_hero_from_squad(hero_id, squad_id, "shelter_view_remove_squad")
	if success:
		var hero_config: Dictionary = DataLoader.get_hero_config(hero_id)
		_show_action_message("%s 已移出 %s" % [
			str(hero_config.get("name", hero_id)),
			_get_squad_name(squad_id)
		], true)
	else:
		_show_action_message("移除失败，请重试", false)
	_refresh_hud()


# 作用：响应“清空编队”按钮。
# 参数：squad_id 是目标小队 id。
# 返回：无。会清空该队全部英雄。
func _on_clear_squad_pressed(squad_id: String) -> void:
	var success: bool = GameState.clear_squad_heroes(squad_id, "shelter_view_clear_squad")
	if success:
		_show_action_message("%s 已清空编队" % _get_squad_name(squad_id), true)
	else:
		_show_action_message("当前小队已经为空", false)
	_refresh_hud()


# 作用：响应英雄装备按钮，为指定英雄装备一件轻量装备。
# 参数：hero_id 是英雄 id；equipment_id 是装备 id。
# 返回：无。成功后刷新英雄区和库存摘要。
func _on_equip_item_pressed(hero_id: String, equipment_id: String) -> void:
	var success: bool = HeroGrowthManager.equip_item(hero_id, equipment_id, "shelter_equip_item")
	if success:
		_show_action_message("%s 装备了 %s" % [
			str(DataLoader.get_hero_config(hero_id).get("name", hero_id)),
			DataLoader.get_equipment_name(equipment_id)
		], true)
	else:
		_show_action_message("当前无法装备 %s" % DataLoader.get_equipment_name(equipment_id), false)
	_refresh_hud()


# 作用：响应英雄卸装按钮。
# 参数：hero_id 是英雄 id。
# 返回：无。成功后返还库存并刷新面板。
func _on_unequip_item_pressed(hero_id: String) -> void:
	var equipped_item_id: String = GameState.get_hero_equipped_item_id(hero_id)
	var success: bool = HeroGrowthManager.unequip_item(hero_id, "shelter_unequip_item")
	if success:
		_show_action_message("%s 已卸下 %s" % [
			str(DataLoader.get_hero_config(hero_id).get("name", hero_id)),
			_format_equipped_item_name(equipped_item_id)
		], true)
	else:
		_show_action_message("当前没有可卸下的装备", false)
	_refresh_hud()


# 作用：响应“小队出发”按钮。
# 参数：squad_id 是目标小队 id。
# 返回：无。D4 阶段先使用占位任务 id 标记执行中状态。
func _on_dispatch_squad_pressed(squad_id: String) -> void:
	var task_id: String = "manual_dispatch_%s_day_%d" % [squad_id, GameState.day]
	var success: bool = GameState.dispatch_squad(squad_id, task_id, "shelter_view_dispatch_squad")
	if success:
		var food_cost: int = int(DataLoader.get_squad_config(squad_id).get("food_cost", 0))
		_show_action_message("%s 已出发，消耗食物 %d" % [
			_get_squad_name(squad_id),
			food_cost
		], true)
	else:
		_show_action_message("无法出发：需要已编队且食物充足，并且今天未行动", false)
	_refresh_hud()


# 作用：响应“小队召回”按钮。
# 参数：squad_id 是目标小队 id。
# 返回：无。召回后小队进入返程中，次日恢复待命。
func _on_recall_squad_pressed(squad_id: String) -> void:
	var success: bool = GameState.recall_squad(squad_id, "shelter_view_recall_squad")
	if success:
		_show_action_message("%s 已召回，状态改为返程中" % _get_squad_name(squad_id), true)
	else:
		_show_action_message("当前只有执行中的小队可以召回", false)
	_refresh_hud()


# 作用：接收建筑面板操作结果。
# 参数：message 是建筑面板返回的提示；success 表示操作是否成功。
# 返回：无。会显示操作提示并刷新 HUD。
func _on_building_action_finished(message: String, success: bool) -> void:
	_show_action_message(message, success)
	_refresh_hud()


# 作用：显示夜晚结算弹窗。
# 参数：result 是 NightSettlementManager.settle_night() 返回的结算结果。
# 返回：无。弹窗继续后会尝试触发每日事件。
func _show_night_settlement_popup(result: Dictionary) -> void:
	var popup: CanvasLayer = NIGHT_SETTLEMENT_POPUP_SCRIPT.new() as CanvasLayer
	if popup == null:
		push_error("[ShelterView] failed to create night settlement popup")
		return

	add_child(popup)
	if popup.has_signal("continued"):
		popup.connect("continued", _on_night_settlement_popup_continued)
	if popup.has_method("show_result"):
		popup.call("show_result", result)


# 作用：响应夜晚结算弹窗的继续信号。
# 参数：无。
# 返回：无。会先展示自动战斗战报，再尝试展示当天事件。
func _on_night_settlement_popup_continued() -> void:
	if not pending_battle_reports.is_empty():
		_show_battle_report_panel(pending_battle_reports)
		pending_battle_reports = []
		return
	_try_show_daily_event()


# 作用：显示自动战斗战报面板。
# 参数：battle_results 是当天探险结算结果数组。
# 返回：无。
func _show_battle_report_panel(battle_results: Array[Dictionary]) -> void:
	var panel: CanvasLayer = BATTLE_REPORT_PANEL_SCRIPT.new() as CanvasLayer
	if panel == null:
		push_error("[ShelterView] failed to create battle report panel")
		_try_show_daily_event()
		return

	add_child(panel)
	if panel.has_signal("closed"):
		panel.connect("closed", _on_battle_report_panel_closed)
	if panel.has_method("show_reports"):
		panel.call("show_reports", battle_results)


# 作用：响应自动战斗战报关闭。
# 参数：无。
# 返回：无。继续进入每日事件。
func _on_battle_report_panel_closed() -> void:
	_try_show_daily_event()


# 作用：尝试显示每日随机事件弹窗。
# 参数：无。
# 返回：无。没有待触发事件时直接结束。
func _try_show_daily_event() -> void:
	var event_config: Dictionary = EventManager.get_pending_event()
	if event_config.is_empty():
		return

	var popup: CanvasLayer = EVENT_POPUP_SCRIPT.new() as CanvasLayer
	if popup == null:
		push_error("[ShelterView] failed to create event popup")
		return

	add_child(popup)
	if popup.has_signal("event_finished"):
		popup.connect("event_finished", _on_event_popup_finished)
	if popup.has_method("show_event"):
		popup.call("show_event", event_config)


# 作用：响应事件弹窗关闭。
# 参数：无。
# 返回：无。会刷新 HUD，展示事件造成的状态变化。
func _on_event_popup_finished() -> void:
	_refresh_hud()


# 作用：响应“自动分配 3 人”按钮。
# 参数：无。
# 返回：无。会调用 assign_three_jobs()。
func _on_assign_jobs_pressed() -> void:
	print("[ShelterView] button=assign_jobs")
	assign_three_jobs()


# 作用：响应岗位加减按钮。
# 参数：job_id 是岗位 id；delta 是调整人数，通常为 +1 或 -1。
# 返回：无。会更新 GameState、展示提示并刷新 HUD。
func _on_job_adjust_pressed(job_id: String, delta: int) -> void:
	var changed: bool = GameState.add_job_assignment(job_id, delta, "job_panel_adjust")
	if changed:
		_show_action_message("%s 已调整" % JobManager.get_job_name(job_id), true)
	else:
		_show_action_message("%s 无法继续调整" % JobManager.get_job_name(job_id), false)
	_refresh_hud()


# 作用：刷新岗位分配面板和预计产出。
# 参数：无。
# 返回：无。会同步岗位人数、按钮可用状态、岗位说明和预览文本。
func _refresh_job_panel() -> void:
	if job_total_label != null:
		job_total_label.text = "总人口：%d" % GameState.get_alive_population()
	if job_assignable_label != null:
		job_assignable_label.text = "可分配健康人口：%d；轻伤半产出人口：%d；重伤不可分配：%d；剩余可用：%d" % [
			GameState.get_healthy_population(),
			int(GameState.population.get("light_wound", 0)),
			int(GameState.population.get("heavy_wound", 0)),
			GameState.get_unassigned_population()
		]

	var assignments: Dictionary = GameState.get_job_assignments()
	var preview: Dictionary = JobManager.get_preview()
	var resources: Dictionary = preview.get("resources", {}) as Dictionary

	for job_id_value: Variant in job_rows.keys():
		var job_id: String = str(job_id_value)
		var row_info: Dictionary = job_rows.get(job_id, {}) as Dictionary
		var count_label: Label = row_info.get("count") as Label
		var plus_button: Button = row_info.get("plus") as Button
		var minus_button: Button = row_info.get("minus") as Button
		var note_label: Label = row_info.get("note") as Label
		if count_label == null or plus_button == null or minus_button == null or note_label == null:
			continue

		var count: int = int(assignments.get(job_id, 0))
		count_label.text = str(count)
		minus_button.disabled = count <= 0
		plus_button.disabled = GameState.get_unassigned_population() <= 0
		note_label.text = _get_job_note_text(job_id, preview, resources)

	if job_preview_labels.has("worker"):
		(job_preview_labels.get("worker") as Label).text = "工人：木材 +%d" % int(resources.get("wood", 0))
	if job_preview_labels.has("hunter"):
		(job_preview_labels.get("hunter") as Label).text = "猎手：食物 +%d" % int(resources.get("food", 0))
	if job_preview_labels.has("cook"):
		(job_preview_labels.get("cook") as Label).text = "厨师：食物节省 %d，士气最多 +%d" % [
			int(preview.get("food_saved", 0)),
			int(preview.get("morale_bonus", 0))
		]
	if job_preview_labels.has("medic"):
		(job_preview_labels.get("medic") as Label).text = "医护：治疗点 %d" % int(preview.get("heal_points", 0))
	if job_preview_labels.has("engineer"):
		(job_preview_labels.get("engineer") as Label).text = "工程师：零件 +%d，煤炭节省 %d" % [
			int(resources.get("parts", 0)),
			int(preview.get("coal_saved", 0))
		]


# 作用：刷新营地状态面板。
# 参数：无。
# 返回：无。会同步健康、病患、士气、希望值和综合状态文本。
func _refresh_status_panel() -> void:
	if status_health_label != null:
		status_health_label.text = "健康人口：%d" % GameState.get_healthy_population()
	if status_sick_label != null:
		status_sick_label.text = "病患人口：%d" % GameState.get_sick_population()
	if status_morale_label != null:
		status_morale_label.text = "士气：%d / 100" % GameState.morale_score
	if status_hope_label != null:
		status_hope_label.text = "希望值：%d / 100" % GameState.get_resource_amount("hope")
	if status_text_label != null:
		status_text_label.text = "当前状态：%s" % GameState.shelter_status_text


# 作用：生成单个岗位的效果说明文本。
# 参数：job_id 是岗位 id；preview 是 JobManager.get_preview() 返回值；resources 是预览中的资源产出 Dictionary。
# 返回：中文岗位说明。
func _get_job_note_text(job_id: String, preview: Dictionary, resources: Dictionary) -> String:
	match job_id:
		"worker":
			return "预计 +%d 木材" % int(resources.get("wood", 0))
		"hunter":
			return "预计 +%d 食物" % int(resources.get("food", 0))
		"cook":
			return "节省率 %.0f%%，士气加成" % (float(preview.get("food_save_rate", 0.0)) * 100.0)
		"medic":
			return "治疗点 %d" % int(preview.get("heal_points", 0))
		"engineer":
			return "零件 +%d，煤炭 -%d" % [
				int(resources.get("parts", 0)),
				int(preview.get("coal_saved", 0))
			]
		_:
			return "岗位效果预览"


# 作用：把任意数组转换成中文顿号连接文本。
# 参数：values 是任意值数组。
# 返回：拼接后的字符串；空数组返回“无”。
func _join_values(values: Array) -> String:
	var parts: PackedStringArray = PackedStringArray()
	for value: Variant in values:
		var text: String = str(value)
		if text.is_empty():
			continue
		parts.append(text)
	if parts.is_empty():
		return "无"
	return "、".join(parts)


# 作用：把任意 Variant 安全转成字符串数组，供标签和战报等 UI 文本拼接复用。
# 参数：value 是任意值。
# 返回：字符串数组；不是数组时返回空数组。
func _to_string_array(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if typeof(value) != TYPE_ARRAY:
		return result
	var raw_values: Array = value as Array
	for item_value: Variant in raw_values:
		result.append(str(item_value))
	return result


# 作用：把英雄专长标签数组转换成中文展示文案。
# 参数：specialty_tags 是 heroes.json 中的专长标签数组。
# 返回：中文专长文本；未知标签保留原值。
func _format_hero_specialties(specialty_tags: Array) -> String:
	var display_values: Array[String] = []
	for tag_value: Variant in specialty_tags:
		var tag: String = str(tag_value)
		display_values.append(str(HERO_SPECIALTY_NAMES.get(tag, tag)))
	return _join_values(display_values)


# 作用：把英雄伤病状态转换成中文展示文案。
# 参数：injury_state 是英雄运行时状态值。
# 返回：中文状态文本；未知值保留原值。
func _format_hero_injury_state(injury_state: String) -> String:
	return str(HERO_INJURY_STATE_NAMES.get(injury_state, injury_state))


# 作用：把装备库存压缩成一行摘要文本。
# 参数：无。
# 返回：中文库存摘要。
func _format_equipment_inventory_summary() -> String:
	var parts: Array[String] = []
	for equipment_id: String in DataLoader.get_equipment_order():
		parts.append("%s %d 件" % [
			DataLoader.get_equipment_name(equipment_id),
			GameState.get_equipment_inventory_amount(equipment_id)
		])
	return "、".join(parts)


# 作用：把英雄当前装备 id 转成显示文本。
# 参数：equipment_id 是装备 id。
# 返回：中文装备名；空字符串时返回“无”。
func _format_equipped_item_name(equipment_id: String) -> String:
	if equipment_id.is_empty():
		return "无"
	return DataLoader.get_equipment_name(equipment_id)


# 作用：生成简易文字经验条。
# 参数：current 是当前经验；target 是升级需求。
# 返回：例如 [###--]。
func _build_text_progress_bar(current: int, target: int) -> String:
	if target <= 0:
		return "[#####]"
	var ratio: float = clamp(float(current) / float(target), 0.0, 1.0)
	var filled: int = int(round(ratio * 5.0))
	var parts: Array[String] = []
	for index: int in range(5):
		if index < filled:
			parts.append("#")
		else:
			parts.append("-")
	return "[%s]" % "".join(parts)


# 作用：把小队状态值转换成中文展示文案。
# 参数：status 是小队运行时状态。
# 返回：中文状态文本；未知值保留原值。
func _format_squad_status(status: String) -> String:
	match status:
		"idle":
			return "待命"
		"assigned":
			return "执行中"
		"returning":
			return "返程中"
		_:
			return status


# 作用：把探险标签数组转换成中文展示文案。
# 参数：required_tags 是探险配置里的标签数组。
# 返回：中文标签文本；未知标签保留原值。
func _format_action_tags(required_tags: Array) -> String:
	var display_values: Array[String] = []
	for tag_value: Variant in required_tags:
		var tag: String = str(tag_value)
		display_values.append(str(HERO_SPECIALTY_NAMES.get(tag, tag)))
	return _join_values(display_values)


# 作用：把小队成员 id 数组转换成英雄中文名文本。
# 参数：hero_ids 是英雄 id 数组。
# 返回：中文名拼接结果；空数组返回“未编队”。
func _format_squad_hero_names(hero_ids: Array[String]) -> String:
	if hero_ids.is_empty():
		return "未编队"

	var hero_names: Array[String] = []
	for hero_id: String in hero_ids:
		var hero_config: Dictionary = DataLoader.get_hero_config(hero_id)
		hero_names.append(str(hero_config.get("name", hero_id)))
	return _join_values(hero_names)


# 作用：获取指定小队下一个可编入的英雄 id。
# 参数：squad_id 是小队 id。
# 返回：找到则返回英雄 id；没有候选时返回空字符串。
func _get_next_assignable_hero_id_for_squad(squad_id: String) -> String:
	for hero_id: String in DataLoader.get_hero_order():
		if GameState.can_assign_hero_to_squad(hero_id, squad_id):
			var assigned_squad_id: String = GameState.get_hero_assigned_squad_id(hero_id)
			if assigned_squad_id == squad_id:
				continue
			return hero_id
	return ""


# 作用：获取小队中文名。
# 参数：squad_id 是小队 id。
# 返回：小队中文名；缺失时返回 squad_id。
func _get_squad_name(squad_id: String) -> String:
	return DataLoader.get_squad_name(squad_id)


# 作用：把当前小队任务 id 转成玩家可读的中文任务名。
# 参数：task_id 是运行时记录的任务 id 或占位任务 id。
# 返回：中文任务名；未知时返回原始 task_id。
func _format_task_name(task_id: String) -> String:
	if task_id.is_empty():
		return "无"
	if task_id.begins_with("manual_dispatch_"):
		return "手动出发测试任务"
	return DataLoader.get_expedition_name(task_id)


# 作用：刷新当前目标面板。
# 参数：无。
# 返回：无。会同步任务标题、进度、奖励、建议，并刷新建筑状态面板。
func _refresh_quest_panel() -> void:
	if quest_title_label == null:
		return

	var title: String = ""
	var progress: String = ""
	var reward: String = ""
	var hint: String = ""
	title = str(QuestManager.get_current_quest_title())
	progress = str(QuestManager.get_current_quest_progress_text())
	reward = str(QuestManager.get_current_quest_reward_text())
	hint = str(QuestManager.get_current_quest_hint_text())

	if title.is_empty():
		title = "暂无目标"
	quest_title_label.text = title
	quest_progress_label.text = "进度：%s" % progress
	quest_reward_label.text = "奖励：%s" % reward
	if quest_hint_label != null:
		quest_hint_label.text = "建议：%s" % hint
	_refresh_building_status_panel()


# 作用：刷新右侧建筑状态列表。
# 参数：无。
# 返回：无。会显示建筑是否解锁、是否建造、等级和特殊功能入口。
func _refresh_building_status_panel() -> void:
	for building_id_value: Variant in building_status_labels.keys():
		var building_id: String = str(building_id_value)
		var label: Label = building_status_labels.get(building_id) as Label
		if label == null:
			continue

		var config: Dictionary = DataLoader.get_building_config(building_id)
		var building_name: String = str(config.get("name", building_id))
		var unlock_day: int = int(config.get("unlock_day", 1))
		var is_unlocked: bool = GameState.is_building_unlocked(building_id)
		var is_built: bool = GameState.is_building_built(building_id)
		var level: int = GameState.get_building_level(building_id)
		var status_text: String = ""

		if is_built:
			status_text = "已建造，等级 %d" % level
			if building_id == "training_ground" and BuildingManager.can_show_feature_unlocked("hero_squad"):
				status_text += "，英雄小队入口已解锁"
			if building_id == "outpost" and BuildingManager.can_show_feature_unlocked("map_outpost"):
				status_text += "，建前哨能力已解锁"
		elif is_unlocked:
			status_text = "已解锁，可建造"
		else:
			status_text = "未解锁，第 %d 天开放" % unlock_day

		label.text = "%s：%s" % [building_name, status_text]


# 作用：刷新近期日志面板。
# 参数：无。
# 返回：无。最多展示 report_labels 数量的日志，空位显示“暂无日志”。
func _refresh_report_panel() -> void:
	if report_labels.is_empty():
		return

	var reports: Array[String] = GameState.get_battle_reports()
	for index: int in range(report_labels.size()):
		var label: Label = report_labels[index]
		if label == null:
			continue
		if index < reports.size():
			label.text = reports[index]
		else:
			label.text = "暂无日志"


# 作用：从夜晚结算结果中过滤出需要展示的自动战斗战报。
# 参数：results_value 是当天探险结算结果数组。
# 返回：只保留带 report_lines 的结果数组。
func _extract_battle_results(results_value: Variant) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if typeof(results_value) != TYPE_ARRAY:
		return result
	var raw_results: Array = results_value as Array
	for item_value: Variant in raw_results:
		if typeof(item_value) != TYPE_DICTIONARY:
			continue
		var item: Dictionary = item_value as Dictionary
		var report_lines: Array = item.get("report_lines", []) as Array
		if report_lines.is_empty():
			continue
		result.append(item.duplicate(true))
	return result


# 作用：显示底部操作提示。
# 参数：message 是提示文本；success 表示成功还是失败。
# 返回：无。成功和失败会使用不同颜色。
func _show_action_message(message: String, success: bool) -> void:
	if action_message_label == null:
		return
	action_message_label.text = message
	if success:
		action_message_label.add_theme_color_override("font_color", Color(0.25, 0.75, 0.35, 1.0))
	else:
		action_message_label.add_theme_color_override("font_color", Color(1.0, 0.25, 0.18, 1.0))
