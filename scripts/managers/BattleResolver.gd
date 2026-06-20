extends Node

const DEFAULT_HERO_EXP_VICTORY: int = 10
const DEFAULT_HERO_EXP_FAILURE: int = 4


# 作用：根据探险配置和当前小队状态结算一次自动战斗。
# 参数：squad_id 是小队 id；expedition_id 是探险模板 id。
# 返回：兼容旧调用和新 BattleResult 字段的 Dictionary。
func resolve_expedition(squad_id: String, expedition_id: String) -> Dictionary:
	return _build_result(squad_id, expedition_id)


# 作用：预览指定探险的成功率和战报，不写入随机结果。
# 参数：squad_id 是小队 id；expedition_id 是探险模板 id。
# 返回：用于 UI 预览的结果 Dictionary。
func preview_expedition(squad_id: String, expedition_id: String) -> Dictionary:
	return _build_result(squad_id, expedition_id, true)


# 作用：纯战斗结算入口，统一计算 battle_score、伤亡、奖励和战报。
# 参数：input 是战斗输入 Dictionary。
# 返回：BattleResult Dictionary，包含 victory、wounds、resource_reward、hero_exp、report_lines。
func resolve_battle(input: Dictionary) -> Dictionary:
	var squad_id: String = str(input.get("squad_id", ""))
	var squad_name: String = str(input.get("squad_name", squad_id))
	var expedition_type: String = str(input.get("expedition_type", ""))
	var expedition_title: String = str(input.get("expedition_title", "探险"))
	var region_id: String = str(input.get("region_id", ""))
	var region_name: String = str(input.get("region_name", region_id))
	var region_owner: String = str(input.get("region_owner", "neutral"))
	var squad_power: int = int(input.get("squad_power", 0))
	var squad_safety: int = int(input.get("squad_safety", 0))
	var hero_bonus: int = int(input.get("hero_bonus", 0))
	var region_danger: int = int(input.get("region_danger", 0))
	var weather_pressure: int = int(input.get("weather_pressure", 0))
	var reward_multiplier: float = float(input.get("reward_multiplier", 0.0))
	var hope_delta: int = int(input.get("hope_delta", 0))
	var hero_exp_victory: int = int(input.get("hero_exp_victory", DEFAULT_HERO_EXP_VICTORY))
	var hero_exp_failure: int = int(input.get("hero_exp_failure", DEFAULT_HERO_EXP_FAILURE))
	var resource_reward: Dictionary = input.get("resource_reward", {}) as Dictionary
	var extra_resource_rewards: Dictionary = input.get("extra_resource_rewards", {}) as Dictionary
	var report_prefix_lines: Array[String] = _to_string_array(input.get("report_prefix_lines", []))
	var skips_battle: bool = bool(input.get("skips_battle", false))

	if skips_battle:
		var preview_reward: Dictionary = _scale_resource_reward(resource_reward, 1.0, extra_resource_rewards)
		var skip_lines: Array[String] = []
		skip_lines.append_array(report_prefix_lines)
		skip_lines.append("任务：%s" % expedition_title)
		skip_lines.append("派出小队：%s" % squad_name)
		skip_lines.append("遇到的危险：%s，危险度 %d，天气压力 %d" % [region_name, region_danger, weather_pressure])
		skip_lines.append("本次为低危险侦察，未触发正面战斗")
		skip_lines.append("胜负：成功")
		skip_lines.append("损失：无")
		skip_lines.append("奖励：%s" % _format_resource_reward(preview_reward))
		return {
			"squad_id": squad_id,
			"expedition_type": expedition_type,
			"region_id": region_id,
			"region_owner": region_owner,
			"battle_score": 0,
			"victory": true,
			"wounds": 0,
			"resource_reward": preview_reward,
			"hero_exp": hero_exp_victory,
			"report_lines": skip_lines,
			"lines": skip_lines,
			"outcome_id": "success",
			"outcome_name": "成功",
			"hope_delta": hope_delta,
			"reward_multiplier": 1.0,
			"injury_chance": 0.0,
			"success_rate": 1.0,
			"squad_power": squad_power,
			"squad_safety": squad_safety,
			"hero_bonus": hero_bonus,
			"task_difficulty": region_danger + weather_pressure,
			"region_danger": region_danger,
			"weather_pressure": weather_pressure,
			"skipped_battle": true
		}

	var battle_score: int = squad_power + hero_bonus - region_danger - weather_pressure
	var victory: bool = battle_score >= 0
	var base_wounds: int = max(region_danger + weather_pressure - squad_safety, 0)
	var wounds: int = base_wounds
	if not victory:
		wounds = max(base_wounds, 1)

	var final_reward_multiplier: float = reward_multiplier
	if not victory:
		final_reward_multiplier = 0.0
	var final_reward: Dictionary = _scale_resource_reward(resource_reward, final_reward_multiplier, extra_resource_rewards)
	var hero_exp: int = hero_exp_victory
	var outcome_id: String = "success"
	var outcome_name: String = "成功"
	if not victory:
		outcome_id = "failure"
		outcome_name = "失败"
		hero_exp = hero_exp_failure

	var lines: Array[String] = []
	lines.append_array(report_prefix_lines)
	lines.append("任务：%s" % expedition_title)
	lines.append("派出小队：%s" % squad_name)
	lines.append("遇到的危险：%s，危险度 %d，天气压力 %d" % [region_name, region_danger, weather_pressure])
	lines.append("战斗计算：战力 %d + 英雄加成 %d - 危险 %d - 天气 %d = %d" % [
		squad_power,
		hero_bonus,
		region_danger,
		weather_pressure,
		battle_score
	])
	lines.append("胜负：%s" % outcome_name)
	lines.append("损失：%d 人受伤" % wounds)
	lines.append("奖励：%s" % _format_resource_reward(final_reward))

	return {
		"squad_id": squad_id,
		"expedition_type": expedition_type,
		"region_id": region_id,
		"region_owner": region_owner,
		"battle_score": battle_score,
		"victory": victory,
		"wounds": wounds,
		"resource_reward": final_reward,
		"hero_exp": hero_exp,
		"report_lines": lines,
		"lines": lines,
		"outcome_id": outcome_id,
		"outcome_name": outcome_name,
		"hope_delta": hope_delta,
		"reward_multiplier": final_reward_multiplier,
		"injury_chance": _convert_wounds_to_injury_chance(wounds),
		"success_rate": _estimate_success_rate(battle_score),
		"squad_power": squad_power,
		"squad_safety": squad_safety,
		"hero_bonus": hero_bonus,
		"task_difficulty": region_danger + weather_pressure,
		"region_danger": region_danger,
		"weather_pressure": weather_pressure,
		"skipped_battle": false
	}


