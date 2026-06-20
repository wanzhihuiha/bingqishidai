extends CanvasLayer

signal continued

var panel: PanelContainer
var title_label: Label
var content_box: VBoxContainer
var cost_table_box: VBoxContainer
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

	_build_cost_table(result)

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

	cost_table_box = VBoxContainer.new()
	cost_table_box.add_theme_constant_override("separation", 6)
	layout.add_child(cost_table_box)

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
	if cost_table_box != null:
		for child: Node in cost_table_box.get_children():
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


# 作用：根据结算结果创建“夜晚消耗”小表格。
# 参数：result 是 NightSettlementManager 返回的结算结果。
# 返回：无。没有 cost_summary 时不创建表格。
func _build_cost_table(result: Dictionary) -> void:
	if cost_table_box == null:
		return

	var rows_variant: Variant = result.get("cost_summary", [])
	if typeof(rows_variant) != TYPE_ARRAY:
		return
	var rows: Array = rows_variant as Array
	if rows.is_empty():
		return

	var title: Label = Label.new()
	title.text = "夜晚消耗"
	title.add_theme_font_size_override("font_size", 20)
	cost_table_box.add_child(title)

	var table_panel: PanelContainer = PanelContainer.new()
	table_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cost_table_box.add_child(table_panel)

	var table_box: VBoxContainer = VBoxContainer.new()
	table_box.add_theme_constant_override("separation", 4)
	table_panel.add_child(table_box)

	table_box.add_child(_build_table_row(["项目", "基础消耗", "实际消耗", "节省", "说明"], true, false))

	for row_value: Variant in rows:
		if typeof(row_value) != TYPE_DICTIONARY:
			continue
		var row: Dictionary = row_value as Dictionary
		table_box.add_child(_build_table_row([
			str(row.get("item", "")),
			str(row.get("base_text", "")),
			str(row.get("actual_text", "")),
			str(row.get("saved_text", "")),
			str(row.get("source_text", ""))
		], false, true))


# 作用：创建夜晚消耗表格的一整行。
# 参数：values 是 5 列文本；is_header 表示是否表头；highlight_saved 表示是否高亮节省列。
# 返回：配置好的 HBoxContainer。
func _build_table_row(values: Array[String], is_header: bool, highlight_saved: bool) -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 8)
	var safe_values: Array[String] = values.duplicate()
	while safe_values.size() < 5:
		safe_values.append("")
	row.add_child(_make_table_cell(safe_values[0], 70, HORIZONTAL_ALIGNMENT_LEFT, is_header, false, false))
	row.add_child(_make_table_cell(safe_values[1], 90, HORIZONTAL_ALIGNMENT_CENTER, is_header, false, false))
	row.add_child(_make_table_cell(safe_values[2], 90, HORIZONTAL_ALIGNMENT_CENTER, is_header, false, false))
	row.add_child(_make_table_cell(safe_values[3], 55, HORIZONTAL_ALIGNMENT_CENTER, is_header, highlight_saved, false))
	row.add_child(_make_table_cell(safe_values[4], 0, HORIZONTAL_ALIGNMENT_LEFT, is_header, false, true))
	return row


# 作用：创建表格单元格。
# 参数：text 是文本；min_width 是最小宽度；alignment 是水平对齐；is_header 表示是否表头；highlight 表示是否高亮；expand 表示是否占满剩余空间。
# 返回：配置好的 Label。
func _make_table_cell(
	text: String,
	min_width: int,
	alignment: HorizontalAlignment,
	is_header: bool,
	highlight: bool,
	expand: bool
) -> Label:
	var label: Label = Label.new()
	label.text = text
	if min_width > 0:
		label.custom_minimum_size = Vector2(min_width, 0)
	if expand:
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.horizontal_alignment = alignment
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if is_header:
		label.add_theme_font_size_override("font_size", 16)
	if highlight:
		label.add_theme_color_override("font_color", Color(0.45, 0.9, 0.45, 1.0))
	return label
