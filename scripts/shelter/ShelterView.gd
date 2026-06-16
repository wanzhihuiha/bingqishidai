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
const COLLECT_COOLDOWN_SECONDS: float = 10.0
const NIGHT_SETTLEMENT_POPUP_SCRIPT: Script = preload("res://scripts/ui/NightSettlementPopup.gd")
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
var furnace_level_label: Label
var furnace_temperature_label: Label
var furnace_cost_label: Label
var furnace_message_label: Label
var furnace_upgrade_button: Button
var collect_cards: Dictionary = {}
var quest_title_label: Label
var quest_progress_label: Label
var quest_reward_label: Label
var building_status_labels: Dictionary = {}
var action_message_label: Label
var job_total_label: Label
var job_assignable_label: Label
var job_rows: Dictionary = {}
var job_preview_labels: Dictionary = {}


func _ready() -> void:
	print("[ShelterView] ready")
	set_process(true)
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


func _process(delta: float) -> void:
	_update_collect_cooldowns(delta)


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
	content.add_theme_constant_override("separation", 16)
	layout.add_child(content)

	var left_column: VBoxContainer = VBoxContainer.new()
	left_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_column.add_theme_constant_override("separation", 16)
	content.add_child(left_column)

	left_column.add_child(_make_hud())
	left_column.add_child(_make_job_panel())
	left_column.add_child(_make_center_panel())
	left_column.add_child(_make_action_bar())
	content.add_child(_make_quest_panel())


func _make_hud() -> GridContainer:
	var hud: GridContainer = GridContainer.new()
	hud.columns = 4
	hud.add_theme_constant_override("h_separation", 12)
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


func _make_hud_label(text: String) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 18)
	return label


func _make_job_panel() -> PanelContainer:
	var panel: PanelContainer = PanelContainer.new()

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


func _make_center_panel() -> PanelContainer:
	var panel: PanelContainer = PanelContainer.new()
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var grid: GridContainer = GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 16)
	panel.add_child(grid)

	grid.add_child(_make_furnace_card())
	for config_value: Dictionary in COLLECT_BUILDINGS:
		grid.add_child(_make_collect_card(config_value))

	return panel


func _make_furnace_card() -> PanelContainer:
	var panel: PanelContainer = PanelContainer.new()
	panel.custom_minimum_size = Vector2(280, 230)

	var box: VBoxContainer = VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)

	var title: Label = Label.new()
	title.text = "寒炉"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	box.add_child(title)

	furnace_level_label = Label.new()
	furnace_level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(furnace_level_label)

	furnace_temperature_label = Label.new()
	furnace_temperature_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(furnace_temperature_label)

	furnace_cost_label = Label.new()
	furnace_cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	furnace_cost_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(furnace_cost_label)

	furnace_message_label = Label.new()
	furnace_message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	furnace_message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	furnace_message_label.add_theme_font_size_override("font_size", 16)
	box.add_child(furnace_message_label)

	furnace_upgrade_button = Button.new()
	furnace_upgrade_button.text = "升级寒炉"
	furnace_upgrade_button.custom_minimum_size = Vector2(130, 36)
	furnace_upgrade_button.pressed.connect(_on_furnace_upgrade_pressed)
	box.add_child(furnace_upgrade_button)

	return panel


func _make_collect_card(config: Dictionary) -> PanelContainer:
	var panel: PanelContainer = PanelContainer.new()
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
		"status": status,
		"cooldown_left": 0.0
	}

	return panel


func _update_collect_cooldowns(delta: float) -> void:
	for resource_id_value: Variant in collect_cards.keys():
		var resource_id: String = str(resource_id_value)
		var card: Dictionary = collect_cards.get(resource_id, {}) as Dictionary
		var cooldown_left: float = float(card.get("cooldown_left", 0.0))
		if cooldown_left <= 0.0:
			continue

		cooldown_left = max(0.0, cooldown_left - delta)
		card["cooldown_left"] = cooldown_left
		collect_cards[resource_id] = card
		_refresh_collect_card(resource_id)


