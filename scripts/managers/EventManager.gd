extends Node

const EVENT_TRIGGER_CHANCE: float = 0.8
const MIN_CHECK_INTERVAL_DAYS: int = 2
const MAX_CHECK_INTERVAL_DAYS: int = 3


# 作用：尝试获取今天应该弹出的随机事件。
# 参数：无。
# 返回：事件配置 Dictionary；今天不触发或没有候选事件时返回空字典。
func get_pending_event() -> Dictionary:
	GameState.ensure_started()
	if GameState.was_event_resolved_today():
		return {}
	if GameState.day < GameState.get_next_event_check_day():
		return {}
	if randf() > EVENT_TRIGGER_CHANCE:
		_schedule_next_check("event_roll_missed")
		return {}

	# 先筛出满足天数、资源、建筑、冷却等条件的候选事件，再按权重随机抽一个。
	var candidates: Array[Dictionary] = _get_candidate_events()
	if candidates.is_empty():
		_schedule_next_check("event_no_candidate")
		return {}

	var event_config: Dictionary = _pick_weighted_event(candidates)
	if event_config.is_empty():
		_schedule_next_check("event_pick_empty")
		return {}

	return event_config


# 作用：处理玩家选择的事件选项，并把效果写入 GameState。
# 参数：event_id 是事件 id；choice_id 是选项 id。
# 返回：结果 Dictionary，success 表示是否成功，message 是展示文本，effect_lines 是数值变化说明。
func resolve_choice(event_id: String, choice_id: String) -> Dictionary:
	GameState.ensure_started()
	var event_config: Dictionary = DataLoader.get_event_config(event_id)
	if event_config.is_empty():
		return {
			"success": false,
			"message": "事件不存在"
		}

	var choice: Dictionary = _find_choice(event_config, choice_id)
	if choice.is_empty():
		return {
			"success": false,
			"message": "选择不存在"
		}

	var availability: Dictionary = get_choice_availability(choice)
	if not bool(availability.get("available", false)):
		return {
			"success": false,
			"message": str(availability.get("reason", "条件不足"))
		}

	# 选项效果逐条应用，返回给 UI 的 effect_lines 只负责展示已经发生的变化。
	var effect_lines: Array[String] = []
	var effects: Array = choice.get("effects", []) as Array
	for effect_value: Variant in effects:
		if typeof(effect_value) != TYPE_DICTIONARY:
			continue
		var effect: Dictionary = effect_value as Dictionary
		var line: String = _apply_effect(effect, event_id, choice_id)
		if not line.is_empty():
			effect_lines.append(line)

	var result_text: String = str(choice.get("result_text", "选择已经执行。"))
	var label: String = str(choice.get("label", choice_id))
	var report_effect_text: String = _join_string_array(effect_lines, "无直接数值变化")
	GameState.mark_event_resolved(event_id, "event_choice:%s" % choice_id)
	_apply_event_cooldown(event_config)
	_schedule_next_check("event_resolved")
	GameState.add_battle_report("事件：%s，选择“%s”：%s。" % [
		str(event_config.get("title", event_id)),
		label,
		report_effect_text
	], "event_choice:%s" % choice_id)

	return {
		"success": true,
		"message": result_text,
		"effect_lines": effect_lines
	}


# 作用：检查某个事件选项当前是否可用。
# 参数：choice 是选项配置 Dictionary。
# 返回：包含 available 和 reason 的 Dictionary。
func get_choice_availability(choice: Dictionary) -> Dictionary:
	var conditions: Dictionary = choice.get("conditions", {}) as Dictionary
	var failed_reasons: Array[String] = _get_condition_failed_reasons(conditions)
	return {
		"available": failed_reasons.is_empty(),
		"reason": _join_string_array(failed_reasons, "满足条件")
	}


