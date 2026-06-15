extends Control

var detail_label: Label


func _ready() -> void:
	print("[WorldMapView] ready")
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
	layout.add_theme_constant_override("separation", 16)
	root.add_child(layout)

	var title: Label = Label.new()
	title.text = "冰原地图"
	title.add_theme_font_size_override("font_size", 30)
	layout.add_child(title)

	var content: HBoxContainer = HBoxContainer.new()
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 18)
	layout.add_child(content)

	content.add_child(_make_region_grid())
	content.add_child(_make_detail_panel())
	layout.add_child(_make_action_bar())


func _make_region_grid() -> GridContainer:
	var regions: Array = _load_regions()
	var grid: GridContainer = GridContainer.new()
	grid.columns = 3
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)

	for region_value: Variant in regions:
		if typeof(region_value) != TYPE_DICTIONARY:
			continue
		var region: Dictionary = region_value as Dictionary
		var code: String = str(region.get("code", "--"))
		var name_text: String = str(region.get("name", "未知区域"))
		var button: Button = Button.new()
		button.text = "%s %s" % [code, name_text]
		button.custom_minimum_size = Vector2(150, 48)
		button.pressed.connect(_on_region_pressed.bind(region))
		grid.add_child(button)

	return grid


func _make_detail_panel() -> PanelContainer:
	var panel: PanelContainer = PanelContainer.new()
	panel.custom_minimum_size = Vector2(300, 320)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL

	detail_label = Label.new()
	detail_label.text = "区域详情占位\n\n点击左侧区域查看占位信息。"
	detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel.add_child(detail_label)

	return panel


func _make_action_bar() -> HBoxContainer:
	var actions: HBoxContainer = HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_END

	var back_button: Button = Button.new()
	back_button.text = "返回避难所"
	back_button.custom_minimum_size = Vector2(160, 42)
	back_button.pressed.connect(_on_back_pressed)
	actions.add_child(back_button)

	var scout_button: Button = Button.new()
	scout_button.text = "派出侦察队"
	scout_button.custom_minimum_size = Vector2(160, 42)
	scout_button.pressed.connect(_on_send_scout_pressed)
	actions.add_child(scout_button)

	var region_button: Button = Button.new()
	region_button.text = "侦察断松林"
	region_button.custom_minimum_size = Vector2(160, 42)
	region_button.pressed.connect(_on_scout_first_region_pressed)
	actions.add_child(region_button)

	return actions


func _load_regions() -> Array:
	var configs: Dictionary = DataLoader.get_region_configs()
	var regions: Array = []
	for region_id_value: Variant in configs.keys():
		var region_id: String = str(region_id_value)
		var region: Dictionary = configs.get(region_id, {}) as Dictionary
		regions.append(region.duplicate(true))
	return regions


func _on_region_pressed(region: Dictionary) -> void:
	var region_id: String = str(region.get("id", "unknown"))
	print("[WorldMapView] button=region id=%s" % region_id)
	detail_label.text = _describe_region(region)


func _describe_region(region: Dictionary) -> String:
	var code: String = str(region.get("code", "--"))
	var name_text: String = str(region.get("name", "未知区域"))
	var owner: String = str(region.get("initial_owner", "unknown"))
	var danger: int = int(region.get("initial_danger_level", 0))
	var resources: Array = region.get("resource_ids", []) as Array
	var neighbors: Array = region.get("neighbors", []) as Array

	return "区域详情占位\n\n编号：%s\n名称：%s\n初始归属：%s\n危险度：%d\n资源：%s\n相邻区域：%s" % [
		code,
		name_text,
		owner,
		danger,
		_join_values(resources),
		_join_values(neighbors)
	]


func _join_values(values: Array) -> String:
	if values.is_empty():
		return "无"

	var parts: PackedStringArray = PackedStringArray()
	for value: Variant in values:
		parts.append(str(value))

	return "、".join(parts)


func _on_back_pressed() -> void:
	print("[WorldMapView] button=back_to_shelter")
	SceneRouter.go_to_shelter()


func _on_send_scout_pressed() -> void:
	print("[WorldMapView] button=send_scout_team")
	GameState.send_first_scout_team("world_map_send_scout_team")


func _on_scout_first_region_pressed() -> void:
	print("[WorldMapView] button=scout_first_region")
	GameState.scout_region("a1_broken_pines", "world_map_scout_first_region")
