extends Node

const FURNACE_ID: String = "furnace"
const WORKSHOP_ID: String = "workshop"


func get_furnace_config() -> Dictionary:
	return DataLoader.get_building_config(FURNACE_ID)


func get_furnace_max_level() -> int:
	return get_building_max_level(FURNACE_ID)


func get_furnace_current_level_config() -> Dictionary:
	return get_building_level_config(FURNACE_ID, GameState.furnace_level)


func get_furnace_next_level_config() -> Dictionary:
	return get_building_level_config(FURNACE_ID, GameState.furnace_level + 1)


func get_furnace_level_config(level: int) -> Dictionary:
	return get_building_level_config(FURNACE_ID, level)


func get_furnace_upgrade_cost() -> Dictionary:
	return get_next_building_cost(FURNACE_ID)


func get_furnace_upgrade_cost_text() -> String:
	return get_next_cost_text(FURNACE_ID)


func get_furnace_missing_resources() -> Dictionary:
	return get_missing_resources(get_furnace_upgrade_cost())


func get_missing_resources_text(missing: Dictionary) -> String:
	return _get_missing_resources_text(missing)


func upgrade_furnace() -> Dictionary:
	return upgrade_building(FURNACE_ID)


func build_building(building_id: String) -> Dictionary:
	return upgrade_building(building_id)


