extends Control

const GAME_TITLE: String = "冰汽时代"
const BATTLE_VERIFIER_SCRIPT: Script = preload("res://scripts/dev/BattleResolverVerifier.gd")
const DEBUG_TOOLS_VERIFIER_SCRIPT: Script = preload("res://scripts/dev/DebugToolsVerifier.gd")
const DEBUG_TOOLS_UI_VERIFIER_SCRIPT: Script = preload("res://scripts/dev/DebugToolsUiVerifier.gd")
const DEV_TOOLS_PANEL_SCRIPT: Script = preload("res://scripts/dev/DevToolsPanel.gd")

var dev_tools_panel = null


# 作用：Godot 自动回调；主菜单场景加载完成后构建界面。
# 参数：无。
# 返回：无。
func _ready() -> void:
	print("[MainMenu] ready")
	if _try_run_pre_ui_dev_verifier():
		return
	_build_ui()
	_try_run_post_ui_dev_verifier()


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

	if _should_show_dev_tools():
		var dev_tools_button: Button = _make_menu_button("开发调试")
		dev_tools_button.pressed.connect(_on_dev_tools_pressed)
		layout.add_child(dev_tools_button)

	var settings_button: Button = _make_menu_button("设置")
	settings_button.pressed.connect(_on_settings_pressed)
	layout.add_child(settings_button)

	var exit_button: Button = _make_menu_button("退出")
	exit_button.pressed.connect(_on_exit_pressed)
	layout.add_child(exit_button)


# 作用：在命令行带上调试参数时，直接运行需要在主菜单 UI 构建前执行的开发期验证脚本。
# 参数：无。
# 返回：命中调试参数返回 true，否则返回 false。
func _try_run_pre_ui_dev_verifier() -> bool:
	var user_args: PackedStringArray = OS.get_cmdline_user_args()
	if user_args.has("--battle-verify"):
		return _run_dev_verifier_script(BATTLE_VERIFIER_SCRIPT, "battle verifier")
	if user_args.has("--debug-preset-verify"):
		return _run_dev_verifier_script(DEBUG_TOOLS_VERIFIER_SCRIPT, "debug tools verifier")
	return false


# 作用：在主菜单 UI 构建完成后，按命令行参数挂载 UI 级开发验证脚本。
# 参数：无。
# 返回：无。
func _try_run_post_ui_dev_verifier() -> void:
	var user_args: PackedStringArray = OS.get_cmdline_user_args()
	if not user_args.has("--dev-tools-ui-verify"):
		return
	var verifier: Node = DEBUG_TOOLS_UI_VERIFIER_SCRIPT.new(self) as Node
	if verifier == null:
		push_error("[MainMenu] failed to create debug tools ui verifier")
		get_tree().quit()
		return
	get_tree().root.call_deferred("add_child", verifier)


# 作用：实例化并运行指定的开发期验证脚本。
# 参数：verifier_script 是待运行脚本；verifier_name 是日志里显示的验证器名称。
# 返回：创建并挂载成功后返回 true。
func _run_dev_verifier_script(verifier_script: Script, verifier_name: String) -> bool:
	if verifier_script == null:
		push_error("[MainMenu] missing %s script" % verifier_name)
		get_tree().quit()
		return false

	var verifier: Node = verifier_script.new() as Node
	if verifier == null:
		push_error("[MainMenu] failed to create %s" % verifier_name)
		get_tree().quit()
		return true

	add_child(verifier)
	return true


# 作用：判断当前是否应该显示开发调试入口。
# 参数：无。
# 返回：编辑器环境或命令行带 --dev-tools 时返回 true。
func _should_show_dev_tools() -> bool:
	if OS.has_feature("editor"):
		return true
	var user_args: PackedStringArray = OS.get_cmdline_user_args()
	return user_args.has("--dev-tools")


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


# 作用：响应“开发调试”按钮，打开开发测试面板。
# 参数：无。
# 返回：无。首次点击时会创建面板并挂到当前主菜单场景。
func _on_dev_tools_pressed() -> void:
	print("[MainMenu] button=dev_tools")
	_ensure_dev_tools_panel()
	if dev_tools_panel != null:
		dev_tools_panel.open_panel()


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


# 作用：确保开发调试面板已创建并挂载到当前主菜单。
# 参数：无。
# 返回：无。创建失败时会输出错误日志。
func _ensure_dev_tools_panel() -> void:
	if dev_tools_panel != null and is_instance_valid(dev_tools_panel):
		return
	dev_tools_panel = DEV_TOOLS_PANEL_SCRIPT.new()
	if dev_tools_panel == null:
		push_error("[MainMenu] failed to create dev tools panel")
		return
	add_child(dev_tools_panel)
