extends Control

const GAME_TITLE: String = "冰汽时代"


func _ready() -> void:
	print("[MainMenu] ready")
	_build_ui()


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
	title.text = GAME_TITLE
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 42)
	layout.add_child(title)

	var start_button: Button = _make_menu_button("开始新游戏")
	start_button.pressed.connect(_on_start_new_game_pressed)
	layout.add_child(start_button)

	var continue_button: Button = _make_menu_button("继续游戏（暂无存档）")
	continue_button.disabled = true
	layout.add_child(continue_button)

	var settings_button: Button = _make_menu_button("设置")
	settings_button.pressed.connect(_on_settings_pressed)
	layout.add_child(settings_button)

	var exit_button: Button = _make_menu_button("退出")
	exit_button.pressed.connect(_on_exit_pressed)
	layout.add_child(exit_button)


func _make_menu_button(text: String) -> Button:
	var button: Button = Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(240, 44)
	return button


func _on_start_new_game_pressed() -> void:
	print("[MainMenu] button=start_new_game")
	GameState.start_new_game()
	SceneRouter.go_to_shelter()


func _on_settings_pressed() -> void:
	print("[MainMenu] button=settings placeholder")


func _on_exit_pressed() -> void:
	print("[MainMenu] button=exit")
	get_tree().quit()