# 作用：生成某个事件选项的效果预览文本。
# 参数：choice 是选项配置 Dictionary。
# 返回：中文效果预览；没有数值效果时返回“无直接数值变化”。
func get_choice_effect_preview(choice: Dictionary) -> String:
	var effects: Array = choice.get("effects", []) as Array
	var lines: Array[String] = []
	for effect_value: Variant in effects:
		if typeof(effect_value) != TYPE_DICTIONARY:
			continue
		var effect: Dictionary = effect_value as Dictionary
		var text: String = _describe_effect(effect)
		if not text.is_empty():
			lines.append(text)
	return _join_string_array(lines, "无直接数值变化")


# 作用：标记今天事件已跳过或无事发生，并安排下次事件检查。
# 参数：source 是日志来源。
# 返回：无。
func mark_event_skipped(source: String) -> void:
	GameState.mark_event_resolved("none", source)
	_schedule_next_check(source)


# 作用：筛选当前可触发的事件候选。
# 参数：无。
# 返回：满足触发条件、未冷却、未被一次性解决过的事件配置数组。
func _get_candidate_events() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var event_order: Array[String] = DataLoader.get_event_order()

	# 候选事件按配置顺序遍历，逐个排除一次性、冷却中和条件不满足的事件。
	for event_id: String in event_order:
		var event_config: Dictionary = DataLoader.get_event_config(event_id)
		if event_config.is_empty():
			continue
		if bool(event_config.get("once_only", false)) and GameState.has_event_been_resolved(event_id):
			continue
		var unique_key: String = str(event_config.get("unique_key", ""))
		if GameState.is_event_on_cooldown(unique_key):
			continue
		var trigger: Dictionary = event_config.get("trigger", {}) as Dictionary
		if not _get_condition_failed_reasons(trigger).is_empty():
			continue
		result.append(event_config)

	return result


# 作用：按事件权重从候选列表中随机选择一个事件。
# 参数：candidates 是候选事件配置数组。
# 返回：选中的事件配置副本；候选为空时不应调用。
func _pick_weighted_event(candidates: Array[Dictionary]) -> Dictionary:
	var total_weight: int = 0
	for event_config: Dictionary in candidates:
		total_weight += max(int(event_config.get("weight", 1)), 1)

	if total_weight <= 0:
		return candidates[0].duplicate(true)

	var roll: int = randi_range(1, total_weight)
	var current: int = 0
	for event_config: Dictionary in candidates:
		current += max(int(event_config.get("weight", 1)), 1)
		if roll <= current:
			return event_config.duplicate(true)

	return candidates[0].duplicate(true)


# 作用：在事件配置中查找指定选项。
# 参数：event_config 是事件配置；choice_id 是选项 id。
# 返回：选项配置副本；找不到时返回空字典。
func _find_choice(event_config: Dictionary, choice_id: String) -> Dictionary:
	var choices: Array = event_config.get("choices", []) as Array
	for choice_value: Variant in choices:
		if typeof(choice_value) != TYPE_DICTIONARY:
			continue
		var choice: Dictionary = choice_value as Dictionary
		if str(choice.get("id", "")) == choice_id:
			return choice.duplicate(true)
	return {}


