extends RefCounted

var preset_loader = null


# 作用：创建调试执行器，可复用已有加载器，避免重复读取同一份 JSON。
# 参数：loader 是可选的预设加载器实例。
# 返回：无。
func _init(loader = null) -> void:
	if loader != null:
		preset_loader = loader
	else:
		preset_loader = load("res://scripts/dev/DebugPresetLoader.gd").new()


# 作用：执行指定调试预设，并按需要跳转到目标页面。
# 参数：preset_id 是预设 id；open_target_scene 表示是否在成功后切场景。
# 返回：统一结果 Dictionary，包含 success、errors、applied_actions 和 target_scene。
func run_preset(preset_id: String, open_target_scene: bool = false) -> Dictionary:
	var result: Dictionary = {
		"success": false,
		"preset_id": preset_id,
		"applied_actions": [],
		"errors": [],
		"target_scene": ""
	}

	if preset_loader == null:
		result["errors"] = ["调试预设加载器未初始化。"]
		return result

	var loader_ok: bool = bool(preset_loader.reload())
	if not loader_ok:
		result["errors"] = preset_loader.get_last_errors()
		return result

	var preset: Dictionary = preset_loader.get_preset_by_id(preset_id)
	if preset.is_empty():
		result["errors"] = ["未找到对应的调试预设。"]
		return result

	var actions: Array = preset.get("actions", []) as Array
	var source: String = "debug_preset:%s" % preset_id
	var resolved_target_scene: String = str(preset.get("target_scene", ""))

	if actions.is_empty():
		result["errors"] = ["这个调试预设没有配置任何动作。"]
		return result

	if str((actions[0] as Dictionary).get("action_type", "")) != "start_new_game":
		GameState.ensure_started()

	var applied_actions: Array[String] = []
	var errors: Array[String] = []
	for action_value: Variant in actions:
		var action: Dictionary = action_value as Dictionary
		var action_result: Dictionary = _apply_action(action, source)
		var action_success: bool = bool(action_result.get("success", false))
		var summary: String = str(action_result.get("summary", ""))
		if not summary.is_empty():
			applied_actions.append(summary)
		if not action_success:
			errors.append(str(action_result.get("error", "未知调试动作错误")))
			break
		var action_scene: String = str(action_result.get("target_scene", ""))
		if not action_scene.is_empty():
			resolved_target_scene = action_scene

	result["applied_actions"] = applied_actions
	result["errors"] = errors
	result["target_scene"] = resolved_target_scene
	if not errors.is_empty():
		return result

	GameState.refresh_temperature_score(source)
	GameState.refresh_shelter_status(source)
	result["success"] = true

	if open_target_scene and not resolved_target_scene.is_empty():
		_go_to_scene(resolved_target_scene)

	return result


