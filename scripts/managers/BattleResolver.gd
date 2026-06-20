extends Node

const SUCCESS_RATE_PER_MARGIN: float = 0.08


# 作用：根据小队、任务和天气修正，计算探险自动战斗结果档位。
# 参数：squad_id 是小队 id；expedition_id 是探险模板 id。
# 返回：包含 outcome_id、outcome_name、margin、success_rate、logs 等字段的结果 Dictionary。
func resolve_expedition(squad_id: String, expedition_id: String) -> Dictionary:
	return _build_result(squad_id, expedition_id, true)


# 作用：预览探险结果，不消耗随机波动。
# 参数：squad_id 是小队 id；expedition_id 是探险模板 id。
# 返回：与结算结果同结构的预览 Dictionary。
func preview_expedition(squad_id: String, expedition_id: String) -> Dictionary:
	return _build_result(squad_id, expedition_id, false)


# 作用：统一构建探险结算或预览结果。
# 参数：squad_id 是小队 id；expedition_id 是探险模板 id；use_random 表示是否使用随机波动。
# 返回：结果 Dictionary。
func _build_result(squad_id: String, expedition_id: String, use_random: bool) -> Dictionary:
	GameState.ensure_started()

	var squad_config: Dictionary = DataLoader.get_squad_config(squad_id)
	var expedition_config: Dictionary = DataLoader.get_expedition_config(expedition_id)
	var battle_rules: Dictionary = DataLoader.get_battle_rules_config()
	var outcome_configs: Array = battle_rules.get("outcomes", []) as Array
	var random_delta_min: int = int(battle_rules.get("random_delta_min", -2))
	var random_delta_max: int = int(battle_rules.get("random_delta_max", 2))

	var hero_ids: Array[String] = GameState.get_squad_hero_ids(squad_id)
	var action_tags: Array[String] = _collect_action_tags(expedition_config)
	var squad_power: int = _calculate_squad_power(squad_id, squad_config, expedition_config, hero_ids, action_tags)
	var task_difficulty: int = _calculate_task_difficulty(expedition_config)
	var success_rate_modifier: float = _get_success_rate_modifier(squad_id, squad_config, expedition_config, hero_ids, action_tags)
	var success_margin_bonus: int = _convert_success_rate_to_margin_bonus(success_rate_modifier)
	var random_delta: int = 0
	if use_random:
		random_delta = randi_range(random_delta_min, random_delta_max)
	var base_margin: int = squad_power - task_difficulty + random_delta
	var margin: int = base_margin + success_margin_bonus

	var outcome: Dictionary = _pick_outcome(outcome_configs, margin)
	var success_rate: float = _estimate_success_rate(squad_power - task_difficulty, success_rate_modifier)
	var reward_multiplier: float = _get_reward_multiplier(outcome, squad_config, expedition_config)
	var injury_chance: float = _get_injury_chance(outcome, squad_id, expedition_config, hero_ids, action_tags)
	var extra_resource_rewards: Dictionary = _get_extra_resource_rewards(expedition_config, hero_ids)
	var logs: Array[String] = _build_logs(
		expedition_config,
		outcome,
		margin,
		squad_power,
		task_difficulty,
		random_delta,
		success_rate_modifier,
		injury_chance
	)

	return {
		"squad_id": squad_id,
		"expedition_id": expedition_id,
		"outcome_id": str(outcome.get("id", "retreat")),
		"outcome_name": str(outcome.get("name", "撤退")),
		"base_margin": base_margin,
		"margin": margin,
		"success_margin_bonus": success_margin_bonus,
		"success_rate_modifier": success_rate_modifier,
		"success_rate": success_rate,
		"squad_power": squad_power,
		"task_difficulty": task_difficulty,
		"random_delta": random_delta,
		"reward_multiplier": reward_multiplier,
		"injury_chance": injury_chance,
		"extra_resource_rewards": extra_resource_rewards,
		"hope_delta": int(outcome.get("hope_delta", 0)),
		"log_tone": str(outcome.get("log_tone", "steady")),
		"lines": logs
	}


# 作用：计算小队战力，按文档保持简单可读。
# 参数：squad_id 是小队 id；squad_config 是小队静态配置；hero_ids 是当前编入英雄数组。
# 返回：整数战力。
func _calculate_squad_power(
	squad_id: String,
	squad_config: Dictionary,
	expedition_config: Dictionary,
	hero_ids: Array[String],
	action_tags: Array[String]
) -> int:
	var power: int = 0
	for hero_id: String in hero_ids:
		var hero_config: Dictionary = DataLoader.get_hero_config(hero_id)
		power += int(hero_config.get("base_power", 0))

	power += int(squad_config.get("power_bonus", 0))
	power += _get_training_ground_bonus()
	power += _get_specialty_bonus(squad_id, hero_ids)
	power += _get_event_battle_power_bonus(squad_id, expedition_config, hero_ids, action_tags)
	return power


