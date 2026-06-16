extends Node

const RESOURCES_PATH: String = "res://data/resources.json"
const SURVIVORS_PATH: String = "res://data/survivors.json"
const JOBS_PATH: String = "res://data/jobs.json"
const BUILDINGS_PATH: String = "res://data/buildings.json"
const QUESTS_PATH: String = "res://data/quests.json"
const REGIONS_PATH: String = "res://data/regions.json"

var resource_configs: Dictionary = {}
var resource_order: Array[String] = []
var survivor_config: Dictionary = {}
var job_configs: Dictionary = {}
var job_order: Array[String] = []
var building_configs: Dictionary = {}
var building_order: Array[String] = []
var quest_configs: Dictionary = {}
var quest_order: Array[String] = []
var region_configs: Dictionary = {}


func _ready() -> void:
	load_all()


func load_all() -> void:
	resource_configs = _load_resource_configs()
	survivor_config = _load_survivor_config()
	job_configs = _load_job_configs()
	building_configs = _load_building_configs()
	quest_configs = _load_quest_configs()
	region_configs = _load_region_configs()
	print("[DataLoader] load_all resources=%d survivor_config=%s jobs=%d buildings=%d quests=%d" % [
		resource_configs.size(),
		str(not survivor_config.is_empty()),
		job_configs.size(),
		building_configs.size(),
		quest_configs.size()
	])


func get_resource_configs() -> Dictionary:
	return resource_configs.duplicate(true)


func get_resource_order() -> Array[String]:
	return resource_order.duplicate()


func get_resource_config(resource_id: String) -> Dictionary:
	var config: Dictionary = resource_configs.get(resource_id, {}) as Dictionary
	return config.duplicate(true)


func get_survivor_initial_counts() -> Dictionary:
	var counts: Dictionary = survivor_config.get("initial_counts", {}) as Dictionary
	return counts.duplicate(true)


func get_wounded_output_modifier() -> float:
	return float(survivor_config.get("wounded_output_modifier", 0.5))


func get_job_configs() -> Dictionary:
	return job_configs.duplicate(true)


func get_job_order() -> Array[String]:
	return job_order.duplicate()


func get_job_config(job_id: String) -> Dictionary:
	var config: Dictionary = job_configs.get(job_id, {}) as Dictionary
	return config.duplicate(true)


func get_building_configs() -> Dictionary:
	return building_configs.duplicate(true)


func get_building_order() -> Array[String]:
	return building_order.duplicate()


func get_building_config(building_id: String) -> Dictionary:
	var config: Dictionary = building_configs.get(building_id, {}) as Dictionary
	return config.duplicate(true)


func get_quest_configs() -> Dictionary:
	return quest_configs.duplicate(true)


func get_quest_order() -> Array[String]:
	return quest_order.duplicate()


func get_quest_config(quest_id: String) -> Dictionary:
	var config: Dictionary = quest_configs.get(quest_id, {}) as Dictionary
	return config.duplicate(true)


func get_region_config(region_id: String) -> Dictionary:
	var config: Dictionary = region_configs.get(region_id, {}) as Dictionary
	return config.duplicate(true)


func get_region_configs() -> Dictionary:
	return region_configs.duplicate(true)


func _load_resource_configs() -> Dictionary:
	resource_order.clear()
	var data: Dictionary = _load_json_dictionary(RESOURCES_PATH)
	var items: Array = data.get("items", []) as Array
	var result: Dictionary = {}

	for item_value: Variant in items:
		if typeof(item_value) != TYPE_DICTIONARY:
			push_error("[DataLoader] resources item is not dictionary")
			continue

		var item: Dictionary = item_value as Dictionary
		var resource_id: String = str(item.get("id", ""))
		if resource_id.is_empty():
			push_error("[DataLoader] resources item missing id")
			continue
		if result.has(resource_id):
			push_error("[DataLoader] duplicated resource id=%s" % resource_id)
			continue

		result[resource_id] = item.duplicate(true)
		resource_order.append(resource_id)

	print("[DataLoader] load_resources count=%d order=%s" % [result.size(), str(resource_order)])
	return result


