extends Node

const RESOURCE_REWARD_VALUES: Dictionary = {
	"wood": 3,
	"food": 3,
	"parts": 1,
	"hope": 2
}
const RESOURCE_HINT_ORDER: Array[String] = ["wood", "food", "coal", "medicine", "parts", "hope"]
const FURNACE_ID: String = "furnace"
const KITCHEN_ID: String = "kitchen"
const MEDICAL_TENT_ID: String = "medical_tent"
const WORKSHOP_ID: String = "workshop"
const TRAINING_GROUND_ID: String = "training_ground"
const INTRO_EVENT_FIRST_DAY: int = 4
const INTRO_EVENT_LAST_DAY: int = 5
const MIDGAME_UNLOCK_DAY: int = 8

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


# 作用：生成右侧目标面板的单行动态建议。
# 参数：无。
# 返回：中文建议文本；没有当前任务时返回收尾提示。
func get_current_quest_hint_text() -> String:
	var quest_id: String = get_current_quest_id()
	if quest_id.is_empty():
		return "前期引导已完成，可继续观察建筑状态并推进冰原地图。"

	match quest_id:
		"guide_collect_wood_once":
			return _build_collect_wood_hint()
		"guide_collect_food_once":
			return _build_collect_food_hint()
		"guide_upgrade_furnace_level_2":
			return _build_furnace_level_2_hint()
		"guide_build_kitchen":
			return _build_kitchen_hint()
		"guide_build_medical_tent":
			return _build_medical_tent_hint()
		"guide_assign_three_jobs":
			if GameState.day >= MIDGAME_UNLOCK_DAY - 2:
				return _build_day_8_prep_hint()
			return _build_job_assignment_hint()
		"guide_unlock_training_ground":
			return _build_day_8_prep_hint()
		"guide_send_first_scout_team":
			return _build_send_first_scout_team_hint()
		"guide_scout_first_region":
			return _build_scout_first_region_hint()
		_:
			return ""


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


# 作用：生成收取木材阶段的动态建议。
# 参数：无。
# 返回：说明当前动作、下一步主线和木材用途的中文建议。
func _build_collect_wood_hint() -> String:
	var furnace_cost: Dictionary = BuildingManager.get_building_cost_for_level(FURNACE_ID, 2)
	var wood_need: int = int(furnace_cost.get("wood", 0))
	return "主线先收一次木材；下一步还要收食物，再准备把寒炉升到 2 级；先记住寒炉 2 级要留 %d 木材" % wood_need


# 作用：生成收取食物阶段的动态建议。
# 参数：无。
# 返回：说明当前动作、今晚消耗和后续寒炉升级的中文建议。
func _build_collect_food_hint() -> String:
	var food_need_tonight: int = GameState.get_alive_population()
	return "主线现在要先收一次食物；今晚基础会消耗 %d 食物；收完后下一步是把寒炉升到 2 级" % food_need_tonight


# 作用：生成寒炉升到 2 级时的动态建议。
# 参数：无。
# 返回：包含升级成本、资源缺口和煤炭收益的中文建议。
func _build_furnace_level_2_hint() -> String:
	var target_level: int = 2
	var upgrade_cost: Dictionary = BuildingManager.get_building_cost_for_level(FURNACE_ID, target_level)
	var current_level_config: Dictionary = BuildingManager.get_furnace_current_level_config()
	var target_level_config: Dictionary = BuildingManager.get_furnace_level_config(target_level)
	var current_production: Dictionary = current_level_config.get("production", {}) as Dictionary
	var target_production: Dictionary = target_level_config.get("production", {}) as Dictionary
	var current_coal_need: int = int(current_production.get("coal_cost_per_night", 0))
	var target_coal_need: int = int(target_production.get("coal_cost_per_night", 0))
	return "主线现在要把寒炉升到 2 级；当前需 %s（%s）；升成后每晚煤炭 %d -> %d，完成后目标会转去建厨房" % [
		_build_cost_text(upgrade_cost),
		_build_missing_text(upgrade_cost),
		current_coal_need,
		target_coal_need
	]


# 作用：生成厨房阶段的动态建议。
# 参数：无。
# 返回：包含开放时间、建造缺口和食物节省预估的中文建议。
func _build_kitchen_hint() -> String:
	var build_cost: Dictionary = BuildingManager.get_building_cost_for_level(KITCHEN_ID, 1)
	var unlock_text: String = "厨房已开放"
	var unlock_day: int = _get_building_unlock_day(KITCHEN_ID)
	if GameState.day < unlock_day:
		unlock_text = "第 %d 天开放" % unlock_day
	var saved_food: int = _estimate_food_saved_with_projected_cooks(1)
	return "%s；主线现在要建厨房；当前需 %s（%s）；建成后安排 1 名厨师，今晚约省 %d 食物" % [
		unlock_text,
		_build_cost_text(build_cost),
		_build_missing_text(build_cost),
		saved_food
	]


# 作用：生成医务帐阶段的动态建议。
# 参数：无。
# 返回：包含事件前瞻、建造缺口和药品/医护建议的中文建议。
func _build_medical_tent_hint() -> String:
	var build_cost: Dictionary = BuildingManager.get_building_cost_for_level(MEDICAL_TENT_ID, 1)
	return "%s；主线下一步是建医务帐；当前需 %s（%s）；建成后至少安排 1 名医护，处理发烧时会更稳" % [
		_build_intro_event_text(),
		_build_cost_text(build_cost),
		_build_missing_text(build_cost)
	]