func _refresh_collect_card(resource_id: String) -> void:
	var card: Dictionary = collect_cards.get(resource_id, {}) as Dictionary
	var button: Button = card.get("button") as Button
	var status: Label = card.get("status") as Label
	var cooldown_left: float = float(card.get("cooldown_left", 0.0))
	if button == null or status == null:
		return

	if cooldown_left > 0.0:
		button.disabled = true
		status.text = "冷却中：%.1f 秒" % cooldown_left
		return

	button.disabled = false
	if GameState.is_resource_near_max(resource_id):
		status.text = "仓库快满了"
	else:
		status.text = "可收取"


func _refresh_furnace_card() -> void:
	if furnace_level_label == null:
		return

	var max_level: int = BuildingManager.get_furnace_max_level()
	var current_level: int = GameState.furnace_level
	furnace_level_label.text = "等级：%d / %d" % [current_level, max_level]

	if furnace_temperature_label != null:
		furnace_temperature_label.text = "温度评分：%d（%s）" % [
			GameState.temperature_score,
			GameState.get_temperature_status()
		]

	if furnace_cost_label != null:
		furnace_cost_label.text = "升级所需：%s" % BuildingManager.get_furnace_upgrade_cost_text()

	if furnace_upgrade_button != null:
		furnace_upgrade_button.disabled = current_level >= max_level
		if current_level >= max_level:
			furnace_upgrade_button.text = "已满级"
		else:
			furnace_upgrade_button.text = "升级寒炉"


func _on_collect_pressed(resource_id: String, amount: int) -> void:
	var card: Dictionary = collect_cards.get(resource_id, {}) as Dictionary
	var cooldown_left: float = float(card.get("cooldown_left", 0.0))
	if cooldown_left > 0.0:
		return

	var before: int = GameState.get_resource_amount(resource_id)
	GameState.add_resource(resource_id, amount, "collect_resource")
	GameState.mark_resource_collected(resource_id, "collect_resource")
	var after: int = GameState.get_resource_amount(resource_id)
	print("collect_resource resource_id=%s amount=%d before=%d after=%d" % [resource_id, amount, before, after])
	card["cooldown_left"] = COLLECT_COOLDOWN_SECONDS
	collect_cards[resource_id] = card
	_refresh_collect_card(resource_id)
	_play_collect_feedback(resource_id, amount)


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


func _on_furnace_upgrade_pressed() -> void:
	var result: Dictionary = BuildingManager.upgrade_furnace()
	var message: String = str(result.get("message", ""))
	var success: bool = bool(result.get("success", false))
	if furnace_message_label != null:
		furnace_message_label.text = message
		if success:
			furnace_message_label.add_theme_color_override("font_color", Color(0.25, 0.75, 0.35, 1.0))
		else:
			furnace_message_label.add_theme_color_override("font_color", Color(1.0, 0.25, 0.18, 1.0))
	_play_furnace_upgrade_feedback(success)
	_refresh_hud()


func build_kitchen() -> void:
	var result: Dictionary = BuildingManager.build_building("kitchen")
	var message: String = str(result.get("message", ""))
	var success: bool = bool(result.get("success", false))
	_show_action_message(message, success)
	_refresh_hud()


func assign_three_jobs() -> void:
	GameState.assign_jobs_total(3, "assign_three_jobs")
	var assigned: int = GameState.assigned_jobs_total
	var success: bool = assigned >= 3
	if success:
		_show_action_message("已分配 3 名幸存者岗位", true)
	else:
		_show_action_message("可分配人口不足 3 名", false)
	_refresh_quest_panel()


func _play_furnace_upgrade_feedback(success: bool) -> void:
	if furnace_upgrade_button == null:
		return

	var target_color: Color = Color(0.45, 1.0, 0.65, 1.0)
	if not success:
		target_color = Color(1.0, 0.55, 0.45, 1.0)

	var tween: Tween = create_tween()
	tween.tween_property(furnace_upgrade_button, "modulate", target_color, 0.1)
	tween.tween_property(furnace_upgrade_button, "modulate", Color.WHITE, 0.2)


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

	var end_day_button: Button = Button.new()
	end_day_button.text = "结束一天"
	end_day_button.custom_minimum_size = Vector2(150, 42)
	end_day_button.pressed.connect(_on_end_day_pressed)
	buttons.add_child(end_day_button)

	var kitchen_button: Button = Button.new()
	kitchen_button.text = "建造厨房"
	kitchen_button.custom_minimum_size = Vector2(150, 42)
	kitchen_button.pressed.connect(_on_build_kitchen_pressed)
	buttons.add_child(kitchen_button)

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

	return panel


