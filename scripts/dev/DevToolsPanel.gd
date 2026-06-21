extends Control

const DEBUG_PRESET_LOADER_SCRIPT: Script = preload("res://scripts/dev/DebugPresetLoader.gd")
const DEBUG_SCENARIO_RUNNER_SCRIPT: Script = preload("res://scripts/dev/DebugScenarioRunner.gd")

var preset_loader = null
var scenario_runner = null
var entries_container: VBoxContainer = null
var feedback_label: Label = null
var preset_buttons_by_key: Dictionary = {}


# 作用：Godot 自动回调；创建调试面板并初始化加载器与执行器。
# 参数：无。
# 返回：无。
func _ready() -> void:
	preset_loader = DEBUG_PRESET_LOADER_SCRIPT.new()
	scenario_runner = DEBUG_SCENARIO_RUNNER_SCRIPT.new(preset_loader)
	_build_ui()
	hide()


# 作用：打开调试面板并刷新预设列表。
# 参数：无。
# 返回：无。
func open_panel() -> void:
	show()
	move_to_front()
	_refresh_preset_entries()


# 作用：关闭调试面板。
# 参数：无。
# 返回：无。
func close_panel() -> void:
	hide()


# 作用：动态创建调试面板界面。
# 参数：无。
# 返回：无。
func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	var overlay: ColorRect = ColorRect.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0, 0, 0, 0.55)
	add_child(overlay)

	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel: PanelContainer = PanelContainer.new()
	panel.custom_minimum_size = Vector2(860, 560)
	center.add_child(panel)

	var layout: VBoxContainer = VBoxContainer.new()
	layout.custom_minimum_size = Vector2(860, 560)
	layout.add_theme_constant_override("separation", 14)
	panel.add_child(layout)

	var top_margin: MarginContainer = MarginContainer.new()
	top_margin.add_theme_constant_override("margin_left", 20)
	top_margin.add_theme_constant_override("margin_top", 20)
	top_margin.add_theme_constant_override("margin_right", 20)
	top_margin.add_theme_constant_override("margin_bottom", 0)
	layout.add_child(top_margin)

	var top_row: HBoxContainer = HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 12)
	top_margin.add_child(top_row)

	var title: Label = Label.new()
	title.text = "开发调试"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 28)
	top_row.add_child(title)

	var close_button: Button = Button.new()
	close_button.text = "关闭"
	close_button.custom_minimum_size = Vector2(100, 40)
	close_button.pressed.connect(close_panel)
	top_row.add_child(close_button)

	var desc_margin: MarginContainer = MarginContainer.new()
	desc_margin.add_theme_constant_override("margin_left", 20)
	desc_margin.add_theme_constant_override("margin_top", 0)
	desc_margin.add_theme_constant_override("margin_right", 20)
	desc_margin.add_theme_constant_override("margin_bottom", 0)
	layout.add_child(desc_margin)

	var desc: Label = Label.new()
	desc.text = "仅开发测试使用，不影响正式玩法。选择一个预设后，可以只载入状态，或载入后直接进入目标页面。"
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_margin.add_child(desc)

	var scroll_margin: MarginContainer = MarginContainer.new()
	scroll_margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll_margin.add_theme_constant_override("margin_left", 20)
	scroll_margin.add_theme_constant_override("margin_top", 0)
	scroll_margin.add_theme_constant_override("margin_right", 20)
	scroll_margin.add_theme_constant_override("margin_bottom", 0)
	layout.add_child(scroll_margin)

	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll_margin.add_child(scroll)

	entries_container = VBoxContainer.new()
	entries_container.add_theme_constant_override("separation", 12)
	scroll.add_child(entries_container)

	var bottom_margin: MarginContainer = MarginContainer.new()
	bottom_margin.add_theme_constant_override("margin_left", 20)
	bottom_margin.add_theme_constant_override("margin_top", 0)
	bottom_margin.add_theme_constant_override("margin_right", 20)
	bottom_margin.add_theme_constant_override("margin_bottom", 20)
	layout.add_child(bottom_margin)

	feedback_label = Label.new()
	feedback_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	feedback_label.text = "等待执行预设。"
	bottom_margin.add_child(feedback_label)


# 作用：刷新调试预设列表，并把加载错误显示到反馈区。
# 参数：无。
# 返回：无。
func _refresh_preset_entries() -> void:
	if entries_container == null or feedback_label == null:
		return

	preset_buttons_by_key = {}
	for child: Node in entries_container.get_children():
		child.queue_free()

	var loaded: bool = bool(preset_loader.reload())
	var errors: Array[String] = preset_loader.get_last_errors()
	if not loaded:
		feedback_label.text = _build_error_text(errors)
		return

	var presets: Array[Dictionary] = preset_loader.get_preset_list()
	if presets.is_empty():
		feedback_label.text = "没有可用的调试预设。"
		return

	for preset: Dictionary in presets:
		entries_container.add_child(_build_preset_entry(preset))

	if errors.is_empty():
		feedback_label.text = "已加载 %d 个调试预设。" % presets.size()
	else:
		feedback_label.text = _build_error_text(errors)