func upgrade_building(building_id: String) -> Dictionary:
	GameState.ensure_started()
	var config: Dictionary = DataLoader.get_building_config(building_id)
	if config.is_empty():
		print("[BuildingManager] upgrade_building failed reason=missing_config building=%s" % building_id)
		return {
			"success": false,
			"message": "建筑数据缺失"
		}

	var building_name: String = str(config.get("name", building_id))
	var current_level: int = GameState.get_building_level(building_id)
	var max_level: int = get_building_max_level(building_id)
	if current_level >= max_level:
		print("[BuildingManager] upgrade_building failed reason=max_level building=%s current_level=%d" % [
			building_id,
			current_level
		])
		return {
			"success": false,
			"message": "%s 已达到最高等级" % building_name
		}

	if not GameState.is_building_unlocked(building_id):
		var locked_reason: String = get_unlock_reason_text(building_id)
		print("[BuildingManager] upgrade_building failed reason=locked building=%s reason=%s" % [
			building_id,
			locked_reason
		])
		return {
			"success": false,
			"message": locked_reason
		}

	if GameState.was_building_upgraded_today():
		print("[BuildingManager] upgrade_building failed reason=daily_limit building=%s" % building_id)
		return {
			"success": false,
			"message": "今天已经完成过一次建筑建设，明天再继续"
		}

	var next_level: int = current_level + 1
	var cost: Dictionary = get_building_cost_for_level(building_id, next_level)
	var missing: Dictionary = get_missing_resources(cost)
	if not missing.is_empty():
		var missing_text: String = _get_missing_resources_text(missing)
		print("[BuildingManager] upgrade_building failed reason=missing_resources building=%s next_level=%d missing=%s" % [
			building_id,
			next_level,
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
		GameState.add_resource(resource_id, -amount, "building_action:%s" % building_id)

	GameState.set_building_level(building_id, next_level, "building_action")
	GameState.mark_building_upgraded("building_action:%s" % building_id)
	GameState.refresh_shelter_status("building_action:%s" % building_id)
	var action_text: String = "建造"
	if current_level > 0:
		action_text = "升级"
	print("[BuildingManager] upgrade_building success building=%s before=%d after=%d cost=%s" % [
		building_id,
		current_level,
		next_level,
		str(cost)
	])
	return {
		"success": true,
		"message": "%s已%s到 %d 级" % [building_name, action_text, next_level],
		"building_id": building_id,
		"level": next_level,
		"unlocks": get_building_unlocked_features(building_id)
	}


func get_building_max_level(building_id: String) -> int:
	var config: Dictionary = DataLoader.get_building_config(building_id)
	return int(config.get("max_level", 1))


func get_building_level_config(building_id: String, level: int) -> Dictionary:
	var config: Dictionary = DataLoader.get_building_config(building_id)
	var levels: Array = config.get("levels", []) as Array
	for level_value: Variant in levels:
		if typeof(level_value) != TYPE_DICTIONARY:
			continue
		var level_config: Dictionary = level_value as Dictionary
		if int(level_config.get("level", 0)) == level:
			return level_config.duplicate(true)
	return {}


func get_next_level_config(building_id: String) -> Dictionary:
	return get_building_level_config(building_id, GameState.get_building_level(building_id) + 1)


func get_current_level_config(building_id: String) -> Dictionary:
	return get_building_level_config(building_id, GameState.get_building_level(building_id))


func get_building_cost_for_level(building_id: String, level: int) -> Dictionary:
	var level_config: Dictionary = get_building_level_config(building_id, level)
	var raw_cost: Dictionary = level_config.get("cost", {}) as Dictionary
	return _apply_upgrade_discount(raw_cost, building_id)


func get_next_building_cost(building_id: String) -> Dictionary:
	return get_building_cost_for_level(building_id, GameState.get_building_level(building_id) + 1)


func get_next_cost_text(building_id: String) -> String:
	var current_level: int = GameState.get_building_level(building_id)
	if current_level >= get_building_max_level(building_id):
		return "已达到最高等级"

	var cost: Dictionary = get_next_building_cost(building_id)
	if cost.is_empty():
		return "无需资源"

	return _get_cost_text(cost)


func get_next_benefit_text(building_id: String) -> String:
	var current_level: int = GameState.get_building_level(building_id)
	if current_level >= get_building_max_level(building_id):
		return "已获得全部收益"

	var level_config: Dictionary = get_building_level_config(building_id, current_level + 1)
	return str(level_config.get("display_text", "提升建筑效果"))


func get_current_effect_text(building_id: String) -> String:
	var current_level: int = GameState.get_building_level(building_id)
	if current_level <= 0:
		return "尚未建造"
	var level_config: Dictionary = get_building_level_config(building_id, current_level)
	return str(level_config.get("display_text", "建筑正在发挥作用"))


func get_unlock_reason_text(building_id: String) -> String:
	var config: Dictionary = DataLoader.get_building_config(building_id)
	var building_name: String = str(config.get("name", building_id))
	var unlock_day: int = int(config.get("unlock_day", 1))
	if GameState.day < unlock_day:
		return "%s 尚未解锁：第 %d 天开放" % [building_name, unlock_day]
	return "%s 尚未解锁" % building_name


func get_building_action_label(building_id: String) -> String:
	var current_level: int = GameState.get_building_level(building_id)
	if current_level <= 0:
		return "建造"
	return "升级"


func can_show_feature_unlocked(feature_id: String) -> bool:
	match feature_id:
		"hero_squad":
			return GameState.get_building_level("training_ground") >= 1
		"map_outpost":
			return GameState.get_building_level("outpost") >= 1
		_:
			return false


func get_building_unlocked_features(building_id: String) -> Array[String]:
	var features: Array[String] = []
	if building_id == "training_ground" and GameState.get_building_level(building_id) >= 1:
		features.append("英雄小队入口已解锁")
	if building_id == "outpost" and GameState.get_building_level(building_id) >= 1:
		features.append("地图建前哨能力已解锁")
	return features


func get_level_production_value(building_id: String, key: String, default_value: Variant) -> Variant:
	var level_config: Dictionary = get_current_level_config(building_id)
	var production: Dictionary = level_config.get("production", {}) as Dictionary
	return production.get(key, default_value)


func get_missing_resources(cost: Dictionary) -> Dictionary:
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


func _apply_upgrade_discount(raw_cost: Dictionary, building_id: String) -> Dictionary:
	var discount: float = _get_workshop_upgrade_discount()
	var cost: Dictionary = {}
	for resource_id_value: Variant in raw_cost.keys():
		var resource_id: String = str(resource_id_value)
		var amount: int = int(raw_cost.get(resource_id, 0))
		if amount <= 0:
			continue
		if discount <= 0.0 or building_id == WORKSHOP_ID:
			cost[resource_id] = amount
		else:
			cost[resource_id] = max(int(ceil(float(amount) * (1.0 - discount))), 1)
	return cost


func _get_workshop_upgrade_discount() -> float:
	if GameState.get_building_level(WORKSHOP_ID) <= 0:
		return 0.0
	return float(get_level_production_value(WORKSHOP_ID, "upgrade_cost_discount", 0.0))


func _get_cost_text(cost: Dictionary) -> String:
	var parts: PackedStringArray = PackedStringArray()
	for resource_id_value: Variant in cost.keys():
		var resource_id: String = str(resource_id_value)
		var amount: int = int(cost.get(resource_id, 0))
		if amount <= 0:
			continue
		var resource_name: String = GameState.get_resource_name(resource_id)
		parts.append("%s %d" % [resource_name, amount])
	if parts.is_empty():
		return "无需资源"
	return "、".join(parts)


func _get_missing_resources_text(missing: Dictionary) -> String:
	if missing.is_empty():
		return ""
	return "缺少：" + _get_cost_text(missing)