# 作用：执行单个调试动作，并返回统一的动作结果。
# 参数：action 是动作 Dictionary；source 是日志来源。
# 返回：包含 success、summary、error 和 target_scene 的 Dictionary。
func _apply_action(action: Dictionary, source: String) -> Dictionary:
	var action_type: String = str(action.get("action_type", ""))
	var target_id: String = str(action.get("target_id", ""))
	var value: Variant = action.get("value", null)

	match action_type:
		"start_new_game":
			GameState.start_new_game()
			return {"success": true, "summary": "重置为新游戏", "error": "", "target_scene": ""}
		"set_day":
			GameState.set_day(int(value), source)
			return {"success": true, "summary": "设置天数为 %d" % int(value), "error": "", "target_scene": ""}
		"grant_resources":
			var resource_values: Dictionary = value as Dictionary
			for resource_id_value: Variant in resource_values.keys():
				var resource_id: String = str(resource_id_value)
				var amount: int = int(resource_values.get(resource_id, 0))
				GameState.add_resource(resource_id, amount, source)
			return {"success": true, "summary": "发放资源", "error": "", "target_scene": ""}
		"ensure_building_level":
			GameState.set_building_level(target_id, int(value), source)
			return {
				"success": true,
				"summary": "设置建筑 %s 到 %d 级" % [_get_building_name(target_id), int(value)],
				"error": "",
				"target_scene": ""
			}
		"unlock_all_heroes":
			for hero_id: String in DataLoader.get_hero_order():
				GameState.set_hero_unlocked(hero_id, true, source)
			return {"success": true, "summary": "解锁全部英雄", "error": "", "target_scene": ""}
		"grant_equipment":
			var equipment_values: Dictionary = value as Dictionary
			for equipment_id_value: Variant in equipment_values.keys():
				var equipment_id: String = str(equipment_id_value)
				var amount: int = int(equipment_values.get(equipment_id, 0))
				GameState.add_equipment_inventory(equipment_id, amount, source)
			return {"success": true, "summary": "发放测试装备", "error": "", "target_scene": ""}
		"clear_all_squads":
			GameState.clear_all_squads(source)
			return {"success": true, "summary": "清空全部编队", "error": "", "target_scene": ""}
		"assign_heroes_to_squad":
			var hero_values: Array = value as Array
			GameState.clear_squad_heroes(target_id, source)
			for hero_value: Variant in hero_values:
				var hero_id: String = str(hero_value)
				var assigned: bool = GameState.assign_hero_to_squad(hero_id, target_id, source)
				if not assigned:
					return {
						"success": false,
						"summary": "编队失败",
						"error": "英雄无法加入小队：%s -> %s" % [_get_hero_name(hero_id), _get_squad_name(target_id)],
						"target_scene": ""
					}
			return {
				"success": true,
				"summary": "构造测试编队 %s" % _get_squad_name(target_id),
				"error": "",
				"target_scene": ""
			}
		"set_region_state":
			var region_values: Dictionary = value as Dictionary
			if region_values.has("owner"):
				GameState.set_region_owner(target_id, str(region_values.get("owner", "neutral")), source)
			if region_values.has("danger_level"):
				GameState.set_region_danger_level(target_id, int(region_values.get("danger_level", 0)), source)
			if region_values.has("is_scouted"):
				GameState.set_region_scouted(target_id, bool(region_values.get("is_scouted", false)), source)
			return {
				"success": true,
				"summary": "设置区域状态 %s" % _get_region_name(target_id),
				"error": "",
				"target_scene": ""
			}
		"set_weather_pressure":
			GameState.set_weather_pressure(float(value), source)
			return {"success": true, "summary": "设置天气压力 %.1f" % float(value), "error": "", "target_scene": ""}
		"set_beacon_state":
			var beacon_values: Dictionary = value as Dictionary
			for key_value: Variant in beacon_values.keys():
				var key: String = str(key_value)
				GameState.set_beacon_value(key, beacon_values.get(key, null), source)
			return {"success": true, "summary": "设置边境信标状态", "error": "", "target_scene": ""}
		"go_to_scene":
			return {
				"success": true,
				"summary": "设置目标页面 %s" % _get_scene_display_name(str(value)),
				"error": "",
				"target_scene": str(value)
			}
		_:
			return {
				"success": false,
				"summary": "",
				"error": "未识别的调试动作：%s" % action_type,
				"target_scene": ""
			}


# 作用：按场景别名切换到正式页面。
# 参数：scene_name 是文档里约定的目标场景名。
# 返回：无。找不到别名时只打印错误，不抛异常。
func _go_to_scene(scene_name: String) -> void:
	match scene_name:
		"main_menu":
			SceneRouter.go_to_main_menu()
		"shelter":
			SceneRouter.go_to_shelter()
		"world_map":
			SceneRouter.go_to_world_map()
		"result":
			SceneRouter.go_to_result()
		_:
			push_error("[DebugScenarioRunner] unknown scene=%s" % scene_name)


# 作用：把建筑 id 转成中文建筑名。
# 参数：building_id 是建筑 id。
# 返回：建筑中文名；缺失时返回原始 id。
func _get_building_name(building_id: String) -> String:
	var config: Dictionary = DataLoader.get_building_config(building_id)
	return str(config.get("name", building_id))


# 作用：把英雄 id 转成中文英雄名。
# 参数：hero_id 是英雄 id。
# 返回：英雄中文名；缺失时返回原始 id。
func _get_hero_name(hero_id: String) -> String:
	var config: Dictionary = DataLoader.get_hero_config(hero_id)
	return str(config.get("name", hero_id))


# 作用：把小队 id 转成中文小队名。
# 参数：squad_id 是小队 id。
# 返回：小队中文名；缺失时返回原始 id。
func _get_squad_name(squad_id: String) -> String:
	return DataLoader.get_squad_name(squad_id)


# 作用：把区域 id 转成中文区域名。
# 参数：region_id 是区域 id。
# 返回：区域中文名；缺失时返回原始 id。
func _get_region_name(region_id: String) -> String:
	return DataLoader.get_region_name(region_id)


# 作用：把调试场景别名转成玩家可读的中文页面名。
# 参数：scene_name 是调试预设里的目标页面别名。
# 返回：中文页面名；未知时返回原始别名。
func _get_scene_display_name(scene_name: String) -> String:
	match scene_name:
		"main_menu":
			return "主菜单"
		"shelter":
			return "避难所"
		"world_map":
			return "冰原地图"
		"result":
			return "结算页"
		_:
			return scene_name