# 作用：统一构建探险结算或预览结果。
# 参数：squad_id 是小队 id；expedition_id 是探险模板 id；is_preview 表示是否只做预览。
# 返回：结果 Dictionary。
func _build_result(squad_id: String, expedition_id: String, is_preview: bool = false) -> Dictionary:
	GameState.ensure_started()

	var squad_config: Dictionary = DataLoader.get_squad_config(squad_id)
	var expedition_config: Dictionary = DataLoader.get_expedition_config(expedition_id)
	if squad_config.is_empty() or expedition_config.is_empty():
		return {}

	var hero_ids: Array[String] = GameState.get_squad_hero_ids(squad_id)
	var action_tags: Array[String] = _collect_action_tags(expedition_config)
	var squad_power: int = _calculate_squad_power(squad_id, squad_config, hero_ids)
	var hero_bonus: int = _calculate_hero_bonus(squad_id, expedition_config, hero_ids, action_tags)
	var squad_safety: int = _calculate_squad_safety(squad_id, hero_ids)
	var target_region_id: String = str(expedition_config.get("target_region_id", ""))
	var region_config: Dictionary = DataLoader.get_region_config(target_region_id)
	var region_name: String = str(region_config.get("name", target_region_id))
	var region_danger: int = GameState.get_region_danger_level(target_region_id)
	var weather_pressure: int = _get_weather_pressure()
	var reward_multiplier: float = _get_reward_multiplier(squad_id, expedition_config)
	var extra_resource_rewards: Dictionary = _get_extra_resource_rewards(expedition_config, hero_ids)
	var resource_reward: Dictionary = _extract_base_resource_reward(expedition_config)
	var outcome_name: String = "成功"
	if squad_power + hero_bonus - region_danger - weather_pressure < 0:
		outcome_name = "失败"
	var report_prefix_lines: Array[String] = []
	if is_preview:
		report_prefix_lines.append("本次为预览结果，未实际写入资源、伤病和区域状态")

	var battle_input: Dictionary = {
		"squad_id": squad_id,
		"squad_name": str(squad_config.get("name", squad_id)),
		"expedition_type": str(expedition_config.get("type", "")),
		"expedition_title": str(expedition_config.get("title", expedition_id)),
		"region_id": target_region_id,
		"region_name": region_name,
		"region_owner": GameState.get_region_owner(target_region_id),
		"squad_power": squad_power,
		"squad_safety": squad_safety,
		"hero_bonus": hero_bonus,
		"region_danger": region_danger,
		"weather_pressure": weather_pressure,
		"reward_multiplier": reward_multiplier,
		"resource_reward": resource_reward,
		"extra_resource_rewards": extra_resource_rewards,
		"hope_delta": _get_hope_delta(outcome_name),
		"report_prefix_lines": report_prefix_lines,
		"skips_battle": _can_skip_battle(expedition_config, target_region_id)
	}
	var result: Dictionary = resolve_battle(battle_input)
	result["expedition_id"] = expedition_id
	result["base_margin"] = int(result.get("battle_score", 0))
	result["margin"] = int(result.get("battle_score", 0))
	result["success_margin_bonus"] = 0
	result["success_rate_modifier"] = 0.0
	result["random_delta"] = 0
	result["log_tone"] = "steady"
	return result


