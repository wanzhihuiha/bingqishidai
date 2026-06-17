extends Node

signal state_changed
signal resources_changed
signal temperature_changed
signal quest_relevant_state_changed

const DEFAULT_FURNACE_LEVEL: int = 1
const DEFAULT_WEATHER_PRESSURE: float = 0.0
const DEFAULT_MORALE_SCORE: int = 60
const FIRST_SCOUT_REGION_ID: String = "a1_broken_pines"
const INITIAL_BUILT_BUILDINGS: Array[String] = ["furnace", "lumber_yard", "hunter_lodge"]

var day: int = 1
var phase: String = "day"
var resources: Dictionary = {}
var population: Dictionary = {
	"healthy": 0,
	"light_wound": 0,
	"heavy_wound": 0,
	"dead": 0
}
var furnace_level: int = DEFAULT_FURNACE_LEVEL
var morale_score: int = DEFAULT_MORALE_SCORE
var health_status: String = "healthy"
var shelter_status_text: String = "营地维持中"
var temperature_score: int = 0
var weather_pressure: float = DEFAULT_WEATHER_PRESSURE
var collected_resources: Dictionary = {}
var buildings: Dictionary = {}
var job_assignments: Dictionary = {}
var assigned_jobs_total: int = 0
var scout_state: Dictionary = {}
var regions: Dictionary = {}
var quests: Dictionary = {}
var daily_flags: Dictionary = {}
var is_started: bool = false


func start_new_game() -> void:
	day = 1
	phase = "day"
	resources = _build_initial_resources()
	population = _build_initial_population()
	furnace_level = DEFAULT_FURNACE_LEVEL
	morale_score = DEFAULT_MORALE_SCORE
	weather_pressure = DEFAULT_WEATHER_PRESSURE
	collected_resources = {}
	buildings = _build_initial_buildings()
	job_assignments = _build_initial_job_assignments()
	assigned_jobs_total = 0
	scout_state = _build_initial_scout_state()
	regions = _build_initial_regions()
	quests = _build_initial_quests()
	daily_flags = _build_initial_daily_flags()
	_update_building_unlocks_for_day("start_new_game")
	refresh_temperature_score("start_new_game")
	refresh_shelter_status("start_new_game")
	is_started = true
	print("[GameState] start_new_game day=%d phase=%s resources=%s population=%s furnace_level=%d morale=%d health_status=%s shelter_status=%s temperature_score=%d" % [
		day,
		phase,
		str(resources),
		str(population),
		furnace_level,
		morale_score,
		health_status,
		shelter_status_text,
		temperature_score
	])
	state_changed.emit()
	resources_changed.emit()
	temperature_changed.emit()
	quest_relevant_state_changed.emit()


func ensure_started() -> void:
	if is_started:
		return
	print("[GameState] ensure_started fallback")
	start_new_game()


func get_resource_amount(resource_id: String) -> int:
	return int(resources.get(resource_id, 0))


func get_resource_name(resource_id: String) -> String:
	var config: Dictionary = DataLoader.get_resource_config(resource_id)
	return str(config.get("name", resource_id))


func get_resource_max_amount(resource_id: String) -> int:
	var config: Dictionary = DataLoader.get_resource_config(resource_id)
	var max_value: Variant = config.get("max_amount", null)
	if max_value == null:
		return -1
	return int(max_value)


func is_resource_near_max(resource_id: String) -> bool:
	var max_amount: int = get_resource_max_amount(resource_id)
	if max_amount < 0:
		return false
	var current_amount: int = get_resource_amount(resource_id)
	return current_amount >= int(float(max_amount) * 0.8)


func get_resource_order() -> Array[String]:
	return DataLoader.get_resource_order()


func set_resource(resource_id: String, amount: int, source: String) -> void:
	var before: int = get_resource_amount(resource_id)
	var after: int = _clamp_resource(resource_id, amount)
	resources[resource_id] = after
	print("[GameState] set_resource source=%s resource=%s before=%d after=%d" % [source, resource_id, before, after])
	if resource_id == "coal":
		refresh_temperature_score("resource_set:%s" % resource_id)
	resources_changed.emit()
	state_changed.emit()


