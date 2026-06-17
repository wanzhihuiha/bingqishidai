extends Control


# 作用：Godot 自动回调；结算场景加载完成后构建占位结算界面。
# 参数：无。
# 返回：无。
func _ready() -> void:
	print("[ResultView] ready")
	_build_ui()


# 作用：动态创建结算界面，目前包含标题和返回主菜单按钮。
# 参数：无。
# 返回：无。创建出的节点会直接添加到当前 Control 下。
func _build_ui() -> void:
	var root: MarginContainer = MarginContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("margin_left", 48)
	root.add_theme_constant_override("margin_top", 48)
	root.add_theme_constant_override("margin_right", 48)
	root.add_theme_constant_override("margin_bottom", 48)
	add_child(root)

	var layout: VBoxContainer = VBoxContainer.new()
	layout.alignment = BoxContainer.ALIGNMENT_CENTER
	layout.add_theme_constant_override("separation", 18)
	root.add_child(layout)

	var title: Label = Label.new()
	title.text = "测试结算"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 36)
	layout.add_child(title)

	var back_button: Button = Button.new()
	back_button.text = "返回主菜单"
	back_button.custom_minimum_size = Vector2(180, 42)
	back_button.pressed.connect(_on_back_to_menu_pressed)
	layout.add_child(back_button)


# 作用：响应“返回主菜单”按钮。
# 参数：无。
# 返回：无。会切换回主菜单场景。
func _on_back_to_menu_pressed() -> void:
	print("[ResultView] button=back_to_main_menu")
	SceneRouter.go_to_main_menu()
