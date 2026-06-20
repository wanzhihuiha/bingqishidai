extends Node


# 作用：返回当前可用于展示或派遣的探险模板列表。
# 参数：无。
# 返回：按 DataLoader 顺序排列的探险配置数组。
func get_expedition_list() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for expedition_id: String in DataLoader.get_expedition_order():
		var config: Dictionary = DataLoader.get_expedition_config(expedition_id)
		if config.is_empty():
			continue
		result.append(config)
	return result


# 作用：计算指定小队对某个探险的成功率预览。
# 参数：squad_id 是小队 id；expedition_id 是探险模板 id。
# 返回：0 到 1 之间的成功率。
func get_success_rate_preview(squad_id: String, expedition_id: String) -> float:
	var preview: Dictionary = BattleResolver.preview_expedition(squad_id, expedition_id)
	return float(preview.get("success_rate", 0.0))


# 作用：获取指定探险的奖励预览文本。
# 参数：expedition_id 是探险模板 id。
# 返回：中文奖励概述。
func get_reward_preview_text(expedition_id: String) -> String:
	var config: Dictionary = DataLoader.get_expedition_config(expedition_id)
	var rewards: Array = config.get("rewards", []) as Array
	if rewards.is_empty():
		return "无明确奖励"
	var parts: Array[String] = []
	for reward_value: Variant in rewards:
		if typeof(reward_value) != TYPE_DICTIONARY:
			continue
		var reward: Dictionary = reward_value as Dictionary
		var effect_type: String = str(reward.get("effect_type", ""))
		var target_id: String = str(reward.get("target_id", ""))
		match effect_type:
			"resource_delta":
				parts.append("%s +%d" % [
					GameState.get_resource_name(target_id),
					int(reward.get("value", 0))
				])
			"state_change":
				if target_id == "region.is_scouted":
					parts.append("解锁区域详情")
				elif target_id == "region_owner":
					parts.append("夺回区域控制")
				else:
					parts.append("状态变化")
			"beacon_delta":
				if target_id == "intel_count":
					parts.append("获得情报")
				else:
					parts.append("推进信标修复")
			_:
				parts.append("特殊效果")
	return "、".join(parts)


# 作用：获取指定探险的风险提示文本。
# 参数：expedition_id 是探险模板 id。
# 返回：中文风险概述。
func get_risk_preview_text(expedition_id: String) -> String:
	var config: Dictionary = DataLoader.get_expedition_config(expedition_id)
	var target_region_id: String = str(config.get("target_region_id", ""))
	var region_danger: int = GameState.get_region_danger_level(target_region_id)
	var region_owner: String = GameState.get_region_owner(target_region_id)
	if str(config.get("type", "")) == "scout" and region_danger <= 1 and region_owner != "enemy" and region_owner != "contested":
		return "低危险侦察，不触发战斗"
	if region_danger >= 4:
		return "高危险区域，战斗和受伤风险较高"
	if region_danger >= 2:
		return "有一定战斗风险"
	return "风险较低"


# 作用：派遣小队执行探险。
# 参数：squad_id 是小队 id；expedition_id 是探险模板 id。
# 返回：成功返回 true。
func dispatch_expedition(squad_id: String, expedition_id: String) -> bool:
	return GameState.dispatch_expedition(squad_id, expedition_id, "expedition_manager_dispatch")


# 作用：结算当前所有已派遣探险。
# 参数：无。
# 返回：包含结算条目的结果数组。
func resolve_end_of_day_expeditions() -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	for expedition_id: String in DataLoader.get_expedition_order():
		var state: Dictionary = GameState.get_expedition_state(expedition_id)
		if state.is_empty():
			continue
		if str(state.get("status", "")) != "assigned":
			continue
		if bool(state.get("resolved", false)):
			continue

		var squad_id: String = str(state.get("squad_id", ""))
		var result: Dictionary = BattleResolver.resolve_expedition(squad_id, expedition_id)
		_apply_expedition_result(expedition_id, result)
		GameState.record_expedition_result(expedition_id, result, "expedition_end_of_day")
		results.append(result)
	return results


# 作用：把探险结果写回资源、幸存者、希望值和区域状态。
# 参数：expedition_id 是探险模板 id；result 是 BattleResolver 的结果。
# 返回：无。
func _apply_expedition_result(expedition_id: String, result: Dictionary) -> void:
	var config: Dictionary = DataLoader.get_expedition_config(expedition_id)
	var rewards: Array = config.get("rewards", []) as Array
	var final_resource_reward: Dictionary = result.get("resource_reward", {}) as Dictionary
	var wounds: int = int(result.get("wounds", 0))
	var hope_delta: int = int(result.get("hope_delta", 0))
	if hope_delta != 0:
		GameState.add_resource("hope", hope_delta, "expedition_result")

	for resource_id_value: Variant in final_resource_reward.keys():
		var resource_id: String = str(resource_id_value)
		var amount: int = int(final_resource_reward.get(resource_id, 0))
		if amount != 0:
			GameState.add_resource(resource_id, amount, "expedition_result")

	var victory: bool = bool(result.get("victory", false))
	if victory:
		for reward_value: Variant in rewards:
			if typeof(reward_value) != TYPE_DICTIONARY:
				continue
			var reward: Dictionary = reward_value as Dictionary
			var effect_type: String = str(reward.get("effect_type", ""))
			var target_id: String = str(reward.get("target_id", ""))
			var base_value: Variant = reward.get("value", 0)
			match effect_type:
				"resource_delta":
					pass
				"state_change":
					if target_id == "region_owner":
						var region_id: String = str(config.get("target_region_id", ""))
						GameState.set_region_owner(region_id, "player", "expedition_result")
					elif target_id == "region.is_scouted":
						var region_id_2: String = str(config.get("target_region_id", ""))
						GameState.scout_region(region_id_2, "expedition_result")
				"beacon_delta":
					if target_id == "intel_count":
						GameState.set_beacon_value("intel_count", int(GameState.get_beacon_state().get("intel_count", 0)) + int(base_value), "expedition_result")
					elif target_id == "repair_progress":
						GameState.set_beacon_value("repair_progress", int(GameState.get_beacon_state().get("repair_progress", 0)) + int(base_value), "expedition_result")
				_:
					push_error("[ExpeditionManager] unsupported reward effect_type=%s expedition=%s" % [effect_type, expedition_id])

	_apply_expedition_wounds(expedition_id, wounds)


# 作用：根据受伤人数给本次探险的小队成员追加轻伤状态。
# 参数：expedition_id 是探险模板 id；wounds 是本次受伤人数。
# 返回：无。
func _apply_expedition_wounds(expedition_id: String, wounds: int) -> void:
	if wounds <= 0:
		return
	var state: Dictionary = GameState.get_expedition_state(expedition_id)
	var squad_id: String = str(state.get("squad_id", ""))
	var hero_ids: Array[String] = GameState.get_squad_hero_ids(squad_id)
	var applied_count: int = 0
	for hero_id: String in hero_ids:
		if applied_count >= wounds:
			break
		if GameState.get_hero_injury_state(hero_id) == "healthy":
			GameState.set_hero_injury_state(hero_id, "light_wound", "expedition_injury")
			applied_count += 1
