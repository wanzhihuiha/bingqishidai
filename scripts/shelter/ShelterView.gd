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

var day_label: Label
var resource_labels: Dictionary = {}
var population_label: Label
var healthy_label: Label
var sick_label: Label
var temperature_label: Label


func _ready() -> void:
	print("[ShelterView] ready")
	GameState.ensure_started()
	if not GameState.state_changed.is_connected(_refresh_hud):
		GameState.state_changed.connect(_refresh_hud)
	if not GameState.resources_changed.is_connected(_refresh_hud):
		GameState.resources_changed.connect(_refresh_hud)
	_build_ui()
	_refresh_hud()


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

	grid.add_child(_make_placeholder("寒炉", "营地核心占位"))
	grid.add_child(_make_placeholder("建筑位 1", "基础生产建筑占位"))
	grid.add_child(_make_placeholder("建筑位 2", "生存保障建筑占位"))
	grid.add_child(_make_placeholder("建筑位 3", "进阶功能建筑占位"))

	return panel


func _make_placeholder(title_text: String, body_text: String) -> PanelContainer:
	var panel: PanelContainer = PanelContainer.new()
	panel.custom_minimum_size = Vector2(220, 140)

	var box: VBoxContainer = VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)

	var title: Label = Label.new()
	title.text = title_text
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	box.add_child(title)

	var body: Label = Label.new()
	body.text = body_text
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(body)

	return panel


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
		temperature_label.text = "温度评分：%d" % GameState.temperature_score


func _on_world_map_pressed() -> void:
	print("[ShelterView] button=world_map")
	SceneRouter.go_to_world_map()


func _on_end_day_pressed() -> void:
	print("[ShelterView] button=end_day")
	SceneRouter.go_to_result()
