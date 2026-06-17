extends PanelContainer

signal action_finished(message: String, success: bool)

var message_label: Label
var card_rows: Dictionary = {}


# 作用：Godot 自动回调；构建建筑面板、连接状态信号，并刷新全部建筑卡片。
# 参数：无。
# 返回：无。
func _ready() -> void:
	_build_ui()
	_connect_state_signals()
	refresh()


# 作用：刷新所有建筑卡片显示。
# 参数：无。
# 返回：无。会按 DataLoader 中的建筑顺序逐个刷新。
func refresh() -> void:
	for building_id: String in DataLoader.get_building_order():
		_refresh_card(building_id)


# 作用：动态创建建筑管理面板 UI。
# 参数：无。
# 返回：无。会创建标题、提示、消息栏、滚动区域和建筑卡片网格。
func _build_ui() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL

	var outer: VBoxContainer = VBoxContainer.new()
	outer.add_theme_constant_override("separation", 10)
	add_child(outer)

	var title: Label = Label.new()
	title.text = "建筑管理"
	title.add_theme_font_size_override("font_size", 24)
	outer.add_child(title)

	var tip: Label = Label.new()
	tip.text = "每天最多完成 1 次建筑建设。0 级建筑点击建造，已建建筑继续升级。"
	tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	outer.add_child(tip)

	message_label = Label.new()
	message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	outer.add_child(message_label)

	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_child(scroll)

	var grid: GridContainer = GridContainer.new()
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	scroll.add_child(grid)

	for building_id: String in DataLoader.get_building_order():
		grid.add_child(_make_building_card(building_id))


# 作用：创建一个建筑卡片。
# 参数：building_id 是建筑 id。
# 返回：包含标题、状态、效果、成本、收益、功能和按钮的 PanelContainer。
func _make_building_card(building_id: String) -> PanelContainer:
	var card: PanelContainer = PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.custom_minimum_size = Vector2(300, 220)

	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	card.add_child(box)

	var title: Label = Label.new()
	title.add_theme_font_size_override("font_size", 20)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(title)

	var status: Label = Label.new()
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(status)

	var current_effect: Label = Label.new()
	current_effect.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(current_effect)

	var next_cost: Label = Label.new()
	next_cost.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(next_cost)

	var next_benefit: Label = Label.new()
	next_benefit.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(next_benefit)

	var feature: Label = Label.new()
	feature.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(feature)

	var button: Button = Button.new()
	button.custom_minimum_size = Vector2(120, 34)
	button.pressed.connect(_on_building_action_pressed.bind(building_id, button))
	box.add_child(button)

	card_rows[building_id] = {
		"title": title,
		"status": status,
		"current_effect": current_effect,
		"next_cost": next_cost,
		"next_benefit": next_benefit,
		"feature": feature,
		"button": button
	}
	return card


# 作用：刷新指定建筑卡片的文本和按钮状态。
# 参数：building_id 是建筑 id。
# 返回：无。建筑未解锁、满级、当天已操作都会影响按钮状态。
func _refresh_card(building_id: String) -> void:
	var row: Dictionary = card_rows.get(building_id, {}) as Dictionary
	if row.is_empty():
		return

	var config: Dictionary = DataLoader.get_building_config(building_id)
	var building_name: String = str(config.get("name", building_id))
	var max_level: int = BuildingManager.get_building_max_level(building_id)
	var current_level: int = GameState.get_building_level(building_id)
	var is_unlocked: bool = GameState.is_building_unlocked(building_id)
	var title: Label = row.get("title") as Label
	var status: Label = row.get("status") as Label
	var current_effect: Label = row.get("current_effect") as Label
	var next_cost: Label = row.get("next_cost") as Label
	var next_benefit: Label = row.get("next_benefit") as Label
	var feature: Label = row.get("feature") as Label
	var button: Button = row.get("button") as Button
	if title == null or status == null or current_effect == null or next_cost == null or next_benefit == null or feature == null or button == null:
		return

	title.text = "%s  Lv.%d / %d" % [building_name, current_level, max_level]
	if not is_unlocked:
		status.text = BuildingManager.get_unlock_reason_text(building_id)
		current_effect.text = "当前效果：未生效"
		next_cost.text = ""
		next_benefit.text = ""
		feature.text = ""
		button.text = "未解锁"
		button.disabled = true
		return

	if current_level <= 0:
		status.text = "状态：已解锁，可建造"
	else:
		status.text = "状态：已建造，等级 %d" % current_level

	current_effect.text = "当前效果：%s" % BuildingManager.get_current_effect_text(building_id)
	feature.text = _get_feature_text(building_id)
	if current_level >= max_level:
		next_cost.text = "升级所需：已满级"
		next_benefit.text = "下一收益：已获得全部收益"
		button.text = "已满级"
		button.disabled = true
		return

	next_cost.text = "%s所需：%s" % [
		BuildingManager.get_building_action_label(building_id),
		BuildingManager.get_next_cost_text(building_id)
	]
	next_benefit.text = "下一收益：%s" % BuildingManager.get_next_benefit_text(building_id)
	button.text = BuildingManager.get_building_action_label(building_id)
	button.disabled = GameState.was_building_upgraded_today()
	if GameState.was_building_upgraded_today():
		button.text = "明天继续"


