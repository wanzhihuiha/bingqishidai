extends Control

var detail_label: Label


# 作用：Godot 自动回调；地图场景加载完成后构建地图界面。
# 参数：无。
# 返回：无。
func _ready() -> void:
	print("[WorldMapView] ready")
	_build_ui()


# 作用：动态创建冰原地图页面。
# 参数：无。
# 返回：无。包含区域按钮网格、详情面板和底部操作栏。
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


# 作用：创建区域按钮网格。
# 参数：无。
# 返回：GridContainer，每个区域会生成一个按钮。
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


# 作用：创建右侧区域详情面板。
# 参数：无。
# 返回：PanelContainer，内部包含 detail_label。
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


# 作用：创建地图页面底部操作栏。
# 参数：无。
# 返回：HBoxContainer，包含返回避难所、派侦察队和侦察断松林按钮。
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


# 作用：加载所有区域配置并整理成数组。
# 参数：无。
# 返回：区域配置数组；每个元素是区域配置 Dictionary 的副本。
func _load_regions() -> Array:
	var configs: Dictionary = DataLoader.get_region_configs()
	var regions: Array = []
	for region_id_value: Variant in configs.keys():
		var region_id: String = str(region_id_value)
		var region: Dictionary = configs.get(region_id, {}) as Dictionary
		regions.append(region.duplicate(true))
	return regions


# 作用：响应区域按钮点击，更新右侧详情文本。
# 参数：region 是被点击区域的配置 Dictionary。
# 返回：无。
func _on_region_pressed(region: Dictionary) -> void:
	var region_id: String = str(region.get("id", "unknown"))
	print("[WorldMapView] button=region id=%s" % region_id)
	detail_label.text = _describe_region(region)


# 作用：把区域配置转换成多行详情文本。
# 参数：region 是区域配置 Dictionary。
# 返回：中文区域详情文本。
func _describe_region(region: Dictionary) -> String:
	var code: String = str(region.get("code", "--"))
	var name_text: String = str(region.get("name", "未知区域"))
	var owner: String = _get_owner_name(str(region.get("initial_owner", "unknown")))
	var danger: int = int(region.get("initial_danger_level", 0))
	var resources: Array = region.get("resource_ids", []) as Array
	var special_target: String = str(region.get("special_target", ""))
	var neighbors: Array = region.get("neighbors", []) as Array
	var can_build_outpost: bool = bool(region.get("can_build_outpost", false))

	return "区域详情\n\n编号：%s\n名称：%s\n归属：%s\n危险度：%s\n资源：%s\n特殊目标：%s\n可建前哨：%s\n相邻区域：%s" % [
		code,
		name_text,
		owner,
		_get_danger_text(danger),
		_join_resource_names(resources),
		_get_special_target_name(special_target),
		_get_yes_no_text(can_build_outpost),
		_join_region_names(neighbors)
	]


# 作用：把资源 id 数组转换成资源中文名文本。
# 参数：values 是资源 id 数组。
# 返回：用顿号连接的资源名称；数组为空时返回“无”。
func _join_resource_names(values: Array) -> String:
	if values.is_empty():
		return "无"

	var parts: PackedStringArray = PackedStringArray()
	for value: Variant in values:
		var resource_id: String = str(value)
		parts.append(GameState.get_resource_name(resource_id))

	return "、".join(parts)


# 作用：把区域 id 数组转换成区域中文名文本。
# 参数：values 是区域 id 数组。
# 返回：用顿号连接的区域名称；数组为空时返回“无”。
func _join_region_names(values: Array) -> String:
	if values.is_empty():
		return "无"

	var parts: PackedStringArray = PackedStringArray()
	for value: Variant in values:
		var region_id: String = str(value)
		var config: Dictionary = DataLoader.get_region_config(region_id)
		var code: String = str(config.get("code", ""))
		var region_name: String = str(config.get("name", region_id))
		if code.is_empty():
			parts.append(region_name)
		else:
			parts.append("%s %s" % [code, region_name])

	return "、".join(parts)


# 作用：把区域归属 id 转换成中文名。
# 参数：owner_id 是归属 id，例如 player、neutral、enemy。
# 返回：中文归属名；未知时返回“未知”。
func _get_owner_name(owner_id: String) -> String:
	match owner_id:
		"player":
			return "我方控制"
		"neutral":
			return "中立"
		"enemy":
			return "敌方控制"
		"contested":
			return "争夺中"
		_:
			return "未知"


# 作用：把危险度数字转换成中文说明。
# 参数：danger 是危险度整数。
# 返回：危险度文本，例如“4（高）”。
func _get_danger_text(danger: int) -> String:
	match danger:
		0:
			return "0（安全）"
		1:
			return "1（低）"
		2:
			return "2（中低）"
		3:
			return "3（中）"
		4:
			return "4（高）"
		5:
			return "5（极高）"
		_:
			return "%d（未知）" % danger


# 作用：把特殊目标 id 转换成中文名。
# 参数：target_id 是特殊目标 id，例如 intel、beacon。
# 返回：中文目标名；没有特殊目标时返回“无”。
func _get_special_target_name(target_id: String) -> String:
	match target_id:
		"intel":
			return "情报"
		"beacon":
			return "边境信标"
		"", "<null>":
			return "无"
		_:
			return "无"


# 作用：把布尔值转换成中文“可以/不可以”。
# 参数：value 是布尔值。
# 返回：true 返回“可以”，false 返回“不可以”。
func _get_yes_no_text(value: bool) -> String:
	if value:
		return "可以"
	return "不可以"


# 作用：响应“返回避难所”按钮。
# 参数：无。
# 返回：无。会切换回避难所场景。
func _on_back_pressed() -> void:
	print("[WorldMapView] button=back_to_shelter")
	SceneRouter.go_to_shelter()


# 作用：响应“派出侦察队”按钮。
# 参数：无。
# 返回：无。会标记第一支侦察队已派出，用于前期引导目标。
func _on_send_scout_pressed() -> void:
	print("[WorldMapView] button=send_scout_team")
	GameState.send_first_scout_team("world_map_send_scout_team")


# 作用：响应“侦察断松林”按钮。
# 参数：无。
# 返回：无。会标记第一个教学区域已侦察。
func _on_scout_first_region_pressed() -> void:
	print("[WorldMapView] button=scout_first_region")
	GameState.scout_region("a1_broken_pines", "world_map_scout_first_region")
