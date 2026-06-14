extends Node

const RESOURCES_PATH: String = "res://data/resources.json"
const SURVIVORS_PATH: String = "res://data/survivors.json"

var resource_configs: Dictionary = {}
var resource_order: Array[String] = []
var survivor_config: Dictionary = {}


func _ready() -> void:
	load_all()


func load_all() -> void:
	resource_configs = _load_resource_configs()
	survivor_config = _load_survivor_config()
	print("[DataLoader] load_all resources=%d survivor_config=%s" % [resource_configs.size(), str(not survivor_config.is_empty())])


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
