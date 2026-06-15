extends Node

const RESOURCE_REWARD_VALUES: Dictionary = {
	"wood": 3,
	"food": 3,
	"parts": 1,
	"hope": 2
}

var is_processing_quest: bool = false


func _ready() -> void:
	if not GameState.quest_relevant_state_changed.is_connected(_evaluate_current_quest):
		GameState.quest_relevant_state_changed.connect(_evaluate_current_quest)
	_queue_recheck()


func get_current_quest() -> Dictionary:
	var quest_id: String = GameState.get_current_quest_id()
	if quest_id.is_empty():
		return {}
	return DataLoader.get_quest_config(quest_id)


func get_current_quest_id() -> String:
	return GameState.get_current_quest_id()


func get_current_quest_progress_text() -> String:
	var quest: Dictionary = get_current_quest()
	if quest.is_empty():
		return "前期引导已完成"

	var target: Dictionary = quest.get("target", {}) as Dictionary
	return _build_progress_text(target)


func get_current_quest_reward_text() -> String:
	var quest: Dictionary = get_current_quest()
	if quest.is_empty():
		return "无"

	var rewards: Array = quest.get("rewards", []) as Array
	if rewards.is_empty():
		return "无"

	var parts: PackedStringArray = PackedStringArray()
	for reward_value: Variant in rewards:
		if typeof(reward_value) != TYPE_DICTIONARY:
			continue
		var reward: Dictionary = reward_value as Dictionary
		parts.append(_build_reward_text(reward))
	return "、".join(parts)


func get_current_quest_title() -> String:
	var quest: Dictionary = get_current_quest()
	if quest.is_empty():
		return "前期引导已完成"
	return str(quest.get("title", "暂无目标"))


func _evaluate_current_quest() -> void:
	if is_processing_quest:
		return
	if not GameState.is_started:
		return
	var quest_id: String = GameState.get_current_quest_id()
	if quest_id.is_empty():
		print("[QuestManager] no current quest")
		return
	if GameState.is_quest_completed(quest_id):
		_apply_completion_chain()
		return

	var quest: Dictionary = DataLoader.get_quest_config(quest_id)
	if quest.is_empty():
		push_error("[QuestManager] missing quest config id=%s" % quest_id)
		return

	var target: Dictionary = quest.get("target", {}) as Dictionary
	if _is_target_completed(target):
		_complete_quest(quest)


func _apply_completion_chain() -> void:
	if is_processing_quest:
		return
	is_processing_quest = true
	var current_id: String = GameState.get_current_quest_id()
	if current_id.is_empty():
		is_processing_quest = false
		return
	var quest: Dictionary = DataLoader.get_quest_config(current_id)
	if quest.is_empty():
		is_processing_quest = false
		return
	if not GameState.is_quest_rewarded(current_id):
		GameState.mark_quest_rewarded(current_id, "quest_chain_recover")
		_grant_rewards(quest)
	_move_to_next_quest(quest)
	is_processing_quest = false
	_queue_recheck()


func _complete_quest(quest: Dictionary) -> void:
	if is_processing_quest:
		return
	is_processing_quest = true
	var quest_id: String = str(quest.get("id", ""))
	if quest_id.is_empty():
		is_processing_quest = false
		return
	if GameState.is_quest_completed(quest_id):
		is_processing_quest = false
		return

	GameState.mark_quest_completed(quest_id, "quest_complete")
	GameState.mark_quest_rewarded(quest_id, "quest_complete")
	_grant_rewards(quest)
	print("[QuestManager] quest_completed id=%s title=%s" % [quest_id, str(quest.get("title", ""))])
	_move_to_next_quest(quest)
	is_processing_quest = false
	_queue_recheck()


func _move_to_next_quest(quest: Dictionary) -> void:
	var current_id: String = str(quest.get("id", ""))
	var next_ids: Array = quest.get("next_quest_ids", []) as Array
	var next_id: String = ""
	if not next_ids.is_empty():
		next_id = str(next_ids[0])

	GameState.set_current_quest_id(next_id, "quest_next")
	print("[QuestManager] quest_advanced from=%s to=%s" % [current_id, next_id])


func _queue_recheck() -> void:
	call_deferred("_evaluate_current_quest")


