extends Node

const FOOD_COST_PER_PERSON: int = 1
const COAL_COST_PER_FURNACE_LEVEL: int = 2
const FOOD_SHORTAGE_HOPE_PENALTY: int = -5
const FOOD_SHORTAGE_MORALE_PENALTY: int = -8
const TEMPERATURE_DANGER_MORALE_PENALTY: int = -5
const MEDIC_TREATMENT_MORALE_BONUS: int = 2


# 作用：执行一次夜晚结算，处理岗位产出、食物/煤炭消耗、温度伤病、士气希望变化，并推进到下一天。
# 参数：无。
# 返回：结算结果 Dictionary，包含食物、煤炭、温度、健康、希望、士气、岗位产出和展示行。
func settle_night() -> Dictionary:
	GameState.ensure_started()

	# 先记录结算前快照，后面用于生成“变化前 -> 变化后”的弹窗文本。
	var day_before: int = GameState.day
	var alive_population: int = GameState.get_alive_population()
	var hope_before: int = GameState.get_resource_amount("hope")
	var morale_before: int = GameState.morale_score
	var healthy_before: int = GameState.get_healthy_population()
	var sick_before: int = GameState.get_sick_population()
	var temperature_score_before: int = GameState.temperature_score
	var temperature_status_before: String = GameState.get_temperature_status()
	var job_production: Dictionary = JobManager.apply_job_production()
	var medical_result: Dictionary = JobManager.apply_medical_treatment()
	var food_before: int = GameState.get_resource_amount("food")
	var coal_before: int = GameState.get_resource_amount("coal")

	# 食物需求由存活人口决定，厨师会先抵扣一部分需求。
	var base_food_need: int = alive_population * FOOD_COST_PER_PERSON
	var food_saved: int = JobManager.get_food_saved_amount(base_food_need)
	var food_need: int = max(base_food_need - food_saved, 0)
	var food_paid: int = _min_int(food_before, food_need)
	var food_shortage: int = food_need - food_paid
	if food_paid > 0:
		GameState.add_resource("food", -food_paid, "night_settlement_food")

	# 煤炭需求由寒炉等级或建筑配置决定，工程师维护会降低一部分煤炭消耗。
	var base_coal_need: int = _get_furnace_coal_need()
	var coal_saved: int = JobManager.get_coal_saved_amount()
	var coal_need: int = max(base_coal_need - coal_saved, 0)
	var coal_paid: int = _min_int(coal_before, coal_need)
	var coal_shortage: int = coal_need - coal_paid
	if coal_paid > 0:
		GameState.add_resource_with_refresh("coal", -coal_paid, "night_settlement_coal", false)

	var hope_delta: int = 0
	var hope_reasons: Array[String] = []
	var morale_reasons: Array[String] = []
	var health_changes: Array[String] = []
	var medical_changes: Array[String] = _to_string_array(medical_result.get("changes", []))
	for medical_change: String in medical_changes:
		health_changes.append(medical_change)
	var did_treat_patient: bool = _has_medical_treatment_change(medical_changes)
	if did_treat_patient:
		GameState.add_morale(MEDIC_TREATMENT_MORALE_BONUS, "night_medic_treatment")
		morale_reasons.append("医护完成治疗，士气 +%d" % MEDIC_TREATMENT_MORALE_BONUS)

	# 温度危险会造成伤病和士气下降；温度温暖暂时只作为正向说明，不额外加数值。
	if temperature_status_before == "危险":
		var cold_sick_added: int = GameState.transfer_population("healthy", "light_wound", 1, "night_temperature_danger")
		if cold_sick_added > 0:
			health_changes.append("温度危险，%d 名健康幸存者转为轻伤" % cold_sick_added)
		else:
			health_changes.append("温度危险，但没有健康幸存者可转为轻伤")
		GameState.add_morale(TEMPERATURE_DANGER_MORALE_PENALTY, "night_temperature_danger")
		morale_reasons.append("温度危险，士气 %d" % TEMPERATURE_DANGER_MORALE_PENALTY)
	elif temperature_status_before == "温暖":
		morale_reasons.append("温度温暖，营地状态稳定")

	# 食物不足是夜晚最重要的负面压力，会同时影响健康、士气和希望值。
	if food_shortage > 0:
		var food_health_change: Dictionary = _apply_food_shortage_health_drop()
		health_changes.append(str(food_health_change.get("message", "食物不足，健康下降")))
		GameState.add_morale(FOOD_SHORTAGE_MORALE_PENALTY, "night_food_shortage")
		morale_reasons.append("食物不足，士气 %d" % FOOD_SHORTAGE_MORALE_PENALTY)
		hope_delta += FOOD_SHORTAGE_HOPE_PENALTY
		hope_reasons.append("食物不足，希望值 %d" % FOOD_SHORTAGE_HOPE_PENALTY)
	else:
		var cook_morale_bonus: int = JobManager.get_cook_morale_bonus(true)
		if cook_morale_bonus > 0:
			GameState.add_morale(cook_morale_bonus, "night_cook_support")
			morale_reasons.append("厨师保障食物秩序，士气 +%d" % cook_morale_bonus)

	if hope_delta != 0:
		GameState.add_resource("hope", hope_delta, "night_settlement_hope")

	# 所有数值写入后，再取一次结算后快照。
	var food_after: int = GameState.get_resource_amount("food")
	var coal_after: int = GameState.get_resource_amount("coal")
	var hope_after: int = GameState.get_resource_amount("hope")
	var morale_after: int = GameState.morale_score
	var healthy_after: int = GameState.get_healthy_population()
	var sick_after: int = GameState.get_sick_population()

	GameState.advance_day("night_settlement")
	GameState.refresh_temperature_score("night_settlement_next_day")

	# 统一返回结构化结果，弹窗只负责展示，不再重新计算结算规则。
	var result: Dictionary = {
		"day_before": day_before,
		"day_after": GameState.day,
		"alive_population": alive_population,
		"food": {
			"base_need": base_food_need,
			"saved": food_saved,
			"need": food_need,
			"paid": food_paid,
			"shortage": food_shortage,
			"before": food_before,
			"after": food_after
		},
		"coal": {
			"base_need": base_coal_need,
			"saved": coal_saved,
			"need": coal_need,
			"paid": coal_paid,
			"shortage": coal_shortage,
			"before": coal_before,
			"after": coal_after
		},
		"temperature": {
			"score": temperature_score_before,
			"status": temperature_status_before
		},
		"health": {
			"healthy_before": healthy_before,
			"healthy_after": healthy_after,
			"sick_before": sick_before,
			"sick_after": sick_after,
			"changes": health_changes
		},
		"hope": {
			"before": hope_before,
			"after": hope_after,
			"delta": hope_after - hope_before,
			"reasons": hope_reasons
		},
		"morale": {
			"before": morale_before,
			"after": morale_after,
			"delta": morale_after - morale_before,
			"reasons": morale_reasons
		},
		"jobs": {
			"production": job_production,
			"medical": medical_result
		}
	}
	result["lines"] = _build_display_lines(result)

	print("[NightSettlementManager] settle_night day=%d->%d alive=%d food_base_need=%d food_saved=%d food_need=%d food_paid=%d food_shortage=%d food_before=%d food_after=%d coal_base_need=%d coal_saved=%d coal_need=%d coal_paid=%d coal_shortage=%d coal_before=%d coal_after=%d temperature_score=%d temperature_status=%s healthy=%d->%d sick=%d->%d morale=%d->%d hope=%d->%d morale_reasons=%s hope_reasons=%s health_changes=%s" % [
		day_before,
		GameState.day,
		alive_population,
		base_food_need,
		food_saved,
		food_need,
		food_paid,
		food_shortage,
		food_before,
		food_after,
		base_coal_need,
		coal_saved,
		coal_need,
		coal_paid,
		coal_shortage,
		coal_before,
		coal_after,
		temperature_score_before,
		temperature_status_before,
		healthy_before,
		healthy_after,
		sick_before,
		sick_after,
		morale_before,
		morale_after,
		hope_before,
		hope_after,
		_join_string_array(morale_reasons, "无"),
		_join_string_array(hope_reasons, "无"),
		_join_string_array(health_changes, "无")
	])

	return result