# 作用：计算小队战力，按文档保持简单可读。
# 参数：squad_id 是小队 id；squad_config 是小队静态配置；hero_ids 是当前编入英雄数组。
# 返回：整数战力。
func _calculate_squad_power(
	squad_id: String,
	squad_config: Dictionary,
	hero_ids: Array[String]
) -> int:
	var power: int = 0
	for hero_id: String in hero_ids:
		var hero_config: Dictionary = DataLoader.get_hero_config(hero_id)
		power += int(hero_config.get("base_power", 0))

	power += int(squad_config.get("power_bonus", 0))
	power += _get_training_ground_bonus()
	return power


# 作用：把结算差值换算成一个直观的成功率预览。
# 参数：margin 是 battle_score 差值。
# 返回：0 到 1 之间的浮点数。
func _estimate_success_rate(margin: int) -> float:
	var raw_rate: float = 0.5 + float(margin) * 0.08
	return clamp(raw_rate, 0.1, 0.95)


# 作用：计算训练场带来的固定战力加成。
# 参数：无。
# 返回：整数加成。
func _get_training_ground_bonus() -> int:
	return int(BuildingManager.get_level_production_value("training_ground", "battle_power_bonus", 0))


# 作用：收集探险类型、需求和日志标签，给成功率和英雄效果匹配使用。
# 参数：expedition_config 是探险静态配置。
# 返回：去重后的标签数组。
func _collect_action_tags(expedition_config: Dictionary) -> Array[String]:
	var tags: Array[String] = []
	var expedition_type: String = str(expedition_config.get("type", ""))
	if not expedition_type.is_empty():
		_append_unique_tag(tags, expedition_type)

	var required_tags: Array = expedition_config.get("required_tags", []) as Array
	for tag_value: Variant in required_tags:
		_append_unique_tag(tags, str(tag_value))

	var log_tags: Array = expedition_config.get("log_tags", []) as Array
	for tag_value: Variant in log_tags:
		_append_unique_tag(tags, str(tag_value))

	return tags


# 作用：向标签数组里追加唯一值。
# 参数：tags 是目标数组；tag 是待加入标签。
# 返回：无。
func _append_unique_tag(tags: Array[String], tag: String) -> void:
	if tag.is_empty():
		return
	if tags.has(tag):
		return
	tags.append(tag)


