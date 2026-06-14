extends Node

signal state_changed
signal resources_changed
signal temperature_changed

const DEFAULT_FURNACE_LEVEL: int = 1
const DEFAULT_WEATHER_PRESSURE: float = 0.0

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
var temperature_score: int = 0
var weather_pressure: float = DEFAULT_WEATHER_PRESSURE
var is_started: bool = false


func start_new_game() -> void:
	day = 1
	phase = "day"
	resources = _build_initial_resources()
	population = _build_initial_population()
	furnace_level = DEFAULT_FURNACE_LEVEL
	weather_pressure = DEFAULT_WEATHER_PRESSURE
	refresh_temperature_score("start_new_game")
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
	var before: int = get_resource_amount(resource_id)
	var after: int = _clamp_resource(resource_id, before + amount)
	resources[resource_id] = after
	print("[GameState] add_resource source=%s resource=%s amount=%d before=%d after=%d" % [source, resource_id, amount, before, after])
	if resource_id == "coal":
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