# 作用：处理食物不足导致的健康恶化。
# 参数：无。
# 返回：Dictionary，包含 amount 实际变化人数和 message 展示文本。
func _apply_food_shortage_health_drop() -> Dictionary:
	var healthy_to_light: int = GameState.transfer_population("healthy", "light_wound", 1, "night_food_shortage")
	if healthy_to_light > 0:
		return {
			"amount": healthy_to_light,
			"message": "食物不足，%d 名健康幸存者转为轻伤" % healthy_to_light
		}

	var light_to_heavy: int = GameState.transfer_population("light_wound", "heavy_wound", 1, "night_food_shortage")
	if light_to_heavy > 0:
		return {
			"amount": light_to_heavy,
			"message": "食物不足，%d 名轻伤幸存者转为重伤" % light_to_heavy
		}

	return {
		"amount": 0,
		"message": "食物不足，但没有可继续恶化的幸存者"
	}


# 作用：判断医护结果中是否真的发生了治疗。
# 参数：changes 是治疗结果文本数组。
# 返回：包含“治疗”字样时返回 true，否则返回 false。
func _has_medical_treatment_change(changes: Array[String]) -> bool:
	for change: String in changes:
		if change.find("治疗") >= 0:
			return true
	return false


# 作用：把结构化夜晚结算结果转换成弹窗展示行。
# 参数：result 是 settle_night() 生成的结算结果 Dictionary。
# 返回：中文展示行数组。
func _build_display_lines(result: Dictionary) -> Array[String]:
	var jobs: Dictionary = result.get("jobs", {}) as Dictionary
	var production: Dictionary = jobs.get("production", {}) as Dictionary
	var production_lines: Array[String] = _to_string_array(production.get("lines", []))
	var food: Dictionary = result.get("food", {}) as Dictionary
	var coal: Dictionary = result.get("coal", {}) as Dictionary
	var temperature: Dictionary = result.get("temperature", {}) as Dictionary
	var health: Dictionary = result.get("health", {}) as Dictionary
	var hope: Dictionary = result.get("hope", {}) as Dictionary
	var morale: Dictionary = result.get("morale", {}) as Dictionary
	var hope_reasons: Array[String] = _to_string_array(hope.get("reasons", []))
	var morale_reasons: Array[String] = _to_string_array(morale.get("reasons", []))
	var health_changes: Array[String] = _to_string_array(health.get("changes", []))

	var lines: Array[String] = []
	lines.append("岗位产出：%s" % _join_string_array(production_lines, "无"))
	lines.append("食物消耗：基础需要 %d，厨师节省 %d，实际需要 %d，已消耗 %d，缺口 %d，剩余 %d" % [
		int(food.get("base_need", 0)),
		int(food.get("saved", 0)),
		int(food.get("need", 0)),
		int(food.get("paid", 0)),
		int(food.get("shortage", 0)),
		int(food.get("after", 0))
	])
	lines.append("煤炭消耗：寒炉 %d 级，基础需要 %d，工程维护节省 %d，实际需要 %d，已消耗 %d，缺口 %d，剩余 %d" % [
		GameState.furnace_level,
		int(coal.get("base_need", 0)),
		int(coal.get("saved", 0)),
		int(coal.get("need", 0)),
		int(coal.get("paid", 0)),
		int(coal.get("shortage", 0)),
		int(coal.get("after", 0))
	])
	lines.append("温度结果：%d（%s）" % [
		int(temperature.get("score", 0)),
		str(temperature.get("status", "未知"))
	])
	lines.append("健康变化：健康 %d -> %d，病患 %d -> %d" % [
		int(health.get("healthy_before", 0)),
		int(health.get("healthy_after", 0)),
		int(health.get("sick_before", 0)),
		int(health.get("sick_after", 0))
	])
	lines.append("健康原因：%s" % _join_string_array(health_changes, "无变化"))
	lines.append("士气变化：%d -> %d（%s）" % [
		int(morale.get("before", 0)),
		int(morale.get("after", 0)),
		_join_string_array(morale_reasons, "无变化")
	])
	lines.append("希望值变化：%d -> %d（%s）" % [
		int(hope.get("before", 0)),
		int(hope.get("after", 0)),
		_join_string_array(hope_reasons, "无变化")
	])
	return lines