# 作用：检查条件配置中哪些条件未满足。
# 参数：conditions 是条件配置 Dictionary。
# 返回：失败原因字符串数组；空数组表示条件全部满足。
func _get_condition_failed_reasons(conditions: Dictionary) -> Array[String]:
	var reasons: Array[String] = []
	var min_day: int = int(conditions.get("min_day", 0))
	if min_day > 0 and GameState.day < min_day:
		reasons.append("第 %d 天后开放" % min_day)

	var max_day: int = int(conditions.get("max_day", 0))
	if max_day > 0 and GameState.day > max_day:
		reasons.append("已超过第 %d 天" % max_day)

	var min_resources: Dictionary = conditions.get("min_resources", {}) as Dictionary
	for resource_id_value: Variant in min_resources.keys():
		var resource_id: String = str(resource_id_value)
		var required_amount: int = int(min_resources.get(resource_id, 0))
		if GameState.get_resource_amount(resource_id) < required_amount:
			reasons.append("%s需要 %d" % [GameState.get_resource_name(resource_id), required_amount])

	var required_building_levels: Dictionary = conditions.get("required_building_levels", {}) as Dictionary
	for building_id_value: Variant in required_building_levels.keys():
		var building_id: String = str(building_id_value)
		var required_level: int = int(required_building_levels.get(building_id, 0))
		if GameState.get_building_level(building_id) < required_level:
			var config: Dictionary = DataLoader.get_building_config(building_id)
			reasons.append("%s %d 级" % [str(config.get("name", building_id)), required_level])

	var required_job_assignments: Dictionary = conditions.get("required_job_assignments", {}) as Dictionary
	for job_id_value: Variant in required_job_assignments.keys():
		var job_id: String = str(job_id_value)
		var required_count: int = int(required_job_assignments.get(job_id, 0))
		if GameState.get_job_assignment(job_id) < required_count:
			reasons.append("%s %d 人" % [JobManager.get_job_name(job_id), required_count])

	return reasons


# 作用：应用单条事件效果。
# 参数：effect 是效果配置；event_id 是事件 id；choice_id 是选项 id。
# 返回：本条效果的中文变化说明；未知效果返回空字符串并输出错误。
func _apply_effect(effect: Dictionary, event_id: String, choice_id: String) -> String:
	var effect_type: String = str(effect.get("effect_type", ""))
	var target_id: String = str(effect.get("target_id", ""))
	var value: Variant = effect.get("value", 0)
	var source: String = "event:%s:%s" % [event_id, choice_id]

	match effect_type:
		"resource_delta":
			var amount: int = int(value)
			GameState.add_resource(target_id, amount, source)
			return "%s %s%d" % [_get_resource_or_target_name(target_id), _format_sign(amount), abs(amount)]
		"state_change":
			return _apply_state_change(target_id, value, source)
		_:
			push_error("[EventManager] unknown effect_type=%s target=%s" % [effect_type, target_id])
			return ""


# 作用：应用 state_change 类型事件效果。
# 参数：target_id 是状态目标；value 是变化值；source 是日志来源。
# 返回：中文变化说明；未知目标返回空字符串并输出错误。
func _apply_state_change(target_id: String, value: Variant, source: String) -> String:
	match target_id:
		"morale_score":
			var morale_delta: int = GameState.add_morale(int(value), source)
			return "士气 %s%d" % [_format_sign(morale_delta), abs(morale_delta)]
		"temperature_score":
			var before: int = GameState.temperature_score
			GameState.temperature_score = int(clamp(GameState.temperature_score + int(value), 0, 100))
			GameState.refresh_shelter_status("event_temperature_changed")
			GameState.state_changed.emit()
			GameState.temperature_changed.emit()
			var delta: int = GameState.temperature_score - before
			return "温度评分 %s%d" % [_format_sign(delta), abs(delta)]
		"population.healthy":
			var added: int = GameState.add_population_state("healthy", int(value), source)
			return "健康人口 %s%d" % [_format_sign(added), abs(added)]
		"population.transfer":
			if typeof(value) != TYPE_DICTIONARY:
				return ""
			var transfer: Dictionary = value as Dictionary
			var from_state: String = str(transfer.get("from_state", ""))
			var to_state: String = str(transfer.get("to_state", ""))
			var amount: int = int(transfer.get("amount", 0))
			var actual: int = GameState.transfer_population(from_state, to_state, amount, source)
			return "%s转为%s %d" % [_get_population_state_name(from_state), _get_population_state_name(to_state), actual]
		_:
			push_error("[EventManager] unknown state_change target=%s" % target_id)
			return ""


