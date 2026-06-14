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


func _ready() -> void:
	print("[ShelterView] ready")
	_build_ui()


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
	var resources: Dictionary = _load_initial_resources()
	var hud: HBoxContainer = HBoxContainer.new()
	hud.add_theme_constant_override("separation", 14)
	hud.add_child(_make_hud_label("第 1 天"))

	for resource_id: String in RESOURCE_ORDER:
		var resource_name: String = str(RESOURCE_NAMES.get(resource_id, resource_id))
		var amount: int = int(resources.get(resource_id, 0))
		hud.add_child(_make_hud_label("%s：%d" % [resource_name, amount]))

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


func _load_initial_resources() -> Dictionary:
	var result: Dictionary = {}
	var file: FileAccess = FileAccess.open("res://data/resources.json", FileAccess.READ)
	if file == null:
		push_warning("[ShelterView] resources.json not found, using zero resources")
		return result

	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("[ShelterView] resources.json parse failed, using zero resources")
		return result

	var data: Dictionary = parsed as Dictionary
	var items: Array = data.get("items", []) as Array
	for item_value: Variant in items:
		if typeof(item_value) != TYPE_DICTIONARY:
			continue
		var item: Dictionary = item_value as Dictionary
		var resource_id: String = str(item.get("id", ""))
		if resource_id.is_empty():
			continue
		result[resource_id] = int(item.get("initial_amount", 0))

	return result


func _on_world_map_pressed() -> void:
	print("[ShelterView] button=world_map")
	SceneRouter.go_to_world_map()


func _on_end_day_pressed() -> void:
	print("[ShelterView] button=end_day")
	SceneRouter.go_to_result()
