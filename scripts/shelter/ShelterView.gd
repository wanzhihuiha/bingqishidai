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
const COLLECT_COOLDOWN_SECONDS: float = 10.0
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

	layout.add_child(_make_hud())
	layout.add_child(_make_center_panel())
	layout.add_child(_make_action_bar())


func _make_hud() -> HBoxContainer:
	var hud: HBoxContainer = HBoxContainer.new()
	hud.add_theme_constant_override("separation", 14)
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


func _play_furnace_upgrade_feedback(success: bool) -> void:
	if furnace_upgrade_button == null:
		return

	var target_color: Color = Color(0.45, 1.0, 0.65, 1.0)
	if not success:
		target_color = Color(1.0, 0.55, 0.45, 1.0)

	var tween: Tween = create_tween()
	tween.tween_property(furnace_upgrade_button, "modulate", target_color, 0.1)
	tween.tween_property(furnace_upgrade_button, "modulate", Color.WHITE, 0.2)


func _make_action_bar() -> HBoxContainer:
	var actions: HBoxContainer = HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_theme_constant_override("separation", 16)

	var world_button: Button = Button.new()
	world_button.text = "进入冰原地图"
	world_button.custom_minimum_size = Vector2(180, 42)
	world_button.pressed.connect(_on_world_map_pressed)
	actions.add_child(world_button)

	var end_day_button: Button = Button.new()
	end_day_button.text = "结束一天"
	end_day_button.custom_minimum_size = Vector2(180, 42)
	end_day_button.pressed.connect(_on_end_day_pressed)
	actions.add_child(end_day_button)

	return actions


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


func _on_world_map_pressed() -> void:
	print("[ShelterView] button=world_map")
	SceneRouter.go_to_world_map()


func _on_end_day_pressed() -> void:
	print("[ShelterView] button=end_day")
	SceneRouter.go_to_result()