func add_resource(resource_id: String, amount: int, source: String) -> void:
	add_resource_with_refresh(resource_id, amount, source, true)


func add_resource_with_refresh(resource_id: String, amount: int, source: String, refresh_temperature: bool) -> void:
	var before: int = get_resource_amount(resource_id)
	var after: int = _clamp_resource(resource_id, before + amount)
	resources[resource_id] = after
	print("[GameState] add_resource source=%s resource=%s amount=%d before=%d after=%d" % [source, resource_id, amount, before, after])
	if refresh_temperature and resource_id == "coal":
		refresh_temperature_score("resource_changed:%s" % resource_id)
	resources_changed.emit()
	state_changed.emit()


func set_furnace_level(level: int, source: String) -> void:
	var before: int = furnace_level
	var max_level: int = BuildingManager.get_furnace_max_level()
	furnace_level = int(clamp(level, DEFAULT_FURNACE_LEVEL, max_level))
	print("[GameState] set_furnace_level source=%s before=%d after=%d" % [source, before, furnace_level])
	refresh_temperature_score("furnace_level_changed")
	state_changed.emit()
	quest_relevant_state_changed.emit()


func transfer_population(from_state: String, to_state: String, amount: int, source: String) -> int:
	var before_from: int = int(population.get(from_state, 0))
	var before_to: int = int(population.get(to_state, 0))
	var actual_amount: int = min(max(amount, 0), before_from)
	if actual_amount <= 0:
		print("[GameState] transfer_population source=%s from=%s to=%s requested=%d actual=0 before_from=%d before_to=%d" % [
			source,
			from_state,
			to_state,
			amount,
			before_from,
			before_to
		])
		return 0

	population[from_state] = before_from - actual_amount
	population[to_state] = before_to + actual_amount
	print("[GameState] transfer_population source=%s from=%s to=%s requested=%d actual=%d before_from=%d after_from=%d before_to=%d after_to=%d" % [
		source,
		from_state,
		to_state,
		amount,
		actual_amount,
		before_from,
		int(population.get(from_state, 0)),
		before_to,
		int(population.get(to_state, 0))
	])
	_clamp_job_assignments_to_population(source)
	refresh_shelter_status("population_changed:%s" % source)
	state_changed.emit()
	return actual_amount


func advance_day(source: String) -> void:
	var before: int = day
	day += 1
	phase = "day"
	_reset_daily_flags(source)
	print("[GameState] advance_day source=%s before=%d after=%d phase=%s" % [source, before, day, phase])
	_update_building_unlocks_for_day(source)
	state_changed.emit()
	quest_relevant_state_changed.emit()


func mark_resource_collected(resource_id: String, source: String) -> void:
	var before: bool = bool(collected_resources.get(resource_id, false))
	collected_resources[resource_id] = true
	print("[GameState] mark_resource_collected source=%s resource=%s before=%s after=true" % [
		source,
		resource_id,
		str(before)
	])
	quest_relevant_state_changed.emit()
	state_changed.emit()


func was_resource_collected(resource_id: String) -> bool:
	return bool(collected_resources.get(resource_id, false))


func build_building(building_id: String, source: String) -> bool:
	var state: Dictionary = _get_or_create_building_state(building_id)
	var was_built: bool = bool(state.get("is_built", false))
	state["is_unlocked"] = true
	state["is_built"] = true
	state["current_level"] = max(1, int(state.get("current_level", 0)))
	buildings[building_id] = state
	if building_id == "furnace":
		set_furnace_level(int(state.get("current_level", DEFAULT_FURNACE_LEVEL)), source)
	print("[GameState] build_building source=%s building=%s before_built=%s after_built=true" % [
		source,
		building_id,
		str(was_built)
	])
	quest_relevant_state_changed.emit()
	state_changed.emit()
	return not was_built