# 作用：响应建筑卡片上的建造/升级按钮。
# 参数：building_id 是建筑 id；button 是被点击的按钮节点。
# 返回：无。会调用 BuildingManager，展示结果，播放反馈，并发出 action_finished 信号。
func _on_building_action_pressed(building_id: String, button: Button) -> void:
	var result: Dictionary = BuildingManager.upgrade_building(building_id)
	var success: bool = bool(result.get("success", false))
	var message: String = str(result.get("message", ""))
	var unlocks: Array = result.get("unlocks", []) as Array
	if success and not unlocks.is_empty():
		message += "；" + _join_values(unlocks)
	_show_message(message, success)
	_play_button_feedback(button, success)
	refresh()
	action_finished.emit(message, success)


# 作用：在建筑面板顶部展示操作结果。
# 参数：message 是提示文本；success 表示本次操作是否成功。
# 返回：无。成功和失败会使用不同颜色。
func _show_message(message: String, success: bool) -> void:
	if message_label == null:
		return
	message_label.text = message
	if success:
		message_label.add_theme_color_override("font_color", Color(0.25, 0.75, 0.35, 1.0))
	else:
		message_label.add_theme_color_override("font_color", Color(1.0, 0.25, 0.18, 1.0))


# 作用：播放按钮颜色反馈。
# 参数：button 是被点击的按钮；success 表示使用成功色还是失败色。
# 返回：无。通过 Tween 做一次短暂闪色。
func _play_button_feedback(button: Button, success: bool) -> void:
	if button == null:
		return
	var target_color: Color = Color(0.45, 1.0, 0.65, 1.0)
	if not success:
		target_color = Color(1.0, 0.55, 0.45, 1.0)
	var tween: Tween = create_tween()
	tween.tween_property(button, "modulate", target_color, 0.1)
	tween.tween_property(button, "modulate", Color.WHITE, 0.2)


# 作用：获取建筑解锁功能的补充文本。
# 参数：building_id 是建筑 id。
# 返回：功能入口说明；没有特殊解锁时返回空字符串。
func _get_feature_text(building_id: String) -> String:
	if building_id == "training_ground" and BuildingManager.can_show_feature_unlocked("hero_squad"):
		return "入口：英雄小队系统已解锁"
	if building_id == "outpost" and BuildingManager.can_show_feature_unlocked("map_outpost"):
		return "入口：地图建前哨能力已解锁"
	return ""


# 作用：连接全局状态信号，让建筑面板随游戏状态自动刷新。
# 参数：无。
# 返回：无。已连接时不会重复连接。
func _connect_state_signals() -> void:
	if not GameState.state_changed.is_connected(refresh):
		GameState.state_changed.connect(refresh)
	if not GameState.resources_changed.is_connected(refresh):
		GameState.resources_changed.connect(refresh)
	if not GameState.quest_relevant_state_changed.is_connected(refresh):
		GameState.quest_relevant_state_changed.connect(refresh)


# 作用：把任意数组转换成中文分号连接文本。
# 参数：values 是任意值数组。
# 返回：拼接后的字符串。
func _join_values(values: Array) -> String:
	var parts: PackedStringArray = PackedStringArray()
	for value: Variant in values:
		parts.append(str(value))
	return "；".join(parts)