# 作用：计算任务难度，当前只使用模板基础难度、区域危险度和天气修正。
# 参数：expedition_config 是探险静态配置。
# 返回：整数难度。
func _calculate_task_difficulty(expedition_config: Dictionary) -> int:
	var difficulty: int = int(expedition_config.get("base_difficulty", 0))
	var target_region_id: String = str(expedition_config.get("target_region_id", ""))
	if not target_region_id.is_empty():
		difficulty += GameState.get_region_danger_level(target_region_id)
	difficulty += _get_weather_modifier()
	return difficulty


# 作用：根据差值选择结果档位。
# 参数：outcome_configs 是 battle_rules.outcomes；margin 是最终差值。
# 返回：命中的结果配置；没有命中时返回撤退档位。
func _pick_outcome(outcome_configs: Array, margin: int) -> Dictionary:
	var retreat_outcome: Dictionary = {}
	for outcome_value: Variant in outcome_configs:
		if typeof(outcome_value) != TYPE_DICTIONARY:
			continue
		var outcome: Dictionary = outcome_value as Dictionary
		var min_margin_value: Variant = outcome.get("min_margin", null)
		var max_margin_value: Variant = outcome.get("max_margin", null)
		var min_margin: int = -99999
		var max_margin: int = 99999
		if min_margin_value != null:
			min_margin = int(min_margin_value)
		if max_margin_value != null:
			max_margin = int(max_margin_value)
		if outcome.get("id", "") == "retreat":
			retreat_outcome = outcome.duplicate(true)
		if margin >= min_margin and margin <= max_margin:
			return outcome.duplicate(true)
	return retreat_outcome


# 作用：把结算差值换算成一个直观的成功率预览。
# 参数：margin 是战力与难度差；rate_modifier 是额外成功率修正。
# 返回：0 到 1 之间的浮点数。
func _estimate_success_rate(margin: int, rate_modifier: float) -> float:
	var raw_rate: float = 0.5 + float(margin) * SUCCESS_RATE_PER_MARGIN + rate_modifier
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


# 作用：按英雄专长和小队类型计算额外战力。
# 参数：squad_id 是小队 id；hero_ids 是当前编入英雄数组。
# 返回：整数加成。
func _get_specialty_bonus(squad_id: String, hero_ids: Array[String]) -> int:
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
	return bonus


# 作用：读取小队配置和英雄事件配置，计算成功率修正。
# 参数：squad_id 是小队 id；squad_config 是小队配置；expedition_config 是探险配置；hero_ids 是当前英雄；action_tags 是行动标签。
# 返回：浮点成功率修正，例如 0.15 表示 +15%。
func _get_success_rate_modifier(
	squad_id: String,
	squad_config: Dictionary,
	expedition_config: Dictionary,
	hero_ids: Array[String],
	action_tags: Array[String]
) -> float:
	var modifier: float = 0.0
	var success_bonus_tags: Dictionary = squad_config.get("success_bonus_tags", {}) as Dictionary
	var expanded_action_tags: Array[String] = action_tags.duplicate()
	var expedition_type: String = str(expedition_config.get("type", ""))

	# 开拓队没有单独的 gather 成功率字段时，沿用 explore 标签来体现采集熟练度。
	if expedition_type == "gather":
		_append_unique_tag(expanded_action_tags, "explore")

	for tag: String in expanded_action_tags:
		if success_bonus_tags.has(tag):
			modifier += float(success_bonus_tags.get(tag, 0.0))

	for hero_id: String in hero_ids:
		var hero_config: Dictionary = DataLoader.get_hero_config(hero_id)
		var event_bonuses: Array = hero_config.get("event_bonus", []) as Array
		for bonus_value: Variant in event_bonuses:
			if typeof(bonus_value) != TYPE_DICTIONARY:
				continue
			var bonus_config: Dictionary = bonus_value as Dictionary
			var effect_type: String = str(bonus_config.get("effect_type", ""))
			if effect_type != "success_rate_modifier":
				continue
			var target_id: String = str(bonus_config.get("target_id", ""))
			if not _matches_event_bonus_target(target_id, squad_id, expedition_config, expanded_action_tags):
				continue
			modifier += float(bonus_config.get("value", 0.0))

	return modifier