# 作用：生成岗位分配阶段的动态建议。
# 参数：无。
# 返回：包含岗位目标和首次伤病事件应对方式的中文建议。
func _build_job_assignment_hint() -> String:
	var unassigned_population: int = GameState.get_unassigned_population()
	return "主线现在要分配满 3 个岗位；当前还可分配 %d 人；建议至少留 1 名医护，第 4-5 天处理发烧会更稳" % unassigned_population


# 作用：生成第 8 天前后的中期准备建议。
# 参数：无。
# 返回：包含训练场、工坊成本和优先级建议的中文建议。
func _build_day_8_prep_hint() -> String:
	var days_left: int = max(MIDGAME_UNLOCK_DAY - GameState.day, 0)
	var prefix: String = "第 8 天已到"
	if days_left > 0:
		prefix = "距第 8 天还有 %d 天" % days_left
	var training_cost: Dictionary = BuildingManager.get_building_cost_for_level(TRAINING_GROUND_ID, 1)
	var workshop_cost: Dictionary = BuildingManager.get_building_cost_for_level(WORKSHOP_ID, 1)
	var training_text: String = _build_cost_text(training_cost)
	var training_missing_text: String = _build_missing_text(training_cost)
	var workshop_text: String = _build_cost_text(workshop_cost)
	var workshop_missing_text: String = _build_missing_text(workshop_cost)
	return "%s；第 8 天会自动解锁训练场和工坊，这个目标也会自动完成；下一步要进入冰原地图派出第一支侦察队。现在先预留训练场 %s（%s），资源够再补工坊 %s（%s）" % [
		prefix,
		training_text,
		training_missing_text,
		workshop_text,
		workshop_missing_text
	]


# 作用：生成派出第一支侦察队阶段的动态建议。
# 参数：无。
# 返回：说明进入地图的原因、主线下一步和当前动作的中文建议。
func _build_send_first_scout_team_hint() -> String:
	return "第 8 天后主线会转到地图；现在要进入冰原地图派出第一支侦察队；派出后下一步就是侦察断松林"


# 作用：生成侦察第一个区域阶段的动态建议。
# 参数：无。
# 返回：说明当前侦察目标、完成后的结果和资源意义的中文建议。
func _build_scout_first_region_hint() -> String:
	return "主线现在要侦察断松林；在地图里点占位按钮完成后，本轮前期引导会收尾；断松林是你后面稳定拿木材的第一块外部区域"


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


# 作用：获取建筑的开放天数。
# 参数：building_id 是建筑 id。
# 返回：建筑配置中的 unlock_day；没有配置时默认 1。
func _get_building_unlock_day(building_id: String) -> int:
	var config: Dictionary = DataLoader.get_building_config(building_id)
	return int(config.get("unlock_day", 1))


# 作用：根据当前人口和预设厨师人数，估算厨房 1 级的节省食物。
# 参数：projected_cook_count 是建议安排的厨师人数。
# 返回：向下取整后的预计节省食物数量。
func _estimate_food_saved_with_projected_cooks(projected_cook_count: int) -> int:
	var kitchen_level_config: Dictionary = BuildingManager.get_building_level_config(KITCHEN_ID, 1)
	var production: Dictionary = kitchen_level_config.get("production", {}) as Dictionary
	var rate_per_cook: float = float(production.get("food_save_rate", 0.0))
	var save_rate: float = clamp(float(projected_cook_count) * rate_per_cook, 0.0, 0.5)
	return int(floor(float(GameState.get_alive_population()) * save_rate))


# 作用：把建造或升级成本转换成稳定顺序的中文文本。
# 参数：cost 是资源 id 到数量的 Dictionary。
# 返回：中文成本文本，例如“木材 10、食物 8”。
func _build_cost_text(cost: Dictionary) -> String:
	var parts: PackedStringArray = PackedStringArray()
	for resource_id: String in RESOURCE_HINT_ORDER:
		if not cost.has(resource_id):
			continue
		var amount: int = int(cost.get(resource_id, 0))
		if amount <= 0:
			continue
		parts.append("%s %d" % [GameState.get_resource_name(resource_id), amount])
	if parts.is_empty():
		return "无需资源"
	return "、".join(parts)


# 作用：把当前资源缺口转换成中文提示。
# 参数：cost 是资源 id 到数量的 Dictionary。
# 返回：有缺口时返回“还差……”；资源已够时返回“资源已够”。
func _build_missing_text(cost: Dictionary) -> String:
	var missing: Dictionary = BuildingManager.get_missing_resources(cost)
	if missing.is_empty():
		return "资源已够"
	var missing_text: String = BuildingManager.get_missing_resources_text(missing)
	return missing_text.trim_prefix("缺少：")


# 作用：生成首次伤病事件的时间提示。
# 参数：无。
# 返回：基于当前天数的中文前瞻文本。
func _build_intro_event_text() -> String:
	if GameState.day < INTRO_EVENT_FIRST_DAY:
		return "第 %d-%d 天可能遇到孩子发烧" % [INTRO_EVENT_FIRST_DAY, INTRO_EVENT_LAST_DAY]
	if GameState.day == INTRO_EVENT_FIRST_DAY:
		return "今天开始可能遇到孩子发烧"
	if GameState.day == INTRO_EVENT_LAST_DAY:
		return "今天仍可能遇到孩子发烧"
	return "近期会持续出现伤病事件"