# 作用：把事件效果配置转换成预览文本，不真正修改状态。
# 参数：effect 是效果配置 Dictionary。
# 返回：中文预览文本；无法描述时返回空字符串。
func _describe_effect(effect: Dictionary) -> String:
	var effect_type: String = str(effect.get("effect_type", ""))
	var target_id: String = str(effect.get("target_id", ""))
	var value: Variant = effect.get("value", 0)

	match effect_type:
		"resource_delta":
			var amount: int = int(value)
			return "%s %s%d" % [_get_resource_or_target_name(target_id), _format_sign(amount), abs(amount)]
		"state_change":
			match target_id:
				"morale_score":
					var morale_amount: int = int(value)
					return "士气 %s%d" % [_format_sign(morale_amount), abs(morale_amount)]
				"temperature_score":
					var temperature_amount: int = int(value)
					return "温度评分 %s%d" % [_format_sign(temperature_amount), abs(temperature_amount)]
				"population.healthy":
					var population_amount: int = int(value)
					return "健康人口 %s%d" % [_format_sign(population_amount), abs(population_amount)]
				"population.transfer":
					if typeof(value) != TYPE_DICTIONARY:
						return ""
					var transfer: Dictionary = value as Dictionary
					return "%s转为%s %d" % [
						_get_population_state_name(str(transfer.get("from_state", ""))),
						_get_population_state_name(str(transfer.get("to_state", ""))),
						int(transfer.get("amount", 0))
					]
				_:
					return "状态变化"
		_:
			return ""


# 作用：事件解决后写入同类事件冷却。
# 参数：event_config 是事件配置 Dictionary。
# 返回：无。没有 unique_key 或 cooldown_days 时不写冷却。
func _apply_event_cooldown(event_config: Dictionary) -> void:
	var unique_key: String = str(event_config.get("unique_key", ""))
	var cooldown_days: int = int(event_config.get("cooldown_days", 0))
	if unique_key.is_empty() or cooldown_days <= 0:
		return
	GameState.set_event_cooldown(unique_key, GameState.day + cooldown_days, "event_cooldown")


# 作用：安排下一次事件检查日。
# 参数：source 是日志来源。
# 返回：无。检查间隔在 MIN_CHECK_INTERVAL_DAYS 到 MAX_CHECK_INTERVAL_DAYS 之间随机。
func _schedule_next_check(source: String) -> void:
	var interval: int = randi_range(MIN_CHECK_INTERVAL_DAYS, MAX_CHECK_INTERVAL_DAYS)
	GameState.set_next_event_check_day(GameState.day + interval, source)


# 作用：把资源 id 或特殊目标 id 转换成中文名。
# 参数：target_id 是资源或目标 id。
# 返回：中文名；未知 id 返回原始 target_id。
func _get_resource_or_target_name(target_id: String) -> String:
	if target_id == "hope":
		return "希望值"
	var resource_config: Dictionary = DataLoader.get_resource_config(target_id)
	if not resource_config.is_empty():
		return str(resource_config.get("name", target_id))
	return target_id


# 作用：把人口状态 id 转换成中文名。
# 参数：state_id 是人口状态 id。
# 返回：中文状态名；未知状态返回原始 state_id。
func _get_population_state_name(state_id: String) -> String:
	match state_id:
		"healthy":
			return "健康"
		"light_wound":
			return "轻伤"
		"heavy_wound":
			return "重伤"
		"dead":
			return "死亡"
		_:
			return state_id


# 作用：获取整数变化量的符号文本。
# 参数：amount 是变化量。
# 返回：非负数返回“+”，负数返回“-”。
func _format_sign(amount: int) -> String:
	if amount >= 0:
		return "+"
	return "-"


# 作用：拼接字符串数组。
# 参数：items 是字符串数组；empty_text 是数组为空时显示的文本。
# 返回：用中文逗号连接后的字符串。
func _join_string_array(items: Array[String], empty_text: String) -> String:
	if items.is_empty():
		return empty_text
	var parts: PackedStringArray = PackedStringArray()
	for item: String in items:
		parts.append(item)
	return "，".join(parts)