func unlock_building(building_id: String, source: String) -> bool:
	var state: Dictionary = _get_or_create_building_state(building_id)
	var was_unlocked: bool = bool(state.get("is_unlocked", false))
	state["is_unlocked"] = true
	buildings[building_id] = state
	print("[GameState] unlock_building source=%s building=%s before_unlocked=%s after_unlocked=true" % [
		source,
		building_id,
		str(was_unlocked)
	])
	quest_relevant_state_changed.emit()
	state_changed.emit()
	return not was_unlocked


func is_building_built(building_id: String) -> bool:
	var state: Dictionary = buildings.get(building_id, {}) as Dictionary
	return bool(state.get("is_built", false))


func is_building_unlocked(building_id: String) -> bool:
	var state: Dictionary = buildings.get(building_id, {}) as Dictionary
	return bool(state.get("is_unlocked", false))


func get_building_level(building_id: String) -> int:
	var state: Dictionary = buildings.get(building_id, {}) as Dictionary
	return int(state.get("current_level", 0))


func set_building_level(building_id: String, level: int, source: String) -> bool:
	var state: Dictionary = _get_or_create_building_state(building_id)
	var before_level: int = int(state.get("current_level", 0))
	var config: Dictionary = DataLoader.get_building_config(building_id)
	var max_level: int = int(config.get("max_level", 1))
	var after_level: int = int(clamp(level, 0, max_level))
	state["current_level"] = after_level
	state["is_built"] = after_level > 0
	if after_level > 0:
		state["is_unlocked"] = true
	buildings[building_id] = state
	if building_id == "furnace":
		set_furnace_level(after_level, source)
	print("[GameState] set_building_level source=%s building=%s before=%d after=%d" % [
		source,
		building_id,
		before_level,
		after_level
	])
	quest_relevant_state_changed.emit()
	state_changed.emit()
	return before_level != after_level


func was_building_upgraded_today() -> bool:
	return bool(daily_flags.get("building_upgraded", false))


func mark_building_upgraded(source: String) -> void:
	var before: bool = was_building_upgraded_today()
	daily_flags["building_upgraded"] = true
	print("[GameState] mark_building_upgraded source=%s before=%s after=true" % [
		source,
		str(before)
	])
	state_changed.emit()


func set_job_assignment(job_id: String, amount: int, source: String) -> bool:
	var before: int = get_job_assignment(job_id)
	var max_assignable: int = get_assignable_population()
	var other_assigned: int = assigned_jobs_total - before
	var allowed_amount: int = max_assignable - other_assigned
	var after: int = int(clamp(amount, 0, max(allowed_amount, 0)))
	if not job_assignments.has(job_id):
		print("[GameState] set_job_assignment failed source=%s job=%s reason=unknown_job" % [source, job_id])
		return false

	job_assignments[job_id] = after
	_refresh_assigned_jobs_total()
	print("[GameState] set_job_assignment source=%s job=%s before=%d requested=%d after=%d max_assignable=%d total=%d" % [
		source,
		job_id,
		before,
		amount,
		after,
		max_assignable,
		assigned_jobs_total
	])
	quest_relevant_state_changed.emit()
	state_changed.emit()
	return after != before


func add_job_assignment(job_id: String, delta: int, source: String) -> bool:
	var before: int = get_job_assignment(job_id)
	return set_job_assignment(job_id, before + delta, source)


func get_job_assignment(job_id: String) -> int:
	return int(job_assignments.get(job_id, 0))


func get_job_assignments() -> Dictionary:
	return job_assignments.duplicate(true)


func get_assignable_population() -> int:
	var healthy: int = int(population.get("healthy", 0))
	var light_wound: int = int(population.get("light_wound", 0))
	return healthy + light_wound


func get_unassigned_population() -> int:
	return max(get_assignable_population() - assigned_jobs_total, 0)


