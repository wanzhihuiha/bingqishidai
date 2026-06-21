extends Node


# 作用：以最小自动化脚本验证自动战斗结算的关键检查点。
# 参数：无。
# 返回：无。会把验证结果打印到控制台，供 Codex 和学员对照查看。
func _ready() -> void:
	call_deferred("_run")


# 作用：等待 Autoload 初始化后，依次构造验证场景并输出结论。
# 参数：无。
# 返回：无。
func _run() -> void:
	await get_tree().process_frame
	GameState.start_new_game()
	_prepare_training_ground()
	_unlock_all_heroes()
	_prepare_squads()

	print("")
	print("=== Battle Verification Start ===")
	_verify_low_danger_scout()
	_verify_high_danger_with_weather()
	_verify_guard_team_vs_pioneer_team()
	_verify_report_fields()
	_verify_hero_exp_output()
	_verify_hero_growth_and_equipment()
	print("=== Battle Verification End ===")
	print("")
	get_tree().quit()


# 作用：确保训练场达到 1 级，避免战力缺少训练场入口加成。
# 参数：无。
# 返回：无。
func _prepare_training_ground() -> void:
	GameState.daily_flags["building_upgraded"] = false
	GameState.add_resource("wood", 200, "battle_verifier_prepare")
	GameState.add_resource("parts", 200, "battle_verifier_prepare")
	GameState.unlock_building("training_ground", "battle_verifier_prepare")
	var build_result: Dictionary = BuildingManager.build_building("training_ground")
	print("[Verifier] training_ground result=%s" % str(build_result))


# 作用：把 4 名英雄全部设置为已加入可派遣，便于快速构造队伍。
# 参数：无。
# 返回：无。
func _unlock_all_heroes() -> void:
	for hero_id: String in DataLoader.get_hero_order():
		var hero_state: Dictionary = GameState.get_hero_state(hero_id)
		hero_state["is_unlocked"] = true
		hero_state["is_available"] = true
		hero_state["assigned_squad_id"] = ""
		hero_state["injury_state"] = "healthy"
		hero_state["level"] = 1
		hero_state["exp"] = 0
		hero_state["equipped_item_id"] = ""
		GameState.heroes[hero_id] = hero_state


# 作用：构造 3 支固定验证队伍，分别覆盖开拓、护卫和搜救能力。
# 参数：无。
# 返回：无。
func _prepare_squads() -> void:
	GameState.clear_squad_heroes("pioneer_team", "battle_verifier_prepare")
	GameState.clear_squad_heroes("guard_team", "battle_verifier_prepare")
	GameState.clear_squad_heroes("rescue_team", "battle_verifier_prepare")
	GameState.assign_hero_to_squad("lin_che", "pioneer_team", "battle_verifier_prepare")
	GameState.assign_hero_to_squad("a_lan", "guard_team", "battle_verifier_prepare")
	GameState.assign_hero_to_squad("shen_zhixue", "rescue_team", "battle_verifier_prepare")


# 作用：验证低危险侦察是否跳过战斗并容易成功。
# 参数：无。
# 返回：无。
func _verify_low_danger_scout() -> void:
	GameState.weather_pressure = 0.0
	GameState.set_region_danger_level("a1_broken_pines", 1, "battle_verifier")
	GameState.set_region_owner("a1_broken_pines", "neutral", "battle_verifier")
	var result: Dictionary = BattleResolver.resolve_expedition("pioneer_team", "scout_broken_pines")
	print("[Check1] low_danger_scout victory=%s skipped_battle=%s wounds=%d report=%s" % [
		str(bool(result.get("victory", false))),
		str(bool(result.get("skipped_battle", false))),
		int(result.get("wounds", 0)),
		_join_lines(result.get("report_lines", []))
	])


# 作用：验证高危险区域叠加天气压力后，风险和伤亡是否上升。
# 参数：无。
# 返回：无。
func _verify_high_danger_with_weather() -> void:
	GameState.weather_pressure = 2.0
	GameState.set_region_danger_level("b3_cracked_mine", 5, "battle_verifier")
	GameState.set_region_owner("b3_cracked_mine", "enemy", "battle_verifier")
	var result: Dictionary = BattleResolver.resolve_expedition("guard_team", "clear_cracked_mine")
	print("[Check2] high_danger_weather battle_score=%d victory=%s wounds=%d weather=%d report=%s" % [
		int(result.get("battle_score", 0)),
		str(bool(result.get("victory", false))),
		int(result.get("wounds", 0)),
		int(result.get("weather_pressure", 0)),
		_join_lines(result.get("report_lines", []))
	])