# 作用：把成功率修正转换成实际结算用的差值补正，保证预览和结算口径一致。
# 参数：success_rate_modifier 是成功率修正。
# 返回：整数差值补正。
func _convert_success_rate_to_margin_bonus(success_rate_modifier: float) -> int:
	return int(round(success_rate_modifier / SUCCESS_RATE_PER_MARGIN))


# 作用：按英雄事件配置给特定小队补战力。
# 参数：squad_id 是小队 id；expedition_config 是探险配置；hero_ids 是当前英雄；action_tags 是行动标签。
# 返回：整数战力加成。
func _get_event_battle_power_bonus(
	squad_id: String,
	expedition_config: Dictionary,
	hero_ids: Array[String],
	action_tags: Array[String]
) -> int:
	var bonus: int = 0
	for hero_id: String in hero_ids:
		var hero_config: Dictionary = DataLoader.get_hero_config(hero_id)
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


# 作用：读取结果档位奖励倍率，并按文档中的小队标签补充采集收益修正。
# 参数：outcome 是结算档位配置；squad_config 是小队配置；expedition_config 是探险配置。
# 返回：最终奖励倍率。
func _get_reward_multiplier(outcome: Dictionary, squad_config: Dictionary, expedition_config: Dictionary) -> float:
	var reward_multiplier: float = float(outcome.get("reward_multiplier", 0.0))
	var expedition_type: String = str(expedition_config.get("type", ""))
	if expedition_type != "gather":
		return reward_multiplier

	var success_bonus_tags: Dictionary = squad_config.get("success_bonus_tags", {}) as Dictionary
	if success_bonus_tags.has("gather"):
		reward_multiplier += float(success_bonus_tags.get("gather", 0.0))
	elif success_bonus_tags.has("explore"):
		reward_multiplier += float(success_bonus_tags.get("explore", 0.0))
	return reward_multiplier


# 作用：按英雄事件配置修正最终受伤概率。
# 参数：outcome 是结算档位；squad_id 是小队 id；expedition_config 是探险配置；hero_ids 是当前英雄；action_tags 是行动标签。
# 返回：0 到 1 之间的最终受伤概率。
func _get_injury_chance(
	outcome: Dictionary,
	squad_id: String,
	expedition_config: Dictionary,
	hero_ids: Array[String],
	action_tags: Array[String]
) -> float:
	var injury_chance: float = float(outcome.get("injury_chance", 0.0))
	for hero_id: String in hero_ids:
		var hero_config: Dictionary = DataLoader.get_hero_config(hero_id)
		var event_bonuses: Array = hero_config.get("event_bonus", []) as Array
		for bonus_value: Variant in event_bonuses:
			if typeof(bonus_value) != TYPE_DICTIONARY:
				continue
			var bonus_config: Dictionary = bonus_value as Dictionary
			var effect_type: String = str(bonus_config.get("effect_type", ""))
			if effect_type != "injury_risk_modifier":
				continue
			var target_id: String = str(bonus_config.get("target_id", ""))
			if not _matches_event_bonus_target(target_id, squad_id, expedition_config, action_tags):
				continue
			injury_chance += float(bonus_config.get("value", 0.0))
	return clamp(injury_chance, 0.0, 1.0)


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


# 作用：获取天气难度修正。
# 参数：无。
# 返回：整数修正，当前项目没有独立天气系统时固定为 0。
func _get_weather_modifier() -> int:
	return 0


# 作用：把结算结果拼成战斗日志。
# 参数：expedition_config 是探险静态配置；outcome 是结果档位；margin 是最终差值；squad_power 是战力；task_difficulty 是难度；random_delta 是随机波动。
# 返回：字符串数组，用于战报和日志弹窗。
func _build_logs(
	expedition_config: Dictionary,
	outcome: Dictionary,
	margin: int,
	squad_power: int,
	task_difficulty: int,
	random_delta: int,
	success_rate_modifier: float,
	injury_chance: float
) -> Array[String]:
	var title: String = str(expedition_config.get("title", "探险"))
	var logs: Array[String] = []
	logs.append("%s 结算完成" % title)
	logs.append("战力 %d，难度 %d，随机 %d，差值 %d" % [squad_power, task_difficulty, random_delta, margin])
	if success_rate_modifier != 0.0:
		logs.append("成功率修正 %.0f%%" % [success_rate_modifier * 100.0])
	if injury_chance > 0.0:
		logs.append("受伤风险 %.0f%%" % [injury_chance * 100.0])
	logs.append("结果：%s" % str(outcome.get("name", "撤退")))
	return logs