func _grant_rewards(quest: Dictionary) -> void:
	var quest_id: String = str(quest.get("id", ""))
	var rewards: Array = quest.get("rewards", []) as Array
	if rewards.is_empty():
		print("[QuestManager] quest_reward_empty id=%s" % quest_id)
		return

	for reward_value: Variant in rewards:
		if typeof(reward_value) != TYPE_DICTIONARY:
			continue
		var reward: Dictionary = reward_value as Dictionary
		_apply_reward(reward, quest_id)


func _apply_reward(reward: Dictionary, quest_id: String) -> void:
	var effect_type: String = str(reward.get("effect_type", ""))
	var target_id: String = str(reward.get("target_id", ""))
	var value: Variant = reward.get("value", 0)
	var note: String = str(reward.get("note", ""))
	if effect_type != "resource_delta":
		push_error("[QuestManager] unsupported reward type=%s quest=%s" % [effect_type, quest_id])
		return

	if not RESOURCE_REWARD_VALUES.has(target_id):
		push_error("[QuestManager] unsupported reward target=%s quest=%s" % [target_id, quest_id])
		return

	var amount: int = int(value)
	GameState.add_resource(target_id, amount, "quest_reward:%s" % quest_id)
	print("[QuestManager] quest_reward quest=%s target=%s amount=%d note=%s" % [
		quest_id,
		target_id,
		amount,
		note
	])


func _is_target_completed(target: Dictionary) -> bool:
	var target_type: String = str(target.get("type", ""))
	match target_type:
		"resource_collected_once":
			return GameState.was_resource_collected(str(target.get("resource_id", "")))
		"building_level":
			return GameState.furnace_level >= int(target.get("level", 0))
		"building_built":
			return GameState.is_building_built(str(target.get("building_id", "")))
		"job_assignment_total":
			return GameState.assigned_jobs_total >= int(target.get("value", 0))
		"building_unlocked":
			return GameState.is_building_unlocked(str(target.get("building_id", "")))
		"scout_team_sent":
			return GameState.was_first_scout_team_sent()
		"region_scouted":
			return GameState.is_region_scouted(str(target.get("region_id", "")))
		_:
			push_error("[QuestManager] unknown target type=%s" % target_type)
			return false


func _build_progress_text(target: Dictionary) -> String:
	var target_type: String = str(target.get("type", ""))
	match target_type:
		"resource_collected_once":
			var resource_id: String = str(target.get("resource_id", ""))
			var resource_name: String = GameState.get_resource_name(resource_id)
			return "%s：%d/1" % [resource_name, int(GameState.was_resource_collected(resource_id))]
		"building_level":
			var level: int = int(target.get("level", 0))
			return "寒炉等级：%d/%d" % [GameState.furnace_level, level]
		"building_built":
			var building_id: String = str(target.get("building_id", ""))
			return "%s：%d/1" % [_get_building_name(building_id), int(GameState.is_building_built(building_id))]
		"job_assignment_total":
			var goal: int = int(target.get("value", 0))
			return "岗位人数：%d/%d" % [GameState.assigned_jobs_total, goal]
		"building_unlocked":
			var unlock_id: String = str(target.get("building_id", ""))
			return "%s：%d/1" % [_get_building_name(unlock_id), int(GameState.is_building_unlocked(unlock_id))]
		"scout_team_sent":
			return "侦察队派出：%d/1" % int(GameState.was_first_scout_team_sent())
		"region_scouted":
			var region_id: String = str(target.get("region_id", ""))
			var region_name: String = _get_region_name(region_id)
			return "%s：%d/1" % [region_name, int(GameState.is_region_scouted(region_id))]
		_:
			return "进度未知"


func _build_reward_text(reward: Dictionary) -> String:
	var target_id: String = str(reward.get("target_id", ""))
	var value: int = int(reward.get("value", 0))
	var amount_text: String = ""
	if value > 0:
		amount_text = "+%d" % value
	else:
		amount_text = str(value)

	if target_id == "hope":
		return "希望值 %s" % amount_text
	return "%s %s" % [GameState.get_resource_name(target_id), amount_text]


func _get_building_name(building_id: String) -> String:
	var config: Dictionary = DataLoader.get_building_config(building_id)
	return str(config.get("name", building_id))


func _get_region_name(region_id: String) -> String:
	var config: Dictionary = DataLoader.get_region_config(region_id)
	return str(config.get("name", region_id))