func _add_building_status_row(container: VBoxContainer, building_id: String) -> void:
	var label: Label = Label.new()
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	container.add_child(label)
	building_status_labels[building_id] = label


func _refresh_hud() -> void:
	if day_label != null:
		day_label.text = "第 %d 天" % GameState.day

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

	_refresh_furnace_card()
	_refresh_job_panel()
	_refresh_quest_panel()


func _on_world_map_pressed() -> void:
	print("[ShelterView] button=world_map")
	SceneRouter.go_to_world_map()


func _on_end_day_pressed() -> void:
	print("[ShelterView] button=end_day")
	var result: Dictionary = NightSettlementManager.settle_night()
	_refresh_hud()
	_show_night_settlement_popup(result)


func _show_night_settlement_popup(result: Dictionary) -> void:
	var popup: CanvasLayer = NIGHT_SETTLEMENT_POPUP_SCRIPT.new() as CanvasLayer
	if popup == null:
		push_error("[ShelterView] failed to create night settlement popup")
		return

	add_child(popup)
	if popup.has_method("show_result"):
		popup.call("show_result", result)


func _on_build_kitchen_pressed() -> void:
	print("[ShelterView] button=build_kitchen")
	build_kitchen()


func _on_assign_jobs_pressed() -> void:
	print("[ShelterView] button=assign_jobs")
	assign_three_jobs()


func _on_job_adjust_pressed(job_id: String, delta: int) -> void:
	var changed: bool = GameState.add_job_assignment(job_id, delta, "job_panel_adjust")
	if changed:
		_show_action_message("%s 已调整" % JobManager.get_job_name(job_id), true)
	else:
		_show_action_message("%s 无法继续调整" % JobManager.get_job_name(job_id), false)
	_refresh_hud()


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
		(job_preview_labels.get("cook") as Label).text = "厨师：食物节省 %d，希望值最多 +%d" % [
			int(preview.get("food_saved", 0)),
			int(preview.get("hope_bonus", 0))
		]
	if job_preview_labels.has("medic"):
		(job_preview_labels.get("medic") as Label).text = "医护：治疗点 %d" % int(preview.get("heal_points", 0))
	if job_preview_labels.has("engineer"):
		(job_preview_labels.get("engineer") as Label).text = "工程师：零件 +%d，煤炭节省 %d" % [
			int(resources.get("parts", 0)),
			int(preview.get("coal_saved", 0))
		]


func _get_job_note_text(job_id: String, preview: Dictionary, resources: Dictionary) -> String:
	match job_id:
		"worker":
			return "预计 +%d 木材" % int(resources.get("wood", 0))
		"hunter":
			return "预计 +%d 食物" % int(resources.get("food", 0))
		"cook":
			return "节省率 %.0f%%" % (float(preview.get("food_save_rate", 0.0)) * 100.0)
		"medic":
			return "治疗点 %d" % int(preview.get("heal_points", 0))
		"engineer":
			return "零件 +%d，煤炭 -%d" % [
				int(resources.get("parts", 0)),
				int(preview.get("coal_saved", 0))
			]
		_:
			return "岗位效果预览"


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
		elif is_unlocked:
			status_text = "已解锁"
		else:
			status_text = "未解锁，第 %d 天开放" % unlock_day

		label.text = "%s：%s" % [building_name, status_text]


func _show_action_message(message: String, success: bool) -> void:
	if action_message_label == null:
		return
	action_message_label.text = message
	if success:
		action_message_label.add_theme_color_override("font_color", Color(0.25, 0.75, 0.35, 1.0))
	else:
		action_message_label.add_theme_color_override("font_color", Color(1.0, 0.25, 0.18, 1.0))