func assign_jobs_total(amount: int, source: String) -> void:
	var before: int = assigned_jobs_total
	var max_assignable: int = get_assignable_population()
	_clear_job_assignments()
	var remaining: int = int(clamp(amount, 0, max_assignable))
	var job_order: Array[String] = DataLoader.get_job_order()
	for job_id: String in job_order:
		if remaining <= 0:
			break
		job_assignments[job_id] = int(job_assignments.get(job_id, 0)) + 1
		remaining -= 1
	_refresh_assigned_jobs_total()
	print("[GameState] assign_jobs_total source=%s before=%d requested=%d after=%d max=%d assignments=%s" % [
		source,
		before,
		amount,
		assigned_jobs_total,
		max_assignable,
		str(job_assignments)
	])
	quest_relevant_state_changed.emit()
	state_changed.emit()


func send_first_scout_team(source: String) -> bool:
	var before: bool = bool(scout_state.get("first_scout_team_sent", false))
	scout_state["first_scout_team_sent"] = true
	print("[GameState] send_first_scout_team source=%s before=%s after=true" % [
		source,
		str(before)
	])
	quest_relevant_state_changed.emit()
	state_changed.emit()
	return not before


func was_first_scout_team_sent() -> bool:
	return bool(scout_state.get("first_scout_team_sent", false))


func scout_region(region_id: String, source: String) -> bool:
	var state: Dictionary = regions.get(region_id, {}) as Dictionary
	if state.is_empty():
		state = {
			"is_scouted": false
		}
	var before: bool = bool(state.get("is_scouted", false))
	state["is_scouted"] = true
	regions[region_id] = state
	print("[GameState] scout_region source=%s region=%s before=%s after=true" % [
		source,
		region_id,
		str(before)
	])
	quest_relevant_state_changed.emit()
	state_changed.emit()
	return not before


func is_region_scouted(region_id: String) -> bool:
	var state: Dictionary = regions.get(region_id, {}) as Dictionary
	return bool(state.get("is_scouted", false))


func initialize_quest_state(first_quest_id: String) -> void:
	quests = {
		"current_quest_id": first_quest_id,
		"completed": {},
		"rewarded": {}
	}
	print("[GameState] initialize_quest_state current=%s" % first_quest_id)
	quest_relevant_state_changed.emit()
	state_changed.emit()


func get_current_quest_id() -> String:
	return str(quests.get("current_quest_id", ""))


func set_current_quest_id(quest_id: String, source: String) -> void:
	var before: String = get_current_quest_id()
	quests["current_quest_id"] = quest_id
	print("[GameState] set_current_quest_id source=%s before=%s after=%s" % [
		source,
		before,
		quest_id
	])
	quest_relevant_state_changed.emit()
	state_changed.emit()


func mark_quest_completed(quest_id: String, source: String) -> void:
	var completed: Dictionary = quests.get("completed", {}) as Dictionary
	completed[quest_id] = true
	quests["completed"] = completed
	print("[GameState] mark_quest_completed source=%s quest=%s" % [source, quest_id])
	quest_relevant_state_changed.emit()
	state_changed.emit()


func is_quest_completed(quest_id: String) -> bool:
	var completed: Dictionary = quests.get("completed", {}) as Dictionary
	return bool(completed.get(quest_id, false))


func mark_quest_rewarded(quest_id: String, source: String) -> void:
	var rewarded: Dictionary = quests.get("rewarded", {}) as Dictionary
	rewarded[quest_id] = true
	quests["rewarded"] = rewarded
	print("[GameState] mark_quest_rewarded source=%s quest=%s" % [source, quest_id])
	quest_relevant_state_changed.emit()
	state_changed.emit()


func is_quest_rewarded(quest_id: String) -> bool:
	var rewarded: Dictionary = quests.get("rewarded", {}) as Dictionary
	return bool(rewarded.get(quest_id, false))


func refresh_temperature_score(source: String = "manual") -> void:
	var before: int = temperature_score
	var coal_amount: int = get_resource_amount("coal")
	var calculated: float = float(furnace_level * 20) + float(min(coal_amount, 50)) * 0.2 - weather_pressure
	temperature_score = int(round(calculated))
	print("[GameState] refresh_temperature_score source=%s furnace_level=%d coal=%d weather_pressure=%.1f before=%d after=%d status=%s" % [
		source,
		furnace_level,
		coal_amount,
		weather_pressure,
		before,
		temperature_score,
		get_temperature_status()
	])
	temperature_changed.emit()
	refresh_shelter_status("temperature_changed:%s" % source)