# 作用：验证护卫队在同一高危险战斗中是否比开拓队更适合战斗。
# 参数：无。
# 返回：无。
func _verify_guard_team_vs_pioneer_team() -> void:
	GameState.weather_pressure = 1.0
	GameState.set_region_danger_level("b3_cracked_mine", 4, "battle_verifier")
	GameState.set_region_owner("b3_cracked_mine", "enemy", "battle_verifier")
	var guard_result: Dictionary = BattleResolver.resolve_expedition("guard_team", "clear_cracked_mine")
	var pioneer_result: Dictionary = BattleResolver.resolve_battle({
		"squad_id": "pioneer_team",
		"squad_name": "开拓队",
		"expedition_type": "clear",
		"expedition_title": "开拓队强行清剿对照",
		"region_id": "b3_cracked_mine",
		"region_name": "裂冰矿井",
		"region_owner": "enemy",
		"squad_power": 7,
		"squad_safety": 2,
		"hero_bonus": 1,
		"region_danger": 4,
		"weather_pressure": 1,
		"reward_multiplier": 1.0,
		"resource_reward": {},
		"extra_resource_rewards": {},
		"hope_delta": 0
	})
	print("[Check3] guard_vs_pioneer guard_score=%d guard_wounds=%d pioneer_score=%d pioneer_wounds=%d" % [
		int(guard_result.get("battle_score", 0)),
		int(guard_result.get("wounds", 0)),
		int(pioneer_result.get("battle_score", 0)),
		int(pioneer_result.get("wounds", 0))
	])


# 作用：验证战报是否明确列出危险、战力、天气影响、胜负、损失和奖励。
# 参数：无。
# 返回：无。
func _verify_report_fields() -> void:
	GameState.weather_pressure = 1.0
	var result: Dictionary = BattleResolver.resolve_expedition("guard_team", "escort_scrap_yard")
	var report_lines: Array[String] = _to_string_array(result.get("report_lines", []))
	print("[Check4] report_lines_count=%d" % report_lines.size())
	for line: String in report_lines:
		print("  [Report] %s" % line)


# 作用：验证结算结果里是否包含 hero_exp 字段。
# 参数：无。
# 返回：无。
func _verify_hero_exp_output() -> void:
	GameState.weather_pressure = 0.0
	var win_result: Dictionary = BattleResolver.resolve_expedition("guard_team", "escort_scrap_yard")
	GameState.weather_pressure = 3.0
	GameState.set_region_danger_level("c4_border_beacon", 5, "battle_verifier")
	var lose_result: Dictionary = BattleResolver.resolve_battle({
		"squad_id": "pioneer_team",
		"squad_name": "开拓队",
		"expedition_type": "repair",
		"expedition_title": "高压失败经验对照",
		"region_id": "c4_border_beacon",
		"region_name": "边境信标站",
		"region_owner": "enemy",
		"squad_power": 5,
		"squad_safety": 2,
		"hero_bonus": 0,
		"region_danger": 5,
		"weather_pressure": 3,
		"reward_multiplier": 1.0,
		"resource_reward": {},
		"extra_resource_rewards": {},
		"hope_delta": -3
	})
	print("[Check5] hero_exp win=%d lose=%d" % [
		int(win_result.get("hero_exp", 0)),
		int(lose_result.get("hero_exp", 0))
	])


# 作用：验证英雄经验、升级、装备加成与掉装库存是否生效。
# 参数：无。
# 返回：无。
func _verify_hero_growth_and_equipment() -> void:
	GameState.add_equipment_inventory("hunting_crossbow", 1, "battle_verifier")
	HeroGrowthManager.equip_item("lin_che", "hunting_crossbow", "battle_verifier")
	var before_preview: Dictionary = BattleResolver.preview_expedition("pioneer_team", "escort_scrap_yard")
	var growth_results: Array[Dictionary] = HeroGrowthManager.apply_expedition_growth(["lin_che"], 10, "battle_verifier")
	var after_level: int = GameState.get_hero_level("lin_che")
	var after_exp: int = GameState.get_hero_exp("lin_che")
	GameState.add_equipment_inventory("toolkit", 1, "battle_verifier")
	HeroGrowthManager.equip_item("xu_yan", "toolkit", "battle_verifier")
	var repair_preview: Dictionary = BattleResolver.preview_expedition("guard_team", "repair_border_beacon")
	print("[Check6] growth_equipment battle_score=%d level=%d exp=%d growth=%s repair_bonus_score=%d crossbow_equipped=%s toolkit_equipped=%s inventory=%s" % [
		int(before_preview.get("battle_score", 0)),
		after_level,
		after_exp,
		str(growth_results),
		int(repair_preview.get("battle_score", 0)),
		GameState.get_hero_equipped_item_id("lin_che"),
		GameState.get_hero_equipped_item_id("xu_yan"),
		str(GameState.get_equipment_inventory())
	])


# 作用：把 Variant 安全转换成字符串数组。
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


# 作用：把战报数组压成一行，便于控制台快速查看。
# 参数：value 是战报数组。
# 返回：分号拼接后的文本。
func _join_lines(value: Variant) -> String:
	var lines: Array[String] = _to_string_array(value)
	if lines.is_empty():
		return "无"
	return " | ".join(lines)
