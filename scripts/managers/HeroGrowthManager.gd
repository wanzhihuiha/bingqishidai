extends Node

const MAX_LEVEL: int = 5
const BASE_EXP_SUCCESS: int = 4
const BATTLE_EXP_VICTORY: int = 6


# 作用：获取当前等级升到下一级所需经验。
# 参数：level 是当前等级。
# 返回：经验需求；满级时返回 0。
func get_exp_to_next_level(level: int) -> int:
	if level >= MAX_LEVEL:
		return 0
	return max(level, 1) * 10


# 作用：获取指定英雄当前等级到下一级的经验需求。
# 参数：hero_id 是英雄 id。
# 返回：经验需求；满级时返回 0。
func get_hero_exp_to_next_level(hero_id: String) -> int:
	return get_exp_to_next_level(GameState.get_hero_level(hero_id))


# 作用：根据英雄等级返回基础战力成长加成。
# 参数：hero_id 是英雄 id。
# 返回：等级带来的额外基础战力。
func get_level_power_bonus(hero_id: String) -> int:
	return max(GameState.get_hero_level(hero_id) - 1, 0)


# 作用：根据英雄等级返回主专长成长加成。
# 参数：hero_id 是英雄 id。
# 返回：主专长带来的额外加成。
func get_primary_specialty_bonus(hero_id: String) -> int:
	return max(GameState.get_hero_level(hero_id) - 1, 0)


# 作用：获取英雄当前装备配置。
# 参数：hero_id 是英雄 id。
# 返回：装备配置 Dictionary；未装备时返回空字典。
func get_equipped_item_config(hero_id: String) -> Dictionary:
	var equipment_id: String = GameState.get_hero_equipped_item_id(hero_id)
	if equipment_id.is_empty():
		return {}
	return DataLoader.get_equipment_config(equipment_id)


# 作用：获取英雄装备带来的战力加成。
# 参数：hero_id 是英雄 id。
# 返回：战力加成整数。
func get_equipment_power_bonus(hero_id: String) -> int:
	var config: Dictionary = get_equipped_item_config(hero_id)
	return int(config.get("power_bonus", 0))


# 作用：获取英雄装备带来的安全加成。
# 参数：hero_id 是英雄 id。
# 返回：安全加成整数。
func get_equipment_safety_bonus(hero_id: String) -> int:
	var config: Dictionary = get_equipped_item_config(hero_id)
	return int(config.get("safety_bonus", 0))


# 作用：获取英雄装备带来的采集倍率加成。
# 参数：hero_id 是英雄 id。
# 返回：采集倍率浮点数。
func get_equipment_gather_reward_multiplier(hero_id: String) -> float:
	var config: Dictionary = get_equipped_item_config(hero_id)
	return float(config.get("gather_reward_multiplier", 0.0))


# 作用：获取英雄装备带来的修复加成。
# 参数：hero_id 是英雄 id。
# 返回：修复加成整数。
func get_equipment_repair_bonus(hero_id: String) -> int:
	var config: Dictionary = get_equipped_item_config(hero_id)
	return int(config.get("repair_bonus", 0))


# 作用：获取英雄装备带来的前哨加成。
# 参数：hero_id 是英雄 id。
# 返回：前哨加成整数。
func get_equipment_outpost_bonus(hero_id: String) -> int:
	var config: Dictionary = get_equipped_item_config(hero_id)
	return int(config.get("outpost_bonus", 0))


# 作用：返回探险成功应给英雄的基础经验。
# 参数：无。
# 返回：基础经验值。
func get_success_exp_reward() -> int:
	return BASE_EXP_SUCCESS


# 作用：返回战斗胜利应额外给英雄的经验。
# 参数：无。
# 返回：额外经验值。
func get_battle_victory_exp_reward() -> int:
	return BATTLE_EXP_VICTORY