func get_temperature_status() -> String:
	if temperature_score >= 80:
		return "温暖"
	if temperature_score >= 50:
		return "可忍受"
	if temperature_score >= 20:
		return "寒冷"
	return "危险"


func get_alive_population() -> int:
	var healthy: int = int(population.get("healthy", 0))
	var light_wound: int = int(population.get("light_wound", 0))
	var heavy_wound: int = int(population.get("heavy_wound", 0))
	return healthy + light_wound + heavy_wound


func get_sick_population() -> int:
	var light_wound: int = int(population.get("light_wound", 0))
	var heavy_wound: int = int(population.get("heavy_wound", 0))
	return light_wound + heavy_wound


func get_healthy_population() -> int:
	return int(population.get("healthy", 0))


func add_morale(amount: int, source: String) -> int:
	var before: int = morale_score
	morale_score = int(clamp(morale_score + amount, 0, 100))
	var delta: int = morale_score - before
	print("[GameState] add_morale source=%s amount=%d before=%d after=%d delta=%d" % [
		source,
		amount,
		before,
		morale_score,
		delta
	])
	refresh_shelter_status("morale_changed:%s" % source)
	state_changed.emit()
	quest_relevant_state_changed.emit()
	return delta


func refresh_shelter_status(source: String = "manual") -> void:
	var before_health_status: String = health_status
	var before_status_text: String = shelter_status_text
	if get_sick_population() > 0:
		health_status = "sick"
	else:
		health_status = "healthy"

	shelter_status_text = _build_shelter_status_text()
	if before_health_status != health_status or before_status_text != shelter_status_text:
		print("[GameState] refresh_shelter_status source=%s health=%s->%s status=%s->%s morale=%d sick=%d temperature=%s" % [
			source,
			before_health_status,
			health_status,
			before_status_text,
			shelter_status_text,
			morale_score,
			get_sick_population(),
			get_temperature_status()
		])


func _build_initial_resources() -> Dictionary:
	var result: Dictionary = {}
	var configs: Dictionary = DataLoader.get_resource_configs()

	for resource_id_value: Variant in configs.keys():
		var resource_id: String = str(resource_id_value)
		var config: Dictionary = configs.get(resource_id, {}) as Dictionary
		result[resource_id] = int(config.get("initial_amount", 0))

	return result


func _build_initial_population() -> Dictionary:
	var counts: Dictionary = DataLoader.get_survivor_initial_counts()
	return {
		"healthy": int(counts.get("healthy", 0)),
		"light_wound": int(counts.get("light_wound", 0)),
		"heavy_wound": int(counts.get("heavy_wound", 0)),
		"dead": int(counts.get("dead", 0))
	}


func _build_initial_buildings() -> Dictionary:
	var result: Dictionary = {}
	var configs: Dictionary = DataLoader.get_building_configs()

	for building_id_value: Variant in configs.keys():
		var building_id: String = str(building_id_value)
		var config: Dictionary = configs.get(building_id, {}) as Dictionary
		var unlock_day: int = int(config.get("unlock_day", 1))
		var is_initial: bool = unlock_day <= day
		var current_level: int = 0
		var is_built: bool = false
		if INITIAL_BUILT_BUILDINGS.has(building_id):
			current_level = 1
			is_built = true
		result[building_id] = {
			"is_unlocked": is_initial,
			"is_built": is_built,
			"current_level": current_level
		}

	return result


func _build_initial_job_assignments() -> Dictionary:
	var result: Dictionary = {}
	var job_order: Array[String] = DataLoader.get_job_order()
	for job_id: String in job_order:
		result[job_id] = 0
	return result


func _build_initial_scout_state() -> Dictionary:
	return {
		"first_scout_team_sent": false
	}


func _build_initial_regions() -> Dictionary:
	return {
		FIRST_SCOUT_REGION_ID: {
			"is_scouted": false
		}
	}