# 作用：按英雄专长和小队类型计算额外英雄加成。
# 参数：squad_id 是小队 id；hero_ids 是当前编入英雄数组。
# 返回：整数加成。
func _calculate_hero_bonus(
	squad_id: String,
	expedition_config: Dictionary,
	hero_ids: Array[String],
	action_tags: Array[String]
) -> int:
	var bonus: int = 0
	for hero_id: String in hero_ids:
		var hero_config: Dictionary = DataLoader.get_hero_config(hero_id)
		var tags: Array = hero_config.get("specialty_tags", []) as Array
		for tag_value: Variant in tags:
			var tag: String = str(tag_value)
			if squad_id == "pioneer_team" and tag == "scout":
				bonus += 1
			elif squad_id == "guard_team" and tag == "guard":
				bonus += 1
			elif squad_id == "rescue_team" and tag == "rescue":
				bonus += 1
		if squad_id == "rescue_team" and tags.has("medical"):
			bonus += 1
		var event_bonuses: Array = hero_config.get("event_bonus", []) as Array
		for bonus_value: Variant in event_bonuses:
			if typeof(bonus_value) != TYPE_DICTIONARY:
				continue
			var bonus_config: Dictionary = bonus_value as Dictionary
			var effect_type: String = str(bonus_config.get("effect_type", ""))
			if effect_type != "battle_power_modifier":
				continue
			var target_id: String = str(bonus_config.get("target_id", ""))
			if not _matches_event_bonus_target(target_id, squad_id, expedition_config, action_tags):
				continue
			bonus += int(bonus_config.get("value", 0))
	return bonus


# 作用：根据当前小队与任务类型，计算基础奖励倍率。
# 参数：squad_id 是小队 id；expedition_config 是探险配置。
# 返回：最终奖励倍率。
func _get_reward_multiplier(squad_id: String, expedition_config: Dictionary) -> float:
	var reward_multiplier: float = 1.0
	var expedition_type: String = str(expedition_config.get("type", ""))
	if expedition_type != "gather":
		return reward_multiplier

	var squad_config: Dictionary = DataLoader.get_squad_config(squad_id)
	var success_bonus_tags: Dictionary = squad_config.get("success_bonus_tags", {}) as Dictionary
	if success_bonus_tags.has("gather"):
		reward_multiplier += float(success_bonus_tags.get("gather", 0.0))
	elif success_bonus_tags.has("explore"):
		reward_multiplier += float(success_bonus_tags.get("explore", 0.0))
	return reward_multiplier


# 作用：运行时派生当前小队安全值，用来降低受伤人数。
# 参数：squad_id 是小队 id；hero_ids 是小队当前英雄列表。
# 返回：安全值整数。
func _calculate_squad_safety(squad_id: String, hero_ids: Array[String]) -> int:
	var safety: int = 2
	match squad_id:
		"guard_team":
			safety = 4
		"rescue_team":
			safety = 3
		"pioneer_team":
			safety = 2
		_:
			safety = 2

	for hero_id: String in hero_ids:
		var hero_config: Dictionary = DataLoader.get_hero_config(hero_id)
		var tags: Array = hero_config.get("specialty_tags", []) as Array
		if tags.has("guard"):
			safety += 1
		if tags.has("medical"):
			safety += 1
	return safety


# 作用：读取英雄资源类事件加成，转成额外奖励字典。
# 参数：expedition_config 是探险配置；hero_ids 是当前英雄。
# 返回：资源 id 到额外奖励值的字典。
func _get_extra_resource_rewards(expedition_config: Dictionary, hero_ids: Array[String]) -> Dictionary:
	var rewards: Array = expedition_config.get("rewards", []) as Array
	var reward_resource_ids: Array[String] = []
	for reward_value: Variant in rewards:
		if typeof(reward_value) != TYPE_DICTIONARY:
			continue
		var reward_config: Dictionary = reward_value as Dictionary
		if str(reward_config.get("effect_type", "")) != "resource_delta":
			continue
		_append_unique_tag(reward_resource_ids, str(reward_config.get("target_id", "")))

	var extra_rewards: Dictionary = {}
	for hero_id: String in hero_ids:
		var hero_config: Dictionary = DataLoader.get_hero_config(hero_id)
		var event_bonuses: Array = hero_config.get("event_bonus", []) as Array
		for bonus_value: Variant in event_bonuses:
			if typeof(bonus_value) != TYPE_DICTIONARY:
				continue
			var bonus_config: Dictionary = bonus_value as Dictionary
			var effect_type: String = str(bonus_config.get("effect_type", ""))
			if effect_type != "resource_delta":
				continue
			var target_id: String = str(bonus_config.get("target_id", ""))
			if not reward_resource_ids.has(target_id):
				continue
			var before_amount: int = int(extra_rewards.get(target_id, 0))
			extra_rewards[target_id] = before_amount + int(bonus_config.get("value", 0))
	return extra_rewards


