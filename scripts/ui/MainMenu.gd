extends Control

const GAME_TITLE: String = "冰汽时代"
const BATTLE_VERIFIER_SCRIPT: Script = preload("res://scripts/dev/BattleResolverVerifier.gd")


# 作用：Godot 自动回调；主菜单场景加载完成后构建界面。
# 参数：无。
# 返回：无。
func _ready() -> void:
	print("[MainMenu] ready")
	if _try_run_dev_verifier():
		return
	_build_ui()


# 作用：动态创建主菜单界面，包括标题、开始、继续、设置和退出按钮。
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


# 作用：在命令行带上调试参数时，直接运行自动战斗验证脚本。
# 参数：无。
# 返回：命中调试参数返回 true，否则返回 false。
func _try_run_dev_verifier() -> bool:
	var user_args: PackedStringArray = OS.get_cmdline_user_args()
	if not user_args.has("--battle-verify"):
		return false

	var verifier: Node = BATTLE_VERIFIER_SCRIPT.new() as Node
	if verifier == null:
		push_error("[MainMenu] failed to create battle verifier")
		get_tree().quit()
		return true

	add_child(verifier)
	return true


# 作用：创建统一尺寸的主菜单按钮。
# 参数：text 是按钮显示文案。
# 返回：配置好文本和最小尺寸的 Button。
func _make_menu_button(text: String) -> Button:
	var button: Button = Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(240, 44)
	return button


# 作用：响应“开始新游戏”按钮。
# 参数：无。
# 返回：无。会重置游戏状态并进入避难所界面。
func _on_start_new_game_pressed() -> void:
	print("[MainMenu] button=start_new_game")
	GameState.start_new_game()
	SceneRouter.go_to_shelter()


# 作用：响应“设置”按钮。
# 参数：无。
# 返回：无。当前只是占位日志，后续可接入设置界面。
func _on_settings_pressed() -> void:
	print("[MainMenu] button=settings placeholder")


# 作用：响应“退出”按钮。
# 参数：无。
# 返回：无。会请求 Godot 关闭游戏窗口。
func _on_exit_pressed() -> void:
	print("[MainMenu] button=exit")
	get_tree().quit()
