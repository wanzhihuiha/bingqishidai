extends Node

signal state_changed
signal resources_changed

const DEFAULT_TEMPERATURE_SCORE: int = 60
const DEFAULT_FURNACE_LEVEL: int = 1

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
var temperature_score: int = DEFAULT_TEMPERATURE_SCORE
var is_started: bool = false


func start_new_game() -> void:
	day = 1
	phase = "day"
	resources = _build_initial_resources()
	population = _build_initial_population()
	furnace_level = DEFAULT_FURNACE_LEVEL
	temperature_score = DEFAULT_TEMPERATURE_SCORE
	is_started = true
	print("[GameState] start_new_game day=%d phase=%s resources=%s population=%s furnace_level=%d temperature_score=%d" % [
		day,
		phase,
		str(resources),
		str(population),
		furnace_level,
		temperature_score
	])
	state_changed.emit()
	resources_changed.emit()


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


func get_resource_order() -> Array[String]:
	return DataLoader.get_resource_order()


func set_resource(resource_id: String, amount: int, source: String) -> void:
	var before: int = get_resource_amount(resource_id)
	var after: int = _clamp_resource(resource_id, amount)
	resources[resource_id] = after
	print("[GameState] set_resource source=%s resource=%s before=%d after=%d" % [source, resource_id, before, after])
	resources_changed.emit()
	state_changed.emit()


func add_resource(resource_id: String, amount: int, source: String) -> void:
	var before: int = get_resource_amount(resource_id)
	var after: int = _clamp_resource(resource_id, before + amount)
	resources[resource_id] = after
	print("[GameState] add_resource source=%s resource=%s amount=%d before=%d after=%d" % [source, resource_id, amount, before, after])
	resources_changed.emit()
	state_changed.emit()


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


func _clamp_resource(resource_id: String, amount: int) -> int:
	var config: Dictionary = DataLoader.get_resource_config(resource_id)
	var min_amount: int = int(config.get("min_amount", 0))
	var result: int = max(amount, min_amount)
	var max_value: Variant = config.get("max_amount", null)
	if max_value != null:
		var max_amount: int = int(max_value)
		result = min(result, max_amount)
	return result
