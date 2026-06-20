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
const JOB_ORDER: Array[String] = ["worker", "hunter", "cook", "medic", "engineer"]
const NIGHT_SETTLEMENT_POPUP_SCRIPT: Script = preload("res://scripts/ui/NightSettlementPopup.gd")
const EVENT_POPUP_SCRIPT: Script = preload("res://scripts/ui/EventPopup.gd")
const BUILDING_PANEL_SCRIPT: Script = preload("res://scripts/shelter/BuildingPanel.gd")
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
	row.add_child(_make_center_panel())
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
	end_day_confirm_dialog.dialog_text = "结束一天后会进入夜晚结算，并推进到第 %d 天。\n是否继续？" % (GameState.day + 1)
	end_day_confirm_dialog.popup_centered()


# 作用：响应结束一天确认。
# 参数：无。
# 返回：无。会执行夜晚结算、刷新界面并显示结算弹窗。
func _on_end_day_confirmed() -> void:
	print("[ShelterView] confirm=end_day")
	var result: Dictionary = NightSettlementManager.settle_night()
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
	_show_action_message("英雄小队入口已解锁，正式编队功能将在后续章节接入。", true)


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
# 返回：无。会尝试展示当天事件。
func _on_night_settlement_popup_continued() -> void:
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


# 作用：刷新当前目标面板。
# 参数：无。
# 返回：无。会同步任务标题、进度、奖励，并刷新建筑状态面板。
func _refresh_quest_panel() -> void:
	if quest_title_label == null:
		return

	var title: String = ""
	var progress: String = ""
	var reward: String = ""
	title = str(QuestManager.get_current_quest_title())
	progress = str(QuestManager.get_current_quest_progress_text())
	reward = str(QuestManager.get_current_quest_reward_text())

	if title.is_empty():
		title = "暂无目标"
	quest_title_label.text = title
	quest_progress_label.text = "进度：%s" % progress
	quest_reward_label.text = "奖励：%s" % reward
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
