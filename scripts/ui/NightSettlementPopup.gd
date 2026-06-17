extends CanvasLayer

signal continued

var panel: PanelContainer
var title_label: Label
var content_box: VBoxContainer
var continue_button: Button
var ui_built: bool = false


# 作用：Godot 自动回调；配置弹窗层级并确保 UI 已创建。
# 参数：无。
# 返回：无。
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 10
	_ensure_ui_built()


# 作用：展示夜晚结算结果。
# 参数：result 是 NightSettlementManager.settle_night() 返回的结算 Dictionary。
# 返回：无。会刷新标题和内容列表。
func show_result(result: Dictionary) -> void:
	_ensure_ui_built()

	var day_after: int = int(result.get("day_after", 1))
	var day_before: int = int(result.get("day_before", day_after))
	if title_label != null:
		title_label.text = "第 %d 天夜晚结算" % day_before

	if content_box == null:
		return

	_clear_content()

	var lines: Array[String] = _to_string_array(result.get("lines", []))
	if lines.is_empty():
		lines = [
			"本次夜晚结算无明细"
		]

	for line: String in lines:
		var label: Label = Label.new()
		label.text = line
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		content_box.add_child(label)

	var summary: Label = Label.new()
	summary.text = "点击继续进入第 %d 天" % day_after
	summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	summary.add_theme_font_size_override("font_size", 16)
	content_box.add_child(summary)


# 作用：动态创建夜晚结算弹窗 UI。
# 参数：无。
# 返回：无。会创建遮罩、面板、标题、内容容器和继续按钮。
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
	panel.offset_left = -340
	panel.offset_top = -220
	panel.offset_right = 340
	panel.offset_bottom = 220
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
	title_label.text = "夜晚结算"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 28)
	layout.add_child(title_label)

	content_box = VBoxContainer.new()
	content_box.add_theme_constant_override("separation", 8)
	layout.add_child(content_box)

	continue_button = Button.new()
	continue_button.text = "继续"
	continue_button.custom_minimum_size = Vector2(160, 40)
	continue_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	continue_button.pressed.connect(_on_continue_pressed)
	layout.add_child(continue_button)
	ui_built = true


# 作用：清空弹窗内容区。
# 参数：无。
# 返回：无。旧内容节点会排队释放。
func _clear_content() -> void:
	if content_box == null:
		return

	for child: Node in content_box.get_children():
		child.queue_free()


# 作用：响应“继续”按钮。
# 参数：无。
# 返回：无。会发出 continued 信号并关闭弹窗。
func _on_continue_pressed() -> void:
	print("[NightSettlementPopup] button=continue")
	continued.emit()
	queue_free()


# 作用：把 Variant 安全转换成字符串数组。
# 参数：value 是任意值，通常来自结算结果 Dictionary。
# 返回：字符串数组；value 不是数组时返回空数组。
func _to_string_array(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if typeof(value) != TYPE_ARRAY:
		return result

	var raw_items: Array = value as Array
	for item_value: Variant in raw_items:
		result.append(str(item_value))
	return result


# 作用：确保弹窗 UI 已经创建。
# 参数：无。
# 返回：无。已经创建过时不会重复创建。
func _ensure_ui_built() -> void:
	if ui_built:
		return
	_build_ui()