func _build_initial_quests() -> Dictionary:
	var quest_order: Array[String] = DataLoader.get_quest_order()
	var first_quest_id: String = ""
	if not quest_order.is_empty():
		first_quest_id = quest_order[0]
	return {
		"current_quest_id": first_quest_id,
		"completed": {},
		"rewarded": {}
	}


func _build_initial_daily_flags() -> Dictionary:
	return {
		"building_upgraded": false
	}


func _reset_daily_flags(source: String) -> void:
	daily_flags = _build_initial_daily_flags()
	print("[GameState] reset_daily_flags source=%s flags=%s" % [source, str(daily_flags)])


func _get_or_create_building_state(building_id: String) -> Dictionary:
	var state: Dictionary = buildings.get(building_id, {}) as Dictionary
	if state.is_empty():
		state = {
			"is_unlocked": false,
			"is_built": false,
			"current_level": 0
		}
	return state


func _build_shelter_status_text() -> String:
	if get_temperature_status() == "危险":
		return "寒炉供暖危险"
	if morale_score <= 25:
		return "营地士气低落"
	if get_sick_population() > 0:
		return "有人需要治疗"
	if morale_score >= 75:
		return "营地运转稳定"
	return "营地维持中"


func _update_building_unlocks_for_day(source: String) -> void:
	var configs: Dictionary = DataLoader.get_building_configs()
	var changed: bool = false

	for building_id_value: Variant in configs.keys():
		var building_id: String = str(building_id_value)
		var config: Dictionary = configs.get(building_id, {}) as Dictionary
		var unlock_day: int = int(config.get("unlock_day", 1))
		if day < unlock_day:
			continue

		var state: Dictionary = buildings.get(building_id, {}) as Dictionary
		if state.is_empty():
			state = {
				"is_unlocked": false,
				"is_built": false,
				"current_level": 0
			}
		if bool(state.get("is_unlocked", false)):
			continue

		state["is_unlocked"] = true
		buildings[building_id] = state
		changed = true
		print("[GameState] unlock_building_by_day source=%s building=%s unlock_day=%d current_day=%d" % [
			source,
			building_id,
			unlock_day,
			day
		])

	if changed:
		quest_relevant_state_changed.emit()


func _clamp_resource(resource_id: String, amount: int) -> int:
	var config: Dictionary = DataLoader.get_resource_config(resource_id)
	var min_amount: int = int(config.get("min_amount", 0))
	var result: int = max(amount, min_amount)
	var max_value: Variant = config.get("max_amount", null)
	if max_value != null:
		var max_amount: int = int(max_value)
		result = min(result, max_amount)
	return result


func _clear_job_assignments() -> void:
	for job_id_value: Variant in job_assignments.keys():
		var job_id: String = str(job_id_value)
		job_assignments[job_id] = 0


func _refresh_assigned_jobs_total() -> void:
	var total: int = 0
	for job_id_value: Variant in job_assignments.keys():
		var job_id: String = str(job_id_value)
		total += int(job_assignments.get(job_id, 0))
	assigned_jobs_total = total


func _clamp_job_assignments_to_population(source: String) -> void:
	var max_assignable: int = get_assignable_population()
	_refresh_assigned_jobs_total()
	if assigned_jobs_total <= max_assignable:
		return

	var overflow: int = assigned_jobs_total - max_assignable
	var job_order: Array[String] = DataLoader.get_job_order()
	for index: int in range(job_order.size() - 1, -1, -1):
		if overflow <= 0:
			break
		var job_id: String = job_order[index]
		var current: int = int(job_assignments.get(job_id, 0))
		if current <= 0:
			continue
		var removed: int = min(current, overflow)
		job_assignments[job_id] = current - removed
		overflow -= removed

	_refresh_assigned_jobs_total()
	print("[GameState] clamp_job_assignments source=%s max_assignable=%d total=%d assignments=%s" % [
		source,
		max_assignable,
		assigned_jobs_total,
		str(job_assignments)
	])
