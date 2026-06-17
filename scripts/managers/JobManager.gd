extends Node

const WORKER_ID: String = "worker"
const HUNTER_ID: String = "hunter"
const COOK_ID: String = "cook"
const MEDIC_ID: String = "medic"
const ENGINEER_ID: String = "engineer"


func get_job_name(job_id: String) -> String:
	var config: Dictionary = DataLoader.get_job_config(job_id)
	return str(config.get("name", job_id))


func get_effective_worker_count(job_id: String) -> float:
	var assignments: Dictionary = GameState.get_job_assignments()
	var job_order: Array[String] = DataLoader.get_job_order()
	var healthy_left: int = GameState.get_healthy_population()
	var wounded_modifier: float = DataLoader.get_wounded_output_modifier()

	for current_job_id: String in job_order:
		var count: int = int(assignments.get(current_job_id, 0))
		var healthy_used: int = min(count, healthy_left)
		var light_used: int = count - healthy_used
		if current_job_id == job_id:
			return float(healthy_used) + float(light_used) * wounded_modifier
		healthy_left = max(healthy_left - healthy_used, 0)

	return 0.0


func get_assignment_capacity_text() -> String:
	return "可分配：健康 %d + 轻伤 %d（半产出），未分配 %d" % [
		GameState.get_healthy_population(),
		int(GameState.population.get("light_wound", 0)),
		GameState.get_unassigned_population()
	]


func get_preview() -> Dictionary:
	var wood_output: int = _round_output(WORKER_ID, "wood")
	var food_output: int = _round_output(HUNTER_ID, "food")
	var parts_output: int = _round_output(ENGINEER_ID, "parts")
	var food_save_rate: float = get_food_save_rate()
	var food_saved: int = get_food_saved_amount(GameState.get_alive_population())
	var heal_points: int = get_heal_points()
	var coal_saved: int = get_coal_saved_amount()
	var morale_bonus: int = get_cook_morale_bonus(true)

	return {
		"resources": {
			"wood": wood_output,
			"food": food_output,
			"parts": parts_output
		},
		"food_save_rate": food_save_rate,
		"food_saved": food_saved,
		"heal_points": heal_points,
		"coal_saved": coal_saved,
		"morale_bonus": morale_bonus,
		"lines": _build_preview_lines(wood_output, food_output, parts_output, food_save_rate, food_saved, heal_points, coal_saved, morale_bonus)
	}


func apply_job_production() -> Dictionary:
	var preview: Dictionary = get_preview()
	var resources: Dictionary = preview.get("resources", {}) as Dictionary
	var deltas: Dictionary = {}
	var lines: Array[String] = []

	for resource_id_value: Variant in resources.keys():
		var resource_id: String = str(resource_id_value)
		var amount: int = int(resources.get(resource_id, 0))
		if amount <= 0:
			continue
		GameState.add_resource(resource_id, amount, "job_production:%s" % resource_id)
		deltas[resource_id] = amount
		lines.append("%s +%d" % [GameState.get_resource_name(resource_id), amount])

	return {
		"deltas": deltas,
		"lines": lines
	}


func apply_medical_treatment() -> Dictionary:
	var heal_points: int = get_heal_points()
	var remaining: int = heal_points
	var changes: Array[String] = []

	if remaining > 0:
		var heavy_to_light: int = GameState.transfer_population("heavy_wound", "light_wound", remaining, "job_medic_treatment")
		if heavy_to_light > 0:
			changes.append("医护治疗：%d 名重伤转为轻伤" % heavy_to_light)
			remaining -= heavy_to_light

	if remaining > 0:
		var light_to_healthy: int = GameState.transfer_population("light_wound", "healthy", remaining, "job_medic_treatment")
		if light_to_healthy > 0:
			changes.append("医护治疗：%d 名轻伤恢复健康" % light_to_healthy)
			remaining -= light_to_healthy

	if heal_points > 0 and changes.is_empty():
		changes.append("医护待命：今晚没有需要治疗的病患")

	return {
		"heal_points": heal_points,
		"changes": changes
	}


func get_food_save_rate() -> float:
	if GameState.get_building_level("kitchen") <= 0:
		return 0.0
	var rate_per_worker: float = float(BuildingManager.get_level_production_value("kitchen", "food_save_rate", 0.0))
	var effective_count: float = get_effective_worker_count(COOK_ID)
	return clamp(effective_count * rate_per_worker, 0.0, 0.5)


func get_food_saved_amount(base_food_need: int) -> int:
	var rate: float = get_food_save_rate()
	return int(floor(float(base_food_need) * rate))


func get_heal_points() -> int:
	if GameState.get_building_level("medical_tent") <= 0:
		return 0
	var effective_count: float = get_effective_worker_count(MEDIC_ID)
	var heal_points_per_medic: float = float(BuildingManager.get_level_production_value("medical_tent", "heal_points_per_medic", 1.0))
	return int(floor(effective_count * heal_points_per_medic))


func get_coal_saved_amount() -> int:
	var effective_count: float = get_effective_worker_count(ENGINEER_ID)
	return int(floor(effective_count / 2.0))


func get_cook_morale_bonus(food_will_be_enough: bool) -> int:
	if not food_will_be_enough:
		return 0
	if not is_cook_support_enough():
		return 0
	return 2


func is_cook_support_enough() -> bool:
	if GameState.get_building_level("kitchen") <= 0:
		return false
	return get_effective_worker_count(COOK_ID) >= 2.0


func _round_output(job_id: String, output_id: String) -> int:
	var config: Dictionary = DataLoader.get_job_config(job_id)
	var output: Dictionary = config.get("base_output", {}) as Dictionary
	var base_amount: float = float(output.get(output_id, 0))
	match job_id:
		WORKER_ID:
			if GameState.get_building_level("lumber_yard") <= 0:
				return 0
			base_amount = float(BuildingManager.get_level_production_value("lumber_yard", "wood_per_worker", base_amount))
		HUNTER_ID:
			if GameState.get_building_level("hunter_lodge") <= 0:
				return 0
			base_amount = float(BuildingManager.get_level_production_value("hunter_lodge", "food_per_hunter", base_amount))
		ENGINEER_ID:
			if GameState.get_building_level("workshop") <= 0:
				return 0
			base_amount = float(BuildingManager.get_level_production_value("workshop", "parts_per_engineer", base_amount))
	var effective_count: float = get_effective_worker_count(job_id)
	return int(floor(effective_count * base_amount))


func _build_preview_lines(wood_output: int, food_output: int, parts_output: int, food_save_rate: float, food_saved: int, heal_points: int, coal_saved: int, morale_bonus: int) -> Array[String]:
	var lines: Array[String] = []
	lines.append("资源产出：木材 +%d，食物 +%d，零件 +%d" % [wood_output, food_output, parts_output])
	lines.append("厨房效果：食物消耗 -%d（节省率 %.0f%%），士气最多 +%d" % [
		food_saved,
		food_save_rate * 100.0,
		morale_bonus
	])
	lines.append("医护效果：治疗点 %d，优先重伤转轻伤" % heal_points)
	lines.append("工程维护：煤炭消耗 -%d" % coal_saved)
	return lines
