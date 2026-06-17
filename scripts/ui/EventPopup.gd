extends CanvasLayer

signal event_finished

var panel: PanelContainer
var title_label: Label
var body_label: Label
var choices_box: VBoxContainer
var result_label: Label
var close_button: Button
var current_event: Dictionary = {}
var is_resolved: bool = false
var ui_built: bool = false


# 作用：Godot 自动回调；配置事件弹窗层级并确保 UI 已创建。
# 参数：无。
# 返回：无。
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 11
	_ensure_ui_built()


# 作用：显示指定事件，并刷新标题、正文和选项按钮。
# 参数：event_config 是事件配置 Dictionary。
# 返回：无。会复制事件配置到 current_event，避免 UI 直接改配置缓存。
func show_event(event_config: Dictionary) -> void:
	_ensure_ui_built()
	current_event = event_config.duplicate(true)
	is_resolved = false

	if title_label != null:
		title_label.text = str(event_config.get("title", "事件"))
	if body_label != null:
		body_label.text = str(event_config.get("body", "营地出现了新的情况。"))
	if result_label != null:
		result_label.text = ""
		result_label.visible = false
	if close_button != null:
		close_button.visible = false

	_refresh_choice_buttons()


# 作用：动态创建事件弹窗 UI。
# 参数：无。
# 返回：无。会创建遮罩、面板、正文、选项容器、结果文本和关闭按钮。
func _build_ui() -> void:
	var dim: ColorRect = ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.0, 0.0, 0.0, 0.55)
	add_child(dim)

	panel = PanelContainer.new()
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -360
	panel.offset_top = -250
	panel.offset_right = 360
	panel.offset_bottom = 250
	add_child(panel)

	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_bottom", 20)
	panel.add_child(margin)

	var layout: VBoxContainer = VBoxContainer.new()
	layout.add_theme_constant_override("separation", 14)
	margin.add_child(layout)

	title_label = Label.new()
	title_label.text = "事件"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 28)
	layout.add_child(title_label)

	body_label = Label.new()
	body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	layout.add_child(body_label)

	choices_box = VBoxContainer.new()
	choices_box.add_theme_constant_override("separation", 10)
	layout.add_child(choices_box)

	result_label = Label.new()
	result_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	result_label.visible = false
	layout.add_child(result_label)

	close_button = Button.new()
	close_button.text = "关闭"
	close_button.custom_minimum_size = Vector2(150, 40)
	close_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close_button.visible = false
	close_button.pressed.connect(_on_close_pressed)
	layout.add_child(close_button)

	ui_built = true


# 作用：根据 current_event 重新生成选项按钮。
# 参数：无。
# 返回：无。旧选项节点会被释放。
func _refresh_choice_buttons() -> void:
	if choices_box == null:
		return

	for child: Node in choices_box.get_children():
		child.queue_free()

	var choices: Array = current_event.get("choices", []) as Array
	for choice_value: Variant in choices:
		if typeof(choice_value) != TYPE_DICTIONARY:
			continue
		var choice: Dictionary = choice_value as Dictionary
		choices_box.add_child(_make_choice_row(choice))


# 作用：创建单个事件选项行。
# 参数：choice 是选项配置 Dictionary。
# 返回：包含按钮和影响预览的 PanelContainer。
func _make_choice_row(choice: Dictionary) -> PanelContainer:
	var panel_container: PanelContainer = PanelContainer.new()
	panel_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 5)
	panel_container.add_child(box)

	var button: Button = Button.new()
	button.text = str(choice.get("label", "选择"))
	button.custom_minimum_size = Vector2(0, 38)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(button)

	var preview: Label = Label.new()
	preview.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(preview)

	var availability: Dictionary = EventManager.get_choice_availability(choice)
	var is_available: bool = bool(availability.get("available", false))
	var effect_text: String = EventManager.get_choice_effect_preview(choice)
	if is_available:
		preview.text = "影响：%s" % effect_text
		button.pressed.connect(_on_choice_pressed.bind(str(choice.get("id", ""))))
	else:
		button.disabled = true
		preview.text = "条件不足：%s；影响：%s" % [
			str(availability.get("reason", "条件不足")),
			effect_text
		]

	return panel_container


# 作用：响应事件选项点击。
# 参数：choice_id 是被点击的选项 id。
# 返回：无。成功处理后会隐藏选项并显示关闭按钮。
func _on_choice_pressed(choice_id: String) -> void:
	if is_resolved:
		return

	var event_id: String = str(current_event.get("id", ""))
	var result: Dictionary = EventManager.resolve_choice(event_id, choice_id)
	var success: bool = bool(result.get("success", false))
	var lines: Array[String] = _to_string_array(result.get("effect_lines", []))
	var message: String = str(result.get("message", "事件已处理。"))
	if not lines.is_empty():
		message += "\n影响：%s" % _join_string_array(lines, "无直接数值变化")
	if result_label != null:
		result_label.text = message
		result_label.visible = true

	if success:
		is_resolved = true
		if choices_box != null:
			choices_box.visible = false
		if close_button != null:
			close_button.visible = true


# 作用：响应事件弹窗关闭按钮。
# 参数：无。
# 返回：无。会发出 event_finished 信号并关闭弹窗。
func _on_close_pressed() -> void:
	print("[EventPopup] button=close")
	event_finished.emit()
	queue_free()


# 作用：确保事件弹窗 UI 已经创建。
# 参数：无。
# 返回：无。已经创建过时不会重复创建。
func _ensure_ui_built() -> void:
	if ui_built:
		return
	_build_ui()


# 作用：把 Variant 安全转换成字符串数组。
# 参数：value 是任意值，通常来自事件结果 Dictionary。
# 返回：字符串数组；value 不是数组时返回空数组。
func _to_string_array(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if typeof(value) != TYPE_ARRAY:
		return result

	var raw_items: Array = value as Array
	for item_value: Variant in raw_items:
		result.append(str(item_value))
	return result


# 作用：拼接字符串数组。
# 参数：items 是字符串数组；empty_text 是数组为空时显示的文本。
# 返回：用中文逗号连接后的字符串。
func _join_string_array(items: Array[String], empty_text: String) -> String:
	if items.is_empty():
		return empty_text
	var parts: PackedStringArray = PackedStringArray()
	for item: String in items:
		parts.append(item)
	return "，".join(parts)