# 作用：对单个英雄增加经验并自动处理升级。
# 参数：hero_id 是英雄 id；exp_gain 是增加经验；source 是日志来源。
# 返回：包含等级变化和最终经验的结果 Dictionary。
func add_hero_exp(hero_id: String, exp_gain: int, source: String) -> Dictionary:
	var before_level: int = GameState.get_hero_level(hero_id)
	var current_level: int = before_level
	var current_exp: int = GameState.get_hero_exp(hero_id)
	var remaining_exp: int = max(exp_gain, 0)
	var gained_exp: int = remaining_exp
	var level_ups: int = 0

	while remaining_exp > 0 and current_level < MAX_LEVEL:
		var next_need: int = get_exp_to_next_level(current_level)
		var need_exp: int = max(next_need - current_exp, 0)
		if remaining_exp < need_exp:
			current_exp += remaining_exp
			remaining_exp = 0
			break
		remaining_exp -= need_exp
		current_level += 1
		level_ups += 1
		current_exp = 0

	if current_level >= MAX_LEVEL:
		current_level = MAX_LEVEL
		current_exp = 0

	GameState.set_hero_level(hero_id, current_level, source)
	GameState.set_hero_exp(hero_id, current_exp, source)
	return {
		"hero_id": hero_id,
		"before_level": before_level,
		"after_level": current_level,
		"level_ups": level_ups,
		"exp_gain": gained_exp,
		"current_exp": current_exp,
		"exp_to_next": get_exp_to_next_level(current_level)
	}


# 作用：把一次探险的成长奖励应用到所有参战英雄。
# 参数：hero_ids 是英雄数组；exp_gain 是本次每名英雄获得的经验；source 是日志来源。
# 返回：英雄成长结果数组。
func apply_expedition_growth(hero_ids: Array[String], exp_gain: int, source: String) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	if exp_gain <= 0:
		return results

	for hero_id: String in hero_ids:
		if not GameState.is_hero_unlocked(hero_id):
			continue
		results.append(add_hero_exp(hero_id, exp_gain, source))
	return results


# 作用：让英雄装备指定装备。
# 参数：hero_id 是英雄 id；equipment_id 是装备 id；source 是日志来源。
# 返回：装备成功返回 true。
func equip_item(hero_id: String, equipment_id: String, source: String) -> bool:
	if not GameState.is_hero_unlocked(hero_id):
		return false
	if _is_hero_equipment_locked(hero_id):
		return false
	if DataLoader.get_equipment_config(equipment_id).is_empty():
		return false
	if GameState.get_equipment_inventory_amount(equipment_id) <= 0:
		return false

	var current_item_id: String = GameState.get_hero_equipped_item_id(hero_id)
	if current_item_id == equipment_id:
		return true
	if not current_item_id.is_empty():
		GameState.add_equipment_inventory(current_item_id, 1, source)

	GameState.add_equipment_inventory(equipment_id, -1, source)
	GameState.set_hero_equipped_item_id(hero_id, equipment_id, source)
	return true


# 作用：卸下英雄当前装备并返还库存。
# 参数：hero_id 是英雄 id；source 是日志来源。
# 返回：有装备被卸下时返回 true。
func unequip_item(hero_id: String, source: String) -> bool:
	if _is_hero_equipment_locked(hero_id):
		return false
	var current_item_id: String = GameState.get_hero_equipped_item_id(hero_id)
	if current_item_id.is_empty():
		return false
	GameState.add_equipment_inventory(current_item_id, 1, source)
	GameState.set_hero_equipped_item_id(hero_id, "", source)
	return true


# 作用：判断英雄当前是否处于不允许换装的执行状态。
# 参数：hero_id 是英雄 id。
# 返回：执行中或返程中返回 true。
func _is_hero_equipment_locked(hero_id: String) -> bool:
	var squad_id: String = GameState.get_hero_assigned_squad_id(hero_id)
	if squad_id.is_empty():
		return false
	var squad_status: String = GameState.get_squad_status(squad_id)
	return squad_status == "assigned" or squad_status == "returning"
