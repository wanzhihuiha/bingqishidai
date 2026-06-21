extends Node

const DEBUG_PRESET_LOADER_SCRIPT: Script = preload("res://scripts/dev/DebugPresetLoader.gd")
const DEBUG_SCENARIO_RUNNER_SCRIPT: Script = preload("res://scripts/dev/DebugScenarioRunner.gd")

var preset_loader = null
var scenario_runner = null


# 作用：Godot 自动回调；延后一帧运行调试预设验证，确保 Autoload 已准备完成。
# 参数：无。
# 返回：无。
func _ready() -> void:
	call_deferred("_run")


# 作用：依次执行全部调试预设，输出结果后自动退出。
# 参数：无。
# 返回：无。
func _run() -> void:
	await get_tree().process_frame
	preset_loader = DEBUG_PRESET_LOADER_SCRIPT.new()
	scenario_runner = DEBUG_SCENARIO_RUNNER_SCRIPT.new(preset_loader)

	print("")
	print("=== Debug Preset Verification Start ===")

	var loaded: bool = bool(preset_loader.reload())
	if not loaded:
		var load_errors: Array[String] = preset_loader.get_last_errors()
		print("[DebugVerifier] preset load failed")
		for error: String in load_errors:
			print("  [Error] %s" % error)
		print("=== Debug Preset Verification End ===")
		print("")
		get_tree().quit()
		return

	var presets: Array[Dictionary] = preset_loader.get_preset_list()
	for preset: Dictionary in presets:
		_verify_preset(preset)

	print("=== Debug Preset Verification End ===")
	print("")
	get_tree().quit()


# 作用：验证单个调试预设的执行结果和关键状态。
# 参数：preset 是调试预设。
# 返回：无。
func _verify_preset(preset: Dictionary) -> void:
	var preset_id: String = str(preset.get("id", ""))
	var target_scene: String = str(preset.get("target_scene", ""))
	var result: Dictionary = scenario_runner.run_preset(preset_id, false)
	var success: bool = bool(result.get("success", false))
	print("[Preset] id=%s success=%s target=%s actions=%d errors=%d" % [
		preset_id,
		str(success),
		target_scene,
		(result.get("applied_actions", []) as Array).size(),
		(result.get("errors", []) as Array).size()
	])

	if not success:
		var errors: Array = result.get("errors", []) as Array
		for error_value: Variant in errors:
			print("  [Error] %s" % str(error_value))
		return

	match preset_id:
		"midgame_day8_expedition_start":
			print("  [State] day=%d training_ground=%d lin_che=%s pioneer=%s a1_scouted=%s" % [
				GameState.day,
				GameState.get_building_level("training_ground"),
				str(GameState.is_hero_unlocked("lin_che")),
				str(GameState.get_squad_hero_ids("pioneer_team")),
				str(GameState.is_region_scouted("a1_broken_pines"))
			])
		"midgame_day14_hero_growth_test":
			print("  [State] day=%d heroes=%s training_ground=%d workshop=%d equipment=%s rescue=%s" % [
				GameState.day,
				_build_unlocked_hero_list(),
				GameState.get_building_level("training_ground"),
				GameState.get_building_level("workshop"),
				str(GameState.get_equipment_inventory()),
				str(GameState.get_squad_hero_ids("rescue_team"))
			])
		"battle_equipment_compare_test":
			print("  [State] day=%d guard=%s region_owner=%s danger=%d weather=%.1f" % [
				GameState.day,
				str(GameState.get_squad_hero_ids("guard_team")),
				GameState.get_region_owner("b3_cracked_mine"),
				GameState.get_region_danger_level("b3_cracked_mine"),
				GameState.weather_pressure
			])
		"beacon_repair_test":
			print("  [State] day=%d pioneer=%s beacon=%s c4_scouted=%s" % [
				GameState.day,
				str(GameState.get_squad_hero_ids("pioneer_team")),
				str(GameState.get_beacon_state()),
				str(GameState.is_region_scouted("c4_border_beacon"))
			])
		_:
			print("  [State] day=%d" % GameState.day)


# 作用：收集当前已解锁英雄列表，方便控制台检查预设状态。
# 参数：无。
# 返回：已解锁英雄 id 数组。
func _build_unlocked_hero_list() -> Array[String]:
	var result: Array[String] = []
	for hero_id: String in DataLoader.get_hero_order():
		if GameState.is_hero_unlocked(hero_id):
			result.append(hero_id)
	return result
