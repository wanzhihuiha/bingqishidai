extends Node

const RESOURCE_REWARD_VALUES: Dictionary = {
	"wood": 3,
	"food": 3,
	"parts": 1,
	"hope": 2
}

var is_processing_quest: bool = false


# 作用：Godot 自动回调；注册任务相关状态变化信号，并延迟检查当前任务。
# 参数：无。
# 返回：无。任务状态变化时会自动触发 _evaluate_current_quest()。
func _ready() -> void:
	if not GameState.quest_relevant_state_changed.is_connected(_evaluate_current_quest):
		GameState.quest_relevant_state_changed.connect(_evaluate_current_quest)
	_queue_recheck()


# 作用：获取当前任务配置。
# 参数：无。
# 返回：当前任务配置 Dictionary；没有当前任务时返回空字典。
func get_current_quest() -> Dictionary:
	var quest_id: String = GameState.get_current_quest_id()
	if quest_id.is_empty():
		return {}
	return DataLoader.get_quest_config(quest_id)


# 作用：获取当前任务 id。
# 参数：无。
# 返回：当前任务 id；没有任务时返回空字符串。
func get_current_quest_id() -> String:
	return GameState.get_current_quest_id()


# 作用：生成当前任务进度文本。
# 参数：无。
# 返回：中文进度文本；前期引导完成后返回完成提示。
func get_current_quest_progress_text() -> String:
	var quest: Dictionary = get_current_quest()
	if quest.is_empty():
		return "前期引导已完成"

	var target: Dictionary = quest.get("target", {}) as Dictionary
	return _build_progress_text(target)


# 作用：生成当前任务奖励文本。
# 参数：无。
# 返回：中文奖励文本；没有奖励时返回“无”。
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


# 作用：获取当前任务标题。
# 参数：无。
# 返回：当前任务标题；没有任务时返回“前期引导已完成”。
func get_current_quest_title() -> String:
	var quest: Dictionary = get_current_quest()
	if quest.is_empty():
		return "前期引导已完成"
	return str(quest.get("title", "暂无目标"))


# 作用：检查当前任务是否已经满足完成条件。
# 参数：无。
# 返回：无。满足条件时会标记完成、发放奖励并推进到下一任务。
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


# 作用：恢复任务链推进，处理“任务已完成但奖励或下一步未处理”的情况。
# 参数：无。
# 返回：无。会补发奖励、推进下一任务，并再次排队检查。
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


# 作用：完成指定任务，发奖励并推进到下一任务。
# 参数：quest 是当前任务配置 Dictionary。
# 返回：无。会写入 GameState 的完成和领奖状态。
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


# 作用：根据当前任务配置切换到下一任务。
# 参数：quest 是当前任务配置 Dictionary。
# 返回：无。没有下一任务时会把 current_quest_id 置为空字符串。
func _move_to_next_quest(quest: Dictionary) -> void:
	var current_id: String = str(quest.get("id", ""))
	var next_ids: Array = quest.get("next_quest_ids", []) as Array
	var next_id: String = ""
	if not next_ids.is_empty():
		next_id = str(next_ids[0])

	GameState.set_current_quest_id(next_id, "quest_next")
	print("[QuestManager] quest_advanced from=%s to=%s" % [current_id, next_id])


# 作用：把任务检查延迟到当前帧结束后执行。
# 参数：无。
# 返回：无。用于避免信号回调中立刻递归检查导致状态交错。
func _queue_recheck() -> void:
	call_deferred("_evaluate_current_quest")


# 作用：发放任务奖励。
# 参数：quest 是任务配置 Dictionary。
# 返回：无。没有奖励时只输出日志。
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


# 作用：应用单条任务奖励。
# 参数：reward 是奖励配置；quest_id 是来源任务 id。
# 返回：无。目前只支持 resource_delta 类型奖励。
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


# 作用：判断任务目标是否已完成。
# 参数：target 是任务 target 配置 Dictionary。
# 返回：完成返回 true，否则返回 false；未知目标类型会输出错误并返回 false。
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


# 作用：把任务目标状态转换成进度文本。
# 参数：target 是任务 target 配置 Dictionary。
# 返回：中文进度文本；未知目标类型返回“进度未知”。
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


# 作用：把单条奖励配置转换成中文文本。
# 参数：reward 是奖励配置 Dictionary。
# 返回：中文奖励文本，例如“木材 +3”。
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


# 作用：获取建筑中文名。
# 参数：building_id 是建筑 id。
# 返回：建筑中文名；配置缺失时返回 building_id。
func _get_building_name(building_id: String) -> String:
	var config: Dictionary = DataLoader.get_building_config(building_id)
	return str(config.get("name", building_id))


# 作用：获取区域中文名。
# 参数：region_id 是区域 id。
# 返回：区域中文名；配置缺失时返回 region_id。
func _get_region_name(region_id: String) -> String:
	var config: Dictionary = DataLoader.get_region_config(region_id)
	return str(config.get("name", region_id))