func _load_survivor_config() -> Dictionary:
	var data: Dictionary = _load_json_dictionary(SURVIVORS_PATH)
	var counts: Dictionary = data.get("initial_counts", {}) as Dictionary
	var required_states: Array[String] = ["healthy", "light_wound", "heavy_wound", "dead"]

	for state_id: String in required_states:
		if not counts.has(state_id):
			push_error("[DataLoader] survivors initial_counts missing %s" % state_id)

	print("[DataLoader] load_survivors counts=%s" % str(counts))
	return data


func _load_job_configs() -> Dictionary:
	job_order.clear()
	var data: Dictionary = _load_json_dictionary(JOBS_PATH)
	var items: Array = data.get("items", []) as Array
	var result: Dictionary = {}

	for item_value: Variant in items:
		if typeof(item_value) != TYPE_DICTIONARY:
			push_error("[DataLoader] jobs item is not dictionary")
			continue

		var item: Dictionary = item_value as Dictionary
		var job_id: String = str(item.get("id", ""))
		if job_id.is_empty():
			push_error("[DataLoader] jobs item missing id")
			continue
		if result.has(job_id):
			push_error("[DataLoader] duplicated job id=%s" % job_id)
			continue

		result[job_id] = item.duplicate(true)
		job_order.append(job_id)

	print("[DataLoader] load_jobs count=%d order=%s" % [result.size(), str(job_order)])
	return result


func _load_building_configs() -> Dictionary:
	building_order.clear()
	var data: Dictionary = _load_json_dictionary(BUILDINGS_PATH)
	var items: Array = data.get("items", []) as Array
	var result: Dictionary = {}

	for item_value: Variant in items:
		if typeof(item_value) != TYPE_DICTIONARY:
			push_error("[DataLoader] buildings item is not dictionary")
			continue

		var item: Dictionary = item_value as Dictionary
		var building_id: String = str(item.get("id", ""))
		if building_id.is_empty():
			push_error("[DataLoader] buildings item missing id")
			continue
		if result.has(building_id):
			push_error("[DataLoader] duplicated building id=%s" % building_id)
			continue

		result[building_id] = item.duplicate(true)
		building_order.append(building_id)

	print("[DataLoader] load_buildings count=%d order=%s" % [result.size(), str(building_order)])
	return result


func _load_quest_configs() -> Dictionary:
	quest_order.clear()
	var data: Dictionary = _load_json_dictionary(QUESTS_PATH)
	var items: Array = data.get("items", []) as Array
	var result: Dictionary = {}

	for item_value: Variant in items:
		if typeof(item_value) != TYPE_DICTIONARY:
			push_error("[DataLoader] quests item is not dictionary")
			continue

		var item: Dictionary = item_value as Dictionary
		var quest_id: String = str(item.get("id", ""))
		if quest_id.is_empty():
			push_error("[DataLoader] quests item missing id")
			continue
		if result.has(quest_id):
			push_error("[DataLoader] duplicated quest id=%s" % quest_id)
			continue

		result[quest_id] = item.duplicate(true)
		quest_order.append(quest_id)

	print("[DataLoader] load_quests count=%d order=%s" % [result.size(), str(quest_order)])
	return result


func _load_region_configs() -> Dictionary:
	var data: Dictionary = _load_json_dictionary(REGIONS_PATH)
	var items: Array = data.get("items", []) as Array
	var result: Dictionary = {}

	for item_value: Variant in items:
		if typeof(item_value) != TYPE_DICTIONARY:
			push_error("[DataLoader] regions item is not dictionary")
			continue

		var item: Dictionary = item_value as Dictionary
		var region_id: String = str(item.get("id", ""))
		if region_id.is_empty():
			push_error("[DataLoader] regions item missing id")
			continue
		if result.has(region_id):
			push_error("[DataLoader] duplicated region id=%s" % region_id)
			continue

		result[region_id] = item.duplicate(true)

	print("[DataLoader] load_regions count=%d" % result.size())
	return result


func _load_json_dictionary(path: String) -> Dictionary:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("[DataLoader] failed to open %s" % path)
		return {}

	var text: String = file.get_as_text()
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("[DataLoader] failed to parse dictionary %s" % path)
		return {}

	var data: Dictionary = parsed as Dictionary
	return data