# 作用：判断英雄事件配置是否命中当前探险或小队。
# 参数：target_id 是事件目标；squad_id 是小队 id；expedition_config 是探险配置；action_tags 是行动标签。
# 返回：命中返回 true。
func _matches_event_bonus_target(
	target_id: String,
	squad_id: String,
	expedition_config: Dictionary,
	action_tags: Array[String]
) -> bool:
	if target_id.is_empty():
		return false
	if target_id == "expedition":
		return true
	if target_id == squad_id:
		return true
	var expedition_type: String = str(expedition_config.get("type", ""))
	if target_id == expedition_type:
		return true
	return action_tags.has(target_id)


# 作用：获取当前天气压力。
# 参数：无。
# 返回：整数压力值，当前先直接读取 GameState.weather_pressure。
func _get_weather_pressure() -> int:
	return int(round(GameState.weather_pressure))


# 作用：从探险奖励里抽取基础资源奖励。
# 参数：expedition_config 是探险静态配置。
# 返回：资源 id 到基础奖励值的 Dictionary。
func _extract_base_resource_reward(expedition_config: Dictionary) -> Dictionary:
	var rewards: Array = expedition_config.get("rewards", []) as Array
	var result: Dictionary = {}
	for reward_value: Variant in rewards:
		if typeof(reward_value) != TYPE_DICTIONARY:
			continue
		var reward: Dictionary = reward_value as Dictionary
		if str(reward.get("effect_type", "")) != "resource_delta":
			continue
		var target_id: String = str(reward.get("target_id", ""))
		result[target_id] = int(reward.get("value", 0))
	return result


# 作用：按倍率和额外奖励生成最终资源奖励。
# 参数：resource_reward 是基础奖励；reward_multiplier 是倍率；extra_resource_rewards 是英雄额外奖励。
# 返回：最终奖励 Dictionary。
func _scale_resource_reward(resource_reward: Dictionary, reward_multiplier: float, extra_resource_rewards: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for key_value: Variant in resource_reward.keys():
		var resource_id: String = str(key_value)
		var amount: int = int(round(float(resource_reward.get(resource_id, 0)) * reward_multiplier))
		amount += int(extra_resource_rewards.get(resource_id, 0))
		if amount > 0:
			result[resource_id] = amount
	for key_value: Variant in extra_resource_rewards.keys():
		var resource_id: String = str(key_value)
		if result.has(resource_id):
			continue
		var extra_amount: int = int(extra_resource_rewards.get(resource_id, 0))
		if extra_amount > 0 and reward_multiplier > 0.0:
			result[resource_id] = extra_amount
	return result


# 作用：把奖励字典转换成战报文本。
# 参数：reward 是资源奖励字典。
# 返回：中文奖励概述。
func _format_resource_reward(reward: Dictionary) -> String:
	if reward.is_empty():
		return "无"
	var parts: Array[String] = []
	for key_value: Variant in reward.keys():
		var resource_id: String = str(key_value)
		parts.append("%s +%d" % [
			GameState.get_resource_name(resource_id),
			int(reward.get(resource_id, 0))
		])
	return "、".join(parts)


# 作用：把受伤人数转换成旧结构里的 injury_chance 预估值，兼容现有调用方。
# 参数：wounds 是本次战斗受伤人数。
# 返回：0 到 1 之间的近似概率值。
func _convert_wounds_to_injury_chance(wounds: int) -> float:
	return clamp(float(wounds) * 0.25, 0.0, 1.0)


# 作用：根据结算结果返回希望值变化，保持与当前探险结果回写接口兼容。
# 参数：outcome_name 是中文结果名。
# 返回：希望值变化。
func _get_hope_delta(outcome_name: String) -> int:
	if outcome_name == "成功":
		return 3
	return -3


# 作用：判断指定探险是否可以跳过战斗。
# 参数：expedition_config 是探险配置；region_id 是目标区域 id。
# 返回：满足低危险侦察特例时返回 true。
func _can_skip_battle(expedition_config: Dictionary, region_id: String) -> bool:
	if str(expedition_config.get("type", "")) != "scout":
		return false
	if GameState.get_region_danger_level(region_id) > 1:
		return false
	var owner: String = GameState.get_region_owner(region_id)
	return owner != "enemy" and owner != "contested"


# 作用：把任意数组安全转成字符串数组。
# 参数：value 是任意值。
# 返回：字符串数组。
func _to_string_array(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if typeof(value) != TYPE_ARRAY:
		return result
	var raw_values: Array = value as Array
	for item_value: Variant in raw_values:
		result.append(str(item_value))
	return result
