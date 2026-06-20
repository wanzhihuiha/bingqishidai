extends CanvasLayer

signal closed

var panel: PanelContainer
var title_label: Label
var list_box: VBoxContainer
var close_button: Button
var current_index: int = 0
var reports: Array[Dictionary] = []
var ui_built: bool = false


# 作用：Godot 自动回调；确保战报面板 UI 已创建。
# 参数：无。
# 返回：无。
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 11
	_ensure_ui_built()


# 作用：显示一组自动战斗战报，支持逐条查看。
# 参数：battle_results 是探险结算结果数组。
# 返回：无。
func show_reports(battle_results: Array[Dictionary]) -> void:
	_ensure_ui_built()
	reports = battle_results.duplicate(true)
	current_index = 0
	_refresh_view()


# 作用：动态创建战报面板 UI。
# 参数：无。
# 返回：无。
func _build_ui() -> void:
	var dim: ColorRect = ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.0, 0.0, 0.0, 0.65)
	add_child(dim)

	panel = PanelContainer.new()
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -360
	panel.offset_top = -260
	panel.offset_right = 360
	panel.offset_bottom = 260
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
	title_label.text = "自动战斗战报"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 28)
	layout.add_child(title_label)

	list_box = VBoxContainer.new()
	list_box.add_theme_constant_override("separation", 8)
	layout.add_child(list_box)

	close_button = Button.new()
	close_button.text = "关闭"
	close_button.custom_minimum_size = Vector2(160, 40)
	close_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close_button.pressed.connect(_on_close_pressed)
	layout.add_child(close_button)
	ui_built = true


# 作用：刷新当前战报内容。
# 参数：无。
# 返回：无。
func _refresh_view() -> void:
	if title_label == null or list_box == null:
		return

	_clear_list_box()
	if reports.is_empty():
		title_label.text = "自动战斗战报"
		var empty_label: Label = Label.new()
		empty_label.text = "本次没有需要展示的自动战斗结果。"
		empty_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		list_box.add_child(empty_label)
		return

	current_index = clamp(current_index, 0, reports.size() - 1)
	var result: Dictionary = reports[current_index] as Dictionary
	var expedition_id: String = str(result.get("expedition_id", ""))
	var expedition_title: String = expedition_id
	if not expedition_id.is_empty():
		expedition_title = str(DataLoader.get_expedition_config(expedition_id).get("title", expedition_id))
	title_label.text = "自动战斗战报 %d/%d：%s" % [current_index + 1, reports.size(), expedition_title]

	var lines: Array[String] = _to_string_array(result.get("report_lines", []))
	for line: String in lines:
		var label: Label = Label.new()
		label.text = line
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		list_box.add_child(label)

	if reports.size() > 1:
		list_box.add_child(_build_pager_row())


# 作用：创建上一条/下一条切换行。
# 参数：无。
# 返回：分页按钮行。
func _build_pager_row() -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)

	var prev_button: Button = Button.new()
	prev_button.text = "上一条"
	prev_button.disabled = current_index <= 0
	prev_button.pressed.connect(_on_prev_pressed)
	row.add_child(prev_button)

	var next_button: Button = Button.new()
	next_button.text = "下一条"
	next_button.disabled = current_index >= reports.size() - 1
	next_button.pressed.connect(_on_next_pressed)
	row.add_child(next_button)

	return row


# 作用：清空战报正文区。
# 参数：无。
# 返回：无。
func _clear_list_box() -> void:
	if list_box == null:
		return
	for child: Node in list_box.get_children():
		child.queue_free()


# 作用：切换到上一条战报。
# 参数：无。
# 返回：无。
func _on_prev_pressed() -> void:
	current_index = max(current_index - 1, 0)
	_refresh_view()


# 作用：切换到下一条战报。
# 参数：无。
# 返回：无。
func _on_next_pressed() -> void:
	current_index = min(current_index + 1, reports.size() - 1)
	_refresh_view()


# 作用：关闭战报面板并通知外层继续流程。
# 参数：无。
# 返回：无。
func _on_close_pressed() -> void:
	closed.emit()
	queue_free()


# 作用：确保 UI 已初始化。
# 参数：无。
# 返回：无。
func _ensure_ui_built() -> void:
	if ui_built:
		return
	_build_ui()


# 作用：把 Variant 安全转成字符串数组。
# 参数：value 是任意值。
# 返回：字符串数组。
func _to_string_array(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if typeof(value) != TYPE_ARRAY:
		return result
	var raw_items: Array = value as Array
	for item_value: Variant in raw_items:
		result.append(str(item_value))
	return result