# 作用：创建单个调试预设的显示条目。
# 参数：preset 是预设 Dictionary。
# 返回：可直接挂到列表里的 Control。
func _build_preset_entry(preset: Dictionary) -> Control:
	var wrapper: PanelContainer = PanelContainer.new()
	var preset_id: String = str(preset.get("id", ""))

	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_bottom", 12)
	wrapper.add_child(margin)

	var layout: VBoxContainer = VBoxContainer.new()
	layout.add_theme_constant_override("separation", 8)
	margin.add_child(layout)

	var name_label: Label = Label.new()
	name_label.text = str(preset.get("name", "未命名预设"))
	name_label.add_theme_font_size_override("font_size", 20)
	layout.add_child(name_label)

	var desc_label: Label = Label.new()
	desc_label.text = str(preset.get("description", ""))
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	layout.add_child(desc_label)

	var button_row: HBoxContainer = HBoxContainer.new()
	button_row.add_theme_constant_override("separation", 10)
	layout.add_child(button_row)

	var load_button: Button = Button.new()
	load_button.text = "载入"
	load_button.custom_minimum_size = Vector2(120, 38)
	load_button.pressed.connect(_on_preset_pressed.bind(preset_id, false))
	button_row.add_child(load_button)

	var load_and_enter_button: Button = Button.new()
	load_and_enter_button.text = "载入并进入页面"
	load_and_enter_button.custom_minimum_size = Vector2(180, 38)
	load_and_enter_button.pressed.connect(_on_preset_pressed.bind(preset_id, true))
	button_row.add_child(load_and_enter_button)

	preset_buttons_by_key["%s:load" % preset_id] = load_button
	preset_buttons_by_key["%s:enter" % preset_id] = load_and_enter_button

	return wrapper


# 作用：响应调试预设按钮，执行预设并把结果写到反馈区。
# 参数：preset_id 是预设 id；open_target_scene 表示是否进入目标页面。
# 返回：无。
func _on_preset_pressed(preset_id: String, open_target_scene: bool) -> void:
	if scenario_runner == null or feedback_label == null:
		return
	var result: Dictionary = scenario_runner.run_preset(preset_id, open_target_scene)
	feedback_label.text = _build_result_text(result)


# 作用：把执行结果整理成面板底部可读文本。
# 参数：result 是统一结果 Dictionary。
# 返回：多行中文说明。
func _build_result_text(result: Dictionary) -> String:
	var lines: Array[String] = []
	var success: bool = bool(result.get("success", false))
	var preset_id: String = str(result.get("preset_id", ""))
	lines.append("预设：%s" % _get_preset_display_name(preset_id))
	lines.append("结果：%s" % ("成功" if success else "失败"))

	var target_scene: String = str(result.get("target_scene", ""))
	if not target_scene.is_empty():
		lines.append("目标页面：%s" % _get_scene_display_name(target_scene))

	var applied_actions: Array = result.get("applied_actions", []) as Array
	if not applied_actions.is_empty():
		lines.append("已执行：")
		for action_value: Variant in applied_actions:
			lines.append("- %s" % str(action_value))

	var errors: Array = result.get("errors", []) as Array
	if not errors.is_empty():
		lines.append("错误：")
		for error_value: Variant in errors:
			lines.append("- %s" % str(error_value))

	return "\n".join(lines)


# 作用：把预设加载错误拼成可读文本。
# 参数：errors 是错误列表。
# 返回：文本结果。
func _build_error_text(errors: Array[String]) -> String:
	if errors.is_empty():
		return "调试预设加载失败。"
	var lines: Array[String] = ["调试预设加载失败："]
	for error: String in errors:
		lines.append("- %s" % error)
	return "\n".join(lines)


# 作用：返回当前调试面板底部反馈文本，供开发期自动验证读取。
# 参数：无。
# 返回：反馈文本；面板未初始化时返回空字符串。
func get_feedback_text() -> String:
	if feedback_label == null:
		return ""
	return feedback_label.text


# 作用：按“预设 id + 按钮类型”获取面板中的按钮，供开发期 UI 自动验证使用。
# 参数：preset_id 是预设 id；button_kind 支持 load / enter。
# 返回：找到时返回 Button，否则返回 null。
func get_preset_button(preset_id: String, button_kind: String) -> Button:
	var key: String = "%s:%s" % [preset_id, button_kind]
	var button: Button = preset_buttons_by_key.get(key, null) as Button
	return button


# 作用：把调试预设 id 转成面板里使用的中文预设名。
# 参数：preset_id 是预设 id。
# 返回：预设中文名；未加载到时返回原始 id。
func _get_preset_display_name(preset_id: String) -> String:
	if preset_loader == null:
		return preset_id
	var preset: Dictionary = preset_loader.get_preset_by_id(preset_id)
	if preset.is_empty():
		return preset_id
	return str(preset.get("name", preset_id))


# 作用：把调试场景别名转成中文页面名。
# 参数：scene_name 是调试预设里的目标页面别名。
# 返回：中文页面名；未知时返回原始别名。
func _get_scene_display_name(scene_name: String) -> String:
	match scene_name:
		"main_menu":
			return "主菜单"
		"shelter":
			return "避难所"
		"world_map":
			return "冰原地图"
		"result":
			return "结算页"
		_:
			return scene_name
