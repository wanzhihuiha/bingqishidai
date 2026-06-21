extends Node

var main_menu = null


# 作用：创建 UI 自动验证器并保存主菜单引用。
# 参数：menu 是当前主菜单实例。
# 返回：无。
func _init(menu = null) -> void:
	main_menu = menu


# 作用：Godot 自动回调；延后一帧执行 UI 验证，等待主菜单和调试面板完全创建。
# 参数：无。
# 返回：无。
func _ready() -> void:
	call_deferred("_run")


# 作用：自动验证主菜单中的开发调试入口、调试面板按钮和切场景链路。
# 参数：无。
# 返回：无。验证完成后自动退出。
func _run() -> void:
	await get_tree().process_frame
	print("")
	print("=== Dev Tools UI Verification Start ===")

	if main_menu == null or not is_instance_valid(main_menu):
		print("[UIVerifier] main menu is missing")
		_finish()
		return

	var dev_tools_button: Button = _find_button_by_text(main_menu, "开发调试")
	if dev_tools_button == null:
		print("[UIVerifier] missing dev tools button")
		_finish()
		return

	print("[UIVerifier] found dev tools button")
	dev_tools_button.emit_signal("pressed")
	await get_tree().process_frame

	var panel = main_menu.dev_tools_panel
	if panel == null or not is_instance_valid(panel):
		print("[UIVerifier] dev tools panel was not created")
		_finish()
		return

	print("[UIVerifier] panel visible=%s" % str(panel.visible))
	print("[UIVerifier] feedback=%s" % panel.get_feedback_text())

	var load_button: Button = panel.get_preset_button("midgame_day8_expedition_start", "load")
	if load_button == null:
		print("[UIVerifier] missing load button for preset midgame_day8_expedition_start")
		_finish()
		return
	load_button.emit_signal("pressed")
	await get_tree().process_frame
	print("[UIVerifier] after load feedback=%s" % panel.get_feedback_text())
	print("[UIVerifier] state day=%d training_ground=%d pioneer=%s" % [
		GameState.day,
		GameState.get_building_level("training_ground"),
		str(GameState.get_squad_hero_ids("pioneer_team"))
	])

	var enter_button: Button = panel.get_preset_button("battle_equipment_compare_test", "enter")
	if enter_button == null:
		print("[UIVerifier] missing enter button for preset battle_equipment_compare_test")
		_finish()
		return
	enter_button.emit_signal("pressed")
	await get_tree().process_frame
	await get_tree().process_frame
	var current_scene_name: String = ""
	if get_tree().current_scene != null:
		current_scene_name = str(get_tree().current_scene.name)
	print("[UIVerifier] current_scene=%s" % current_scene_name)
	print("[UIVerifier] world_state guard=%s region=%s weather=%.1f" % [
		str(GameState.get_squad_hero_ids("guard_team")),
		GameState.get_region_owner("b3_cracked_mine"),
		GameState.weather_pressure
	])

	print("=== Dev Tools UI Verification End ===")
	print("")
	_finish()


# 作用：在节点树中按按钮文案递归查找按钮。
# 参数：root 是起始节点；text 是目标按钮文案。
# 返回：找到时返回 Button，否则返回 null。
func _find_button_by_text(root: Node, text: String) -> Button:
	if root is Button:
		var button: Button = root as Button
		if button.text == text:
			return button
	for child: Node in root.get_children():
		var result: Button = _find_button_by_text(child, text)
		if result != null:
			return result
	return null


# 作用：结束验证并关闭当前 Godot 进程。
# 参数：无。
# 返回：无。
func _finish() -> void:
	get_tree().quit()