# 作用：拼接字符串数组。
# 参数：items 是字符串数组；empty_text 是数组为空时显示的文本。
# 返回：用分号连接后的字符串。
func _join_string_array(items: Array[String], empty_text: String) -> String:
	if items.is_empty():
		return empty_text

	var parts: PackedStringArray = PackedStringArray()
	for item: String in items:
		parts.append(item)
	return "；".join(parts)


# 作用：把 Variant 安全转换成字符串数组。
# 参数：value 是任意值，通常来自 Dictionary.get()。
# 返回：如果 value 是数组，逐项转成字符串；否则返回空数组。
func _to_string_array(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if typeof(value) != TYPE_ARRAY:
		return result

	var raw_items: Array = value as Array
	for item_value: Variant in raw_items:
		result.append(str(item_value))
	return result


# 作用：返回两个整数中的较小值。
# 参数：left 和 right 是待比较整数。
# 返回：较小的整数。
func _min_int(left: int, right: int) -> int:
	if left < right:
		return left
	return right


# 作用：计算寒炉夜晚基础煤炭需求。
# 参数：无。
# 返回：优先读取当前寒炉等级配置中的 coal_cost_per_night；缺失时按寒炉等级乘以默认消耗计算。
func _get_furnace_coal_need() -> int:
	var configured_need: int = int(BuildingManager.get_level_production_value("furnace", "coal_cost_per_night", 0))
	if configured_need > 0:
		return configured_need
	return GameState.furnace_level * COAL_COST_PER_FURNACE_LEVEL
