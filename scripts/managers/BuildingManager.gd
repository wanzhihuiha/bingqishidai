extends Node

const FURNACE_ID: String = "furnace"
const CHECKED_UPGRADE_RESOURCES: Array[String] = ["wood", "coal", "parts"]


func get_furnace_config() -> Dictionary:
	return DataLoader.get_building_config(FURNACE_ID)


func get_furnace_max_level() -> int:
	var config: Dictionary = get_furnace_config()
	return int(config.get("max_level", 1))


func get_furnace_current_level_config() -> Dictionary:
	return get_furnace_level_config(GameState.furnace_level)


func get_furnace_next_level_config() -> Dictionary:
	return get_furnace_level_config(GameState.furnace_level + 1)


func get_furnace_level_config(level: int) -> Dictionary:
	var config: Dictionary = get_furnace_config()
	var levels: Array = config.get("levels", []) as Array

	for level_value: Variant in levels:
		if typeof(level_value) != TYPE_DICTIONARY:
			continue
		var level_config: Dictionary = level_value as Dictionary
		if int(level_config.get("level", 0)) == level:
			return level_config.duplicate(true)

	return {}


func get_furnace_upgrade_cost() -> Dictionary:
	var next_level: Dictionary = get_furnace_next_level_config()
	var cost: Dictionary = next_level.get("cost", {}) as Dictionary
	return cost.duplicate(true)


func get_furnace_upgrade_cost_text() -> String:
	if GameState.furnace_level >= get_furnace_max_level():
		return "已达到最高等级"

	var cost: Dictionary = get_furnace_upgrade_cost()
	if cost.is_empty():
		return "无需资源"

	var parts: PackedStringArray = PackedStringArray()
	for resource_id: String in CHECKED_UPGRADE_RESOURCES:
		var amount: int = int(cost.get(resource_id, 0))
		if amount <= 0:
			continue
		var resource_name: String = GameState.get_resource_name(resource_id)
		parts.append("%s %d" % [resource_name, amount])

	return "、".join(parts)


func get_furnace_missing_resources() -> Dictionary:
	var cost: Dictionary = get_furnace_upgrade_cost()
	var missing: Dictionary = {}

	for resource_id: String in CHECKED_UPGRADE_RESOURCES:
		var need_amount: int = int(cost.get(resource_id, 0))
		if need_amount <= 0:
			continue
		var current_amount: int = GameState.get_resource_amount(resource_id)
		if current_amount < need_amount:
			missing[resource_id] = need_amount - current_amount

	return missing


func get_missing_resources_text(missing: Dictionary) -> String:
	if missing.is_empty():
		return ""

	var parts: PackedStringArray = PackedStringArray()
	for resource_id: String in CHECKED_UPGRADE_RESOURCES:
		if not missing.has(resource_id):
			continue
		var resource_name: String = GameState.get_resource_name(resource_id)
		var amount: int = int(missing.get(resource_id, 0))
		parts.append("%s %d" % [resource_name, amount])

	return "缺少：" + "、".join(parts)


func upgrade_furnace() -> Dictionary:
	GameState.ensure_started()
	var current_level: int = GameState.furnace_level
	var max_level: int = get_furnace_max_level()
	if current_level >= max_level:
		print("[BuildingManager] upgrade_furnace failed reason=max_level current_level=%d" % current_level)
		return {
			"success": false,
			"message": "寒炉已达到最高等级"
		}

	var missing: Dictionary = get_furnace_missing_resources()
	if not missing.is_empty():
		var missing_text: String = get_missing_resources_text(missing)
		print("[BuildingManager] upgrade_furnace failed reason=missing_resources level=%d missing=%s" % [
			current_level,
			str(missing)
		])
		return {
			"success": false,
			"message": missing_text,
			"missing": missing
		}

	var cost: Dictionary = get_furnace_upgrade_cost()
	for resource_id: String in CHECKED_UPGRADE_RESOURCES:
		var amount: int = int(cost.get(resource_id, 0))
		if amount <= 0:
			continue
		GameState.add_resource(resource_id, -amount, "upgrade_furnace")

	var next_level: int = current_level + 1
	GameState.set_furnace_level(next_level, "upgrade_furnace")
	print("[BuildingManager] upgrade_furnace success before_level=%d after_level=%d cost=%s temperature_score=%d" % [
		current_level,
		next_level,
		str(cost),
		GameState.temperature_score
	])
	return {
		"success": true,
		"message": "寒炉已升级到 %d 级" % next_level,
		"level": next_level
	}


func build_building(building_id: String) -> Dictionary:
	GameState.ensure_started()
	var config: Dictionary = DataLoader.get_building_config(building_id)
	if config.is_empty():
		print("[BuildingManager] build_building failed reason=missing_config building=%s" % building_id)
		return {
			"success": false,
			"message": "建筑数据缺失"
		}

	var building_name: String = str(config.get("name", building_id))
	if GameState.is_building_built(building_id):
		print("[BuildingManager] build_building failed reason=already_built building=%s" % building_id)
		return {
			"success": false,
			"message": "%s 已建造" % building_name
		}

	var unlock_day: int = int(config.get("unlock_day", 1))
	if GameState.day < unlock_day:
		print("[BuildingManager] build_building failed reason=locked building=%s day=%d unlock_day=%d" % [
			building_id,
			GameState.day,
			unlock_day
		])
		return {
			"success": false,
			"message": "%s 尚未解锁" % building_name
		}

	var levels: Array = config.get("levels", []) as Array
	var first_level: Dictionary = {}
	if not levels.is_empty() and typeof(levels[0]) == TYPE_DICTIONARY:
		first_level = levels[0] as Dictionary
	var cost: Dictionary = first_level.get("cost", {}) as Dictionary
	var missing: Dictionary = _get_missing_resources(cost)
	if not missing.is_empty():
		var missing_text: String = _get_missing_resources_text(missing)
		print("[BuildingManager] build_building failed reason=missing_resources building=%s missing=%s" % [
			building_id,
			str(missing)
		])
		return {
			"success": false,
			"message": missing_text,
			"missing": missing
		}

	for resource_id_value: Variant in cost.keys():
		var resource_id: String = str(resource_id_value)
		var amount: int = int(cost.get(resource_id, 0))
		if amount <= 0:
			continue
		GameState.add_resource(resource_id, -amount, "build_building:%s" % building_id)

	GameState.build_building(building_id, "build_building")
	print("[BuildingManager] build_building success building=%s cost=%s" % [building_id, str(cost)])
	return {
		"success": true,
		"message": "%s 已建造" % building_name
	}


func _get_missing_resources(cost: Dictionary) -> Dictionary:
	var missing: Dictionary = {}
	for resource_id_value: Variant in cost.keys():
		var resource_id: String = str(resource_id_value)
		var need_amount: int = int(cost.get(resource_id, 0))
		if need_amount <= 0:
			continue
		var current_amount: int = GameState.get_resource_amount(resource_id)
		if current_amount < need_amount:
			missing[resource_id] = need_amount - current_amount
	return missing


func _get_missing_resources_text(missing: Dictionary) -> String:
	if missing.is_empty():
		return ""

	var parts: PackedStringArray = PackedStringArray()
	for resource_id_value: Variant in missing.keys():
		var resource_id: String = str(resource_id_value)
		var resource_name: String = GameState.get_resource_name(resource_id)
		var amount: int = int(missing.get(resource_id, 0))
		parts.append("%s %d" % [resource_name, amount])

	return "缺少：" + "、".join(parts)
