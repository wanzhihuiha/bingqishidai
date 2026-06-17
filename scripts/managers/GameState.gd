extends Node

signal state_changed
signal resources_changed
signal temperature_changed
signal quest_relevant_state_changed

const DEFAULT_FURNACE_LEVEL: int = 1
const DEFAULT_WEATHER_PRESSURE: float = 0.0
const DEFAULT_MORALE_SCORE: int = 60
const FIRST_SCOUT_REGION_ID: String = "a1_broken_pines"
const INITIAL_BUILT_BUILDINGS: Array[String] = ["furnace", "lumber_yard", "hunter_lodge"]

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
var morale_score: int = DEFAULT_MORALE_SCORE
var health_status: String = "healthy"
var shelter_status_text: String = "营地维持中"
var temperature_score: int = 0
var weather_pressure: float = DEFAULT_WEATHER_PRESSURE
var collected_resources: Dictionary = {}
var buildings: Dictionary = {}
var job_assignments: Dictionary = {}
var assigned_jobs_total: int = 0
var scout_state: Dictionary = {}
var regions: Dictionary = {}
var quests: Dictionary = {}
var daily_flags: Dictionary = {}
var event_history: Dictionary = {}
var battle_reports: Array[String] = []
var is_started: bool = false


# 作用：开始一局新游戏，重置天数、阶段、资源、人口、建筑、岗位、地图、任务和事件状态。
# 参数：无。
# 返回：无。执行后会发出多个状态信号，通知界面和任务系统刷新。
func start_new_game() -> void:
	day = 1
	phase = "day"
	resources = _build_initial_resources()
	population = _build_initial_population()
	furnace_level = DEFAULT_FURNACE_LEVEL
	morale_score = DEFAULT_MORALE_SCORE
	weather_pressure = DEFAULT_WEATHER_PRESSURE
	collected_resources = {}
	buildings = _build_initial_buildings()
	job_assignments = _build_initial_job_assignments()
	assigned_jobs_total = 0
	scout_state = _build_initial_scout_state()
	regions = _build_initial_regions()
	quests = _build_initial_quests()
	daily_flags = _build_initial_daily_flags()
	event_history = _build_initial_event_history()
	battle_reports = []
	_update_building_unlocks_for_day("start_new_game")
	refresh_temperature_score("start_new_game")
	refresh_shelter_status("start_new_game")
	is_started = true
	print("[GameState] start_new_game day=%d phase=%s resources=%s population=%s furnace_level=%d morale=%d health_status=%s shelter_status=%s temperature_score=%d" % [
		day,
		phase,
		str(resources),
		str(population),
		furnace_level,
		morale_score,
		health_status,
		shelter_status_text,
		temperature_score
	])
	state_changed.emit()
	resources_changed.emit()
	temperature_changed.emit()
	quest_relevant_state_changed.emit()


# 作用：确保当前已经有一局游戏状态。
# 参数：无。
# 返回：无。未开始时会自动调用 start_new_game() 兜底。
func ensure_started() -> void:
	if is_started:
		return
	print("[GameState] ensure_started fallback")
	start_new_game()


# 作用：获取指定资源当前数量。
# 参数：resource_id 是资源 id，例如 food、coal。
# 返回：资源数量整数；没有该资源时返回 0。
func get_resource_amount(resource_id: String) -> int:
	return int(resources.get(resource_id, 0))


# 作用：获取指定资源的中文名。
# 参数：resource_id 是资源 id。
# 返回：资源中文名；配置缺失时返回 resource_id。
func get_resource_name(resource_id: String) -> String:
	var config: Dictionary = DataLoader.get_resource_config(resource_id)
	return str(config.get("name", resource_id))


# 作用：获取指定资源的最大容量。
# 参数：resource_id 是资源 id。
# 返回：最大容量；没有上限时返回 -1。
func get_resource_max_amount(resource_id: String) -> int:
	var config: Dictionary = DataLoader.get_resource_config(resource_id)
	var max_value: Variant = config.get("max_amount", null)
	if max_value == null:
		return -1
	return int(max_value)


# 作用：判断资源是否接近容量上限。
# 参数：resource_id 是资源 id。
# 返回：达到上限 80% 时返回 true；无上限资源返回 false。
func is_resource_near_max(resource_id: String) -> bool:
	var max_amount: int = get_resource_max_amount(resource_id)
	if max_amount < 0:
		return false
	var current_amount: int = get_resource_amount(resource_id)
	return current_amount >= int(float(max_amount) * 0.8)


# 作用：获取资源显示顺序。
# 参数：无。
# 返回：资源 id 数组，由 DataLoader 的配置顺序决定。
func get_resource_order() -> Array[String]:
	return DataLoader.get_resource_order()


# 作用：直接设置某个资源数量，并自动做上下限裁剪。
# 参数：resource_id 是资源 id；amount 是目标数量；source 是日志来源。
# 返回：无。执行后会发出资源和全局状态变化信号。
func set_resource(resource_id: String, amount: int, source: String) -> void:
	var before: int = get_resource_amount(resource_id)
	var after: int = _clamp_resource(resource_id, amount)
	resources[resource_id] = after
	print("[GameState] set_resource source=%s resource=%s before=%d after=%d" % [source, resource_id, before, after])
	if resource_id == "coal":
		refresh_temperature_score("resource_set:%s" % resource_id)
	resources_changed.emit()
	state_changed.emit()


# 作用：给某个资源增加或减少数量。
# 参数：resource_id 是资源 id；amount 是增量，负数表示扣除；source 是日志来源。
# 返回：无。煤炭变化会默认刷新温度评分。
func add_resource(resource_id: String, amount: int, source: String) -> void:
	add_resource_with_refresh(resource_id, amount, source, true)


# 作用：给某个资源增加或减少数量，并允许控制是否刷新温度。
# 参数：resource_id 是资源 id；amount 是增量；source 是日志来源；refresh_temperature 表示煤炭变化后是否立即刷新温度。
# 返回：无。执行后会发出资源和全局状态变化信号。
func add_resource_with_refresh(resource_id: String, amount: int, source: String, refresh_temperature: bool) -> void:
	var before: int = get_resource_amount(resource_id)
	var after: int = _clamp_resource(resource_id, before + amount)
	resources[resource_id] = after
	print("[GameState] add_resource source=%s resource=%s amount=%d before=%d after=%d" % [source, resource_id, amount, before, after])
	if refresh_temperature and resource_id == "coal":
		refresh_temperature_score("resource_changed:%s" % resource_id)
	resources_changed.emit()
	state_changed.emit()


# 作用：设置寒炉等级，并同步刷新温度和任务相关状态。
# 参数：level 是目标等级；source 是日志来源。
# 返回：无。等级会被裁剪在默认等级和配置最高等级之间。
func set_furnace_level(level: int, source: String) -> void:
	var before: int = furnace_level
	var max_level: int = BuildingManager.get_furnace_max_level()
	furnace_level = int(clamp(level, DEFAULT_FURNACE_LEVEL, max_level))
	print("[GameState] set_furnace_level source=%s before=%d after=%d" % [source, before, furnace_level])
	refresh_temperature_score("furnace_level_changed")
	state_changed.emit()
	quest_relevant_state_changed.emit()


# 作用：把幸存者从一种状态转移到另一种状态。
# 参数：from_state 是来源状态；to_state 是目标状态；amount 是请求转移人数；source 是日志来源。
# 返回：实际转移人数；当来源人数不足时会自动取可转移的最大值。
func transfer_population(from_state: String, to_state: String, amount: int, source: String) -> int:
	var before_from: int = int(population.get(from_state, 0))
	var before_to: int = int(population.get(to_state, 0))
	var actual_amount: int = min(max(amount, 0), before_from)
	if actual_amount <= 0:
		print("[GameState] transfer_population source=%s from=%s to=%s requested=%d actual=0 before_from=%d before_to=%d" % [
			source,
			from_state,
			to_state,
			amount,
			before_from,
			before_to
		])
		return 0

	population[from_state] = before_from - actual_amount
	population[to_state] = before_to + actual_amount
	print("[GameState] transfer_population source=%s from=%s to=%s requested=%d actual=%d before_from=%d after_from=%d before_to=%d after_to=%d" % [
		source,
		from_state,
		to_state,
		amount,
		actual_amount,
		before_from,
		int(population.get(from_state, 0)),
		before_to,
		int(population.get(to_state, 0))
	])
	_clamp_job_assignments_to_population(source)
	refresh_shelter_status("population_changed:%s" % source)
	state_changed.emit()
	return actual_amount


# 作用：增加或减少某一幸存者状态的人数。
# 参数：state_id 是人口状态；amount 是增量；source 是日志来源。
# 返回：实际变化量；减少到 0 以下时会被裁剪。
func add_population_state(state_id: String, amount: int, source: String) -> int:
	var before: int = int(population.get(state_id, 0))
	var after: int = max(before + amount, 0)
	population[state_id] = after
	print("[GameState] add_population_state source=%s state=%s amount=%d before=%d after=%d" % [
		source,
		state_id,
		amount,
		before,
		after
	])
	_clamp_job_assignments_to_population(source)
	refresh_shelter_status("population_changed:%s" % source)
	quest_relevant_state_changed.emit()
	state_changed.emit()
	return after - before


# 作用：推进到下一天，并重置每日标记和按天解锁建筑。
# 参数：source 是日志来源。
# 返回：无。执行后会发出状态和任务相关信号。
func advance_day(source: String) -> void:
	var before: int = day
	day += 1
	phase = "day"
	_reset_daily_flags(source)
	print("[GameState] advance_day source=%s before=%d after=%d phase=%s" % [source, before, day, phase])
	_update_building_unlocks_for_day(source)
	state_changed.emit()
	quest_relevant_state_changed.emit()


# 作用：记录某种资源已经被玩家至少收取过一次。
# 参数：resource_id 是资源 id；source 是日志来源。
# 返回：无。用于前期引导任务判断。
func mark_resource_collected(resource_id: String, source: String) -> void:
	var before: bool = bool(collected_resources.get(resource_id, false))
	collected_resources[resource_id] = true
	print("[GameState] mark_resource_collected source=%s resource=%s before=%s after=true" % [
		source,
		resource_id,
		str(before)
	])
	quest_relevant_state_changed.emit()
	state_changed.emit()


# 作用：判断某种资源是否已经完成过第一次收取。
# 参数：resource_id 是资源 id。
# 返回：已收取过返回 true，否则返回 false。
func was_resource_collected(resource_id: String) -> bool:
	return bool(collected_resources.get(resource_id, false))


# 作用：把指定建筑标记为已建造。
# 参数：building_id 是建筑 id；source 是日志来源。
# 返回：如果本次从未建造变为已建造返回 true；原本已建造返回 false。
func build_building(building_id: String, source: String) -> bool:
	var state: Dictionary = _get_or_create_building_state(building_id)
	var was_built: bool = bool(state.get("is_built", false))
	state["is_unlocked"] = true
	state["is_built"] = true
	state["current_level"] = max(1, int(state.get("current_level", 0)))
	buildings[building_id] = state
	if building_id == "furnace":
		set_furnace_level(int(state.get("current_level", DEFAULT_FURNACE_LEVEL)), source)
	print("[GameState] build_building source=%s building=%s before_built=%s after_built=true" % [
		source,
		building_id,
		str(was_built)
	])
	quest_relevant_state_changed.emit()
	state_changed.emit()
	return not was_built


# 作用：解锁指定建筑。
# 参数：building_id 是建筑 id；source 是日志来源。
# 返回：如果本次从未解锁变为已解锁返回 true；原本已解锁返回 false。
func unlock_building(building_id: String, source: String) -> bool:
	var state: Dictionary = _get_or_create_building_state(building_id)
	var was_unlocked: bool = bool(state.get("is_unlocked", false))
	state["is_unlocked"] = true
	buildings[building_id] = state
	print("[GameState] unlock_building source=%s building=%s before_unlocked=%s after_unlocked=true" % [
		source,
		building_id,
		str(was_unlocked)
	])
	quest_relevant_state_changed.emit()
	state_changed.emit()
	return not was_unlocked


# 作用：判断建筑是否已经建造。
# 参数：building_id 是建筑 id。
# 返回：已建造返回 true，否则返回 false。
func is_building_built(building_id: String) -> bool:
	var state: Dictionary = buildings.get(building_id, {}) as Dictionary
	return bool(state.get("is_built", false))


# 作用：判断建筑是否已经解锁。
# 参数：building_id 是建筑 id。
# 返回：已解锁返回 true，否则返回 false。
func is_building_unlocked(building_id: String) -> bool:
	var state: Dictionary = buildings.get(building_id, {}) as Dictionary
	return bool(state.get("is_unlocked", false))


# 作用：获取建筑当前等级。
# 参数：building_id 是建筑 id。
# 返回：建筑等级；未建造或无状态时返回 0。
func get_building_level(building_id: String) -> int:
	var state: Dictionary = buildings.get(building_id, {}) as Dictionary
	return int(state.get("current_level", 0))


# 作用：设置建筑等级，并同步建造/解锁状态。
# 参数：building_id 是建筑 id；level 是目标等级；source 是日志来源。
# 返回：等级发生变化返回 true；目标等级与原等级相同返回 false。
func set_building_level(building_id: String, level: int, source: String) -> bool:
	var state: Dictionary = _get_or_create_building_state(building_id)
	var before_level: int = int(state.get("current_level", 0))
	var config: Dictionary = DataLoader.get_building_config(building_id)
	var max_level: int = int(config.get("max_level", 1))
	var after_level: int = int(clamp(level, 0, max_level))
	state["current_level"] = after_level
	state["is_built"] = after_level > 0
	if after_level > 0:
		state["is_unlocked"] = true
	buildings[building_id] = state
	if building_id == "furnace":
		set_furnace_level(after_level, source)
	print("[GameState] set_building_level source=%s building=%s before=%d after=%d" % [
		source,
		building_id,
		before_level,
		after_level
	])
	quest_relevant_state_changed.emit()
	state_changed.emit()
	return before_level != after_level


# 作用：判断今天是否已经完成过建筑建设或升级。
# 参数：无。
# 返回：今天已操作过返回 true，否则返回 false。
func was_building_upgraded_today() -> bool:
	return bool(daily_flags.get("building_upgraded", false))


# 作用：标记今天已经完成过一次建筑建设或升级。
# 参数：source 是日志来源。
# 返回：无。用于限制每天最多一次建筑行动。
func mark_building_upgraded(source: String) -> void:
	var before: bool = was_building_upgraded_today()
	daily_flags["building_upgraded"] = true
	print("[GameState] mark_building_upgraded source=%s before=%s after=true" % [
		source,
		str(before)
	])
	state_changed.emit()


# 作用：判断今天是否已经处理过随机事件。
# 参数：无。
# 返回：今天事件已处理返回 true，否则返回 false。
func was_event_resolved_today() -> bool:
	return bool(daily_flags.get("event_resolved", false))


# 作用：标记今天事件已处理，并记录事件解决次数。
# 参数：event_id 是事件 id；source 是日志来源。
# 返回：无。用于避免同一天重复弹事件。
func mark_event_resolved(event_id: String, source: String) -> void:
	daily_flags["event_resolved"] = true
	var resolved_events: Dictionary = event_history.get("resolved_events", {}) as Dictionary
	resolved_events[event_id] = int(resolved_events.get(event_id, 0)) + 1
	event_history["resolved_events"] = resolved_events
	print("[GameState] mark_event_resolved source=%s event=%s flags=%s" % [
		source,
		event_id,
		str(daily_flags)
	])
	state_changed.emit()


# 作用：设置某类事件的冷却结束天数。
# 参数：unique_key 是事件冷却分组；until_day 是冷却到第几天；source 是日志来源。
# 返回：无。unique_key 为空时不会写入。
func set_event_cooldown(unique_key: String, until_day: int, source: String) -> void:
	if unique_key.is_empty():
		return
	var cooldowns: Dictionary = event_history.get("cooldowns", {}) as Dictionary
	cooldowns[unique_key] = until_day
	event_history["cooldowns"] = cooldowns
	print("[GameState] set_event_cooldown source=%s key=%s until_day=%d" % [
		source,
		unique_key,
		until_day
	])


# 作用：判断某类事件当前是否处于冷却中。
# 参数：unique_key 是事件冷却分组。
# 返回：当前天数小于等于冷却结束天数时返回 true。
func is_event_on_cooldown(unique_key: String) -> bool:
	if unique_key.is_empty():
		return false
	var cooldowns: Dictionary = event_history.get("cooldowns", {}) as Dictionary
	var until_day: int = int(cooldowns.get(unique_key, 0))
	return day <= until_day


# 作用：判断指定事件是否曾经被解决过。
# 参数：event_id 是事件 id。
# 返回：解决次数大于 0 时返回 true。
func has_event_been_resolved(event_id: String) -> bool:
	var resolved_events: Dictionary = event_history.get("resolved_events", {}) as Dictionary
	return int(resolved_events.get(event_id, 0)) > 0


# 作用：获取下一次允许检查随机事件的天数。
# 参数：无。
# 返回：天数整数；缺失时默认第 2 天。
func get_next_event_check_day() -> int:
	return int(event_history.get("next_check_day", 2))


# 作用：设置下一次随机事件检查日。
# 参数：next_day 是希望设置的检查日；source 是日志来源。
# 返回：无。实际值至少是当前天数 + 1。
func set_next_event_check_day(next_day: int, source: String) -> void:
	event_history["next_check_day"] = max(next_day, day + 1)
	print("[GameState] set_next_event_check_day source=%s next_day=%d current_day=%d" % [
		source,
		int(event_history.get("next_check_day", 0)),
		day
	])


# 作用：在近期日志中追加一条战斗或事件文本。
# 参数：line 是日志内容；source 是日志来源。
# 返回：无。最多保留 8 条，新的排在前面。
func add_battle_report(line: String, source: String) -> void:
	if line.is_empty():
		return
	battle_reports.push_front("第 %d 天 %s" % [day, line])
	while battle_reports.size() > 8:
		battle_reports.pop_back()
	print("[GameState] add_battle_report source=%s line=%s" % [source, line])
	state_changed.emit()


# 作用：获取近期日志列表。
# 参数：无。
# 返回：日志字符串数组的副本。
func get_battle_reports() -> Array[String]:
	return battle_reports.duplicate()


# 作用：设置某个岗位的人数，并确保总分配不超过可工作人口。
# 参数：job_id 是岗位 id；amount 是目标人数；source 是日志来源。
# 返回：人数实际变化返回 true；没有变化或岗位不存在返回 false。
func set_job_assignment(job_id: String, amount: int, source: String) -> bool:
	var before: int = get_job_assignment(job_id)
	var max_assignable: int = get_assignable_population()
	var other_assigned: int = assigned_jobs_total - before
	var allowed_amount: int = max_assignable - other_assigned
	var after: int = int(clamp(amount, 0, max(allowed_amount, 0)))
	if not job_assignments.has(job_id):
		print("[GameState] set_job_assignment failed source=%s job=%s reason=unknown_job" % [source, job_id])
		return false

	job_assignments[job_id] = after
	_refresh_assigned_jobs_total()
	print("[GameState] set_job_assignment source=%s job=%s before=%d requested=%d after=%d max_assignable=%d total=%d" % [
		source,
		job_id,
		before,
		amount,
		after,
		max_assignable,
		assigned_jobs_total
	])
	quest_relevant_state_changed.emit()
	state_changed.emit()
	return after != before


# 作用：按增量调整某个岗位人数。
# 参数：job_id 是岗位 id；delta 是增减人数；source 是日志来源。
# 返回：人数实际变化返回 true，否则返回 false。
func add_job_assignment(job_id: String, delta: int, source: String) -> bool:
	var before: int = get_job_assignment(job_id)
	return set_job_assignment(job_id, before + delta, source)


# 作用：获取某个岗位当前分配人数。
# 参数：job_id 是岗位 id。
# 返回：岗位人数；没有该岗位时返回 0。
func get_job_assignment(job_id: String) -> int:
	return int(job_assignments.get(job_id, 0))


# 作用：获取全部岗位分配。
# 参数：无。
# 返回：岗位分配 Dictionary 的深拷贝。
func get_job_assignments() -> Dictionary:
	return job_assignments.duplicate(true)


# 作用：计算可分配到岗位的人口。
# 参数：无。
# 返回：健康人口 + 轻伤人口；重伤和死亡不可分配。
func get_assignable_population() -> int:
	var healthy: int = int(population.get("healthy", 0))
	var light_wound: int = int(population.get("light_wound", 0))
	return healthy + light_wound


# 作用：计算尚未分配岗位的可工作人口。
# 参数：无。
# 返回：可分配人口减去已分配岗位总数，最小为 0。
func get_unassigned_population() -> int:
	return max(get_assignable_population() - assigned_jobs_total, 0)


# 作用：自动分配指定总人数到岗位。
# 参数：amount 是希望分配的总人数；source 是日志来源。
# 返回：无。会按岗位顺序每个岗位轮流放入 1 人，直到人数用完。
func assign_jobs_total(amount: int, source: String) -> void:
	var before: int = assigned_jobs_total
	var max_assignable: int = get_assignable_population()
	_clear_job_assignments()
	var remaining: int = int(clamp(amount, 0, max_assignable))
	var job_order: Array[String] = DataLoader.get_job_order()
	for job_id: String in job_order:
		if remaining <= 0:
			break
		job_assignments[job_id] = int(job_assignments.get(job_id, 0)) + 1
		remaining -= 1
	_refresh_assigned_jobs_total()
	print("[GameState] assign_jobs_total source=%s before=%d requested=%d after=%d max=%d assignments=%s" % [
		source,
		before,
		amount,
		assigned_jobs_total,
		max_assignable,
		str(job_assignments)
	])
	quest_relevant_state_changed.emit()
	state_changed.emit()


# 作用：标记已经派出第一支侦察队。
# 参数：source 是日志来源。
# 返回：如果本次从未派出变为已派出返回 true；原本已派出返回 false。
func send_first_scout_team(source: String) -> bool:
	var before: bool = bool(scout_state.get("first_scout_team_sent", false))
	scout_state["first_scout_team_sent"] = true
	print("[GameState] send_first_scout_team source=%s before=%s after=true" % [
		source,
		str(before)
	])
	quest_relevant_state_changed.emit()
	state_changed.emit()
	return not before


# 作用：判断第一支侦察队是否已经派出。
# 参数：无。
# 返回：已派出返回 true，否则返回 false。
func was_first_scout_team_sent() -> bool:
	return bool(scout_state.get("first_scout_team_sent", false))


# 作用：标记指定区域已侦察。
# 参数：region_id 是区域 id；source 是日志来源。
# 返回：如果本次从未侦察变为已侦察返回 true；原本已侦察返回 false。
func scout_region(region_id: String, source: String) -> bool:
	var state: Dictionary = regions.get(region_id, {}) as Dictionary
	if state.is_empty():
		state = {
			"is_scouted": false
		}
	var before: bool = bool(state.get("is_scouted", false))
	state["is_scouted"] = true
	regions[region_id] = state
	print("[GameState] scout_region source=%s region=%s before=%s after=true" % [
		source,
		region_id,
		str(before)
	])
	quest_relevant_state_changed.emit()
	state_changed.emit()
	return not before


# 作用：判断指定区域是否已侦察。
# 参数：region_id 是区域 id。
# 返回：已侦察返回 true，否则返回 false。
func is_region_scouted(region_id: String) -> bool:
	var state: Dictionary = regions.get(region_id, {}) as Dictionary
	return bool(state.get("is_scouted", false))


# 作用：初始化任务状态到指定第一个任务。
# 参数：first_quest_id 是当前任务 id。
# 返回：无。会清空已完成和已领奖记录。
func initialize_quest_state(first_quest_id: String) -> void:
	quests = {
		"current_quest_id": first_quest_id,
		"completed": {},
		"rewarded": {}
	}
	print("[GameState] initialize_quest_state current=%s" % first_quest_id)
	quest_relevant_state_changed.emit()
	state_changed.emit()


# 作用：获取当前主线/引导任务 id。
# 参数：无。
# 返回：当前任务 id；没有任务时返回空字符串。
func get_current_quest_id() -> String:
	return str(quests.get("current_quest_id", ""))


# 作用：设置当前主线/引导任务 id。
# 参数：quest_id 是任务 id；source 是日志来源。
# 返回：无。执行后会通知任务相关界面刷新。
func set_current_quest_id(quest_id: String, source: String) -> void:
	var before: String = get_current_quest_id()
	quests["current_quest_id"] = quest_id
	print("[GameState] set_current_quest_id source=%s before=%s after=%s" % [
		source,
		before,
		quest_id
	])
	quest_relevant_state_changed.emit()
	state_changed.emit()


# 作用：标记指定任务已完成。
# 参数：quest_id 是任务 id；source 是日志来源。
# 返回：无。完成状态会写入 quests.completed。
func mark_quest_completed(quest_id: String, source: String) -> void:
	var completed: Dictionary = quests.get("completed", {}) as Dictionary
	completed[quest_id] = true
	quests["completed"] = completed
	print("[GameState] mark_quest_completed source=%s quest=%s" % [source, quest_id])
	quest_relevant_state_changed.emit()
	state_changed.emit()


# 作用：判断指定任务是否已完成。
# 参数：quest_id 是任务 id。
# 返回：已完成返回 true，否则返回 false。
func is_quest_completed(quest_id: String) -> bool:
	var completed: Dictionary = quests.get("completed", {}) as Dictionary
	return bool(completed.get(quest_id, false))


# 作用：标记指定任务奖励已发放。
# 参数：quest_id 是任务 id；source 是日志来源。
# 返回：无。用于防止奖励重复领取。
func mark_quest_rewarded(quest_id: String, source: String) -> void:
	var rewarded: Dictionary = quests.get("rewarded", {}) as Dictionary
	rewarded[quest_id] = true
	quests["rewarded"] = rewarded
	print("[GameState] mark_quest_rewarded source=%s quest=%s" % [source, quest_id])
	quest_relevant_state_changed.emit()
	state_changed.emit()


# 作用：判断指定任务奖励是否已发放。
# 参数：quest_id 是任务 id。
# 返回：已发放返回 true，否则返回 false。
func is_quest_rewarded(quest_id: String) -> bool:
	var rewarded: Dictionary = quests.get("rewarded", {}) as Dictionary
	return bool(rewarded.get(quest_id, false))


# 作用：根据寒炉等级、煤炭数量和天气压力重新计算温度评分。
# 参数：source 是日志来源，默认 manual。
# 返回：无。会发出温度变化信号，并刷新营地状态文本。
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
	refresh_shelter_status("temperature_changed:%s" % source)


# 作用：把温度评分转换成中文状态。
# 参数：无。
# 返回：温暖、可忍受、寒冷或危险。
func get_temperature_status() -> String:
	if temperature_score >= 80:
		return "温暖"
	if temperature_score >= 50:
		return "可忍受"
	if temperature_score >= 20:
		return "寒冷"
	return "危险"


# 作用：获取存活人口总数。
# 参数：无。
# 返回：健康 + 轻伤 + 重伤人数，不包含死亡。
func get_alive_population() -> int:
	var healthy: int = int(population.get("healthy", 0))
	var light_wound: int = int(population.get("light_wound", 0))
	var heavy_wound: int = int(population.get("heavy_wound", 0))
	return healthy + light_wound + heavy_wound


# 作用：获取病患人口数量。
# 参数：无。
# 返回：轻伤 + 重伤人数。
func get_sick_population() -> int:
	var light_wound: int = int(population.get("light_wound", 0))
	var heavy_wound: int = int(population.get("heavy_wound", 0))
	return light_wound + heavy_wound


# 作用：获取健康人口数量。
# 参数：无。
# 返回：健康人口整数。
func get_healthy_population() -> int:
	return int(population.get("healthy", 0))


# 作用：增加或减少士气分数，并刷新营地状态。
# 参数：amount 是士气增量；source 是日志来源。
# 返回：实际变化量；士气会被裁剪在 0 到 100 之间。
func add_morale(amount: int, source: String) -> int:
	var before: int = morale_score
	morale_score = int(clamp(morale_score + amount, 0, 100))
	var delta: int = morale_score - before
	print("[GameState] add_morale source=%s amount=%d before=%d after=%d delta=%d" % [
		source,
		amount,
		before,
		morale_score,
		delta
	])
	refresh_shelter_status("morale_changed:%s" % source)
	state_changed.emit()
	quest_relevant_state_changed.emit()
	return delta


# 作用：刷新营地健康状态和顶部状态文案。
# 参数：source 是日志来源，默认 manual。
# 返回：无。该方法只更新状态字段，不主动发出信号。
func refresh_shelter_status(source: String = "manual") -> void:
	var before_health_status: String = health_status
	var before_status_text: String = shelter_status_text
	if get_sick_population() > 0:
		health_status = "sick"
	else:
		health_status = "healthy"

	shelter_status_text = _build_shelter_status_text()
	if before_health_status != health_status or before_status_text != shelter_status_text:
		print("[GameState] refresh_shelter_status source=%s health=%s->%s status=%s->%s morale=%d sick=%d temperature=%s" % [
			source,
			before_health_status,
			health_status,
			before_status_text,
			shelter_status_text,
			morale_score,
			get_sick_population(),
			get_temperature_status()
		])


# 作用：根据资源配置生成新游戏初始资源。
# 参数：无。
# 返回：资源 id 到初始数量的 Dictionary。
func _build_initial_resources() -> Dictionary:
	var result: Dictionary = {}
	var configs: Dictionary = DataLoader.get_resource_configs()

	for resource_id_value: Variant in configs.keys():
		var resource_id: String = str(resource_id_value)
		var config: Dictionary = configs.get(resource_id, {}) as Dictionary
		result[resource_id] = int(config.get("initial_amount", 0))

	return result


# 作用：根据幸存者配置生成新游戏初始人口。
# 参数：无。
# 返回：包含健康、轻伤、重伤、死亡人数的 Dictionary。
func _build_initial_population() -> Dictionary:
	var counts: Dictionary = DataLoader.get_survivor_initial_counts()
	return {
		"healthy": int(counts.get("healthy", 0)),
		"light_wound": int(counts.get("light_wound", 0)),
		"heavy_wound": int(counts.get("heavy_wound", 0)),
		"dead": int(counts.get("dead", 0))
	}


# 作用：根据建筑配置生成新游戏初始建筑状态。
# 参数：无。
# 返回：建筑 id 到运行时状态的 Dictionary，包含 is_unlocked、is_built、current_level。
func _build_initial_buildings() -> Dictionary:
	var result: Dictionary = {}
	var configs: Dictionary = DataLoader.get_building_configs()

	# 初始建成建筑来自 INITIAL_BUILT_BUILDINGS，其余建筑只按 unlock_day 判断是否已解锁。
	for building_id_value: Variant in configs.keys():
		var building_id: String = str(building_id_value)
		var config: Dictionary = configs.get(building_id, {}) as Dictionary
		var unlock_day: int = int(config.get("unlock_day", 1))
		var is_initial: bool = unlock_day <= day
		var current_level: int = 0
		var is_built: bool = false
		if INITIAL_BUILT_BUILDINGS.has(building_id):
			current_level = 1
			is_built = true
		result[building_id] = {
			"is_unlocked": is_initial,
			"is_built": is_built,
			"current_level": current_level
		}

	return result


# 作用：生成新游戏初始岗位分配。
# 参数：无。
# 返回：岗位 id 到人数的 Dictionary，所有岗位初始为 0。
func _build_initial_job_assignments() -> Dictionary:
	var result: Dictionary = {}
	var job_order: Array[String] = DataLoader.get_job_order()
	for job_id: String in job_order:
		result[job_id] = 0
	return result


# 作用：生成新游戏初始侦察状态。
# 参数：无。
# 返回：侦察状态 Dictionary。
func _build_initial_scout_state() -> Dictionary:
	return {
		"first_scout_team_sent": false
	}


# 作用：生成新游戏初始区域状态。
# 参数：无。
# 返回：区域运行时状态 Dictionary，目前先记录第一个教学侦察区域。
func _build_initial_regions() -> Dictionary:
	return {
		FIRST_SCOUT_REGION_ID: {
			"is_scouted": false
		}
	}


# 作用：生成新游戏初始任务状态。
# 参数：无。
# 返回：任务状态 Dictionary，包含当前任务、已完成、已领奖。
func _build_initial_quests() -> Dictionary:
	var quest_order: Array[String] = DataLoader.get_quest_order()
	var first_quest_id: String = ""
	if not quest_order.is_empty():
		first_quest_id = quest_order[0]
	return {
		"current_quest_id": first_quest_id,
		"completed": {},
		"rewarded": {}
	}


# 作用：生成每日标记的初始值。
# 参数：无。
# 返回：每日标记 Dictionary，例如今天是否升级建筑、是否处理事件。
func _build_initial_daily_flags() -> Dictionary:
	return {
		"building_upgraded": false,
		"event_resolved": false
	}


# 作用：生成事件历史初始状态。
# 参数：无。
# 返回：事件历史 Dictionary，包含已解决事件、冷却和下次检查日。
func _build_initial_event_history() -> Dictionary:
	return {
		"resolved_events": {},
		"cooldowns": {},
		"next_check_day": 2
	}


# 作用：重置每日标记。
# 参数：source 是日志来源。
# 返回：无。通常在推进到新一天时调用。
func _reset_daily_flags(source: String) -> void:
	daily_flags = _build_initial_daily_flags()
	print("[GameState] reset_daily_flags source=%s flags=%s" % [source, str(daily_flags)])


# 作用：获取指定建筑状态，如果不存在则创建默认状态。
# 参数：building_id 是建筑 id。
# 返回：建筑运行时状态 Dictionary。
func _get_or_create_building_state(building_id: String) -> Dictionary:
	var state: Dictionary = buildings.get(building_id, {}) as Dictionary
	if state.is_empty():
		state = {
			"is_unlocked": false,
			"is_built": false,
			"current_level": 0
		}
	return state


# 作用：根据温度、士气和病患情况生成营地状态文本。
# 参数：无。
# 返回：中文状态文案。
func _build_shelter_status_text() -> String:
	if get_temperature_status() == "危险":
		return "寒炉供暖危险"
	if morale_score <= 25:
		return "营地士气低落"
	if get_sick_population() > 0:
		return "有人需要治疗"
	if morale_score >= 75:
		return "营地运转稳定"
	return "营地维持中"


# 作用：按当前天数自动解锁达到 unlock_day 的建筑。
# 参数：source 是日志来源。
# 返回：无。有建筑解锁时会发出任务相关信号。
func _update_building_unlocks_for_day(source: String) -> void:
	var configs: Dictionary = DataLoader.get_building_configs()
	var changed: bool = false

	# 每天推进后检查所有建筑，保证 UI 和任务链都能感知第几天开放了什么建筑。
	for building_id_value: Variant in configs.keys():
		var building_id: String = str(building_id_value)
		var config: Dictionary = configs.get(building_id, {}) as Dictionary
		var unlock_day: int = int(config.get("unlock_day", 1))
		if day < unlock_day:
			continue

		var state: Dictionary = buildings.get(building_id, {}) as Dictionary
		if state.is_empty():
			state = {
				"is_unlocked": false,
				"is_built": false,
				"current_level": 0
			}
		if bool(state.get("is_unlocked", false)):
			continue

		state["is_unlocked"] = true
		buildings[building_id] = state
		changed = true
		print("[GameState] unlock_building_by_day source=%s building=%s unlock_day=%d current_day=%d" % [
			source,
			building_id,
			unlock_day,
			day
		])

	if changed:
		quest_relevant_state_changed.emit()


# 作用：按资源配置裁剪资源数量。
# 参数：resource_id 是资源 id；amount 是待写入数量。
# 返回：裁剪后的数量，不会低于 min_amount，也不会超过 max_amount。
func _clamp_resource(resource_id: String, amount: int) -> int:
	var config: Dictionary = DataLoader.get_resource_config(resource_id)
	var min_amount: int = int(config.get("min_amount", 0))
	var result: int = max(amount, min_amount)
	var max_value: Variant = config.get("max_amount", null)
	if max_value != null:
		var max_amount: int = int(max_value)
		result = min(result, max_amount)
	return result


# 作用：清空所有岗位分配。
# 参数：无。
# 返回：无。只把各岗位人数置 0，不刷新 total。
func _clear_job_assignments() -> void:
	for job_id_value: Variant in job_assignments.keys():
		var job_id: String = str(job_id_value)
		job_assignments[job_id] = 0


# 作用：重新统计已分配岗位总人数。
# 参数：无。
# 返回：无。结果写入 assigned_jobs_total。
func _refresh_assigned_jobs_total() -> void:
	var total: int = 0
	for job_id_value: Variant in job_assignments.keys():
		var job_id: String = str(job_id_value)
		total += int(job_assignments.get(job_id, 0))
	assigned_jobs_total = total


# 作用：当可工作人口下降时，自动压缩岗位分配，避免分配人数超过人口。
# 参数：source 是日志来源。
# 返回：无。会从岗位顺序末尾开始移除超出的分配人数。
func _clamp_job_assignments_to_population(source: String) -> void:
	var max_assignable: int = get_assignable_population()
	_refresh_assigned_jobs_total()
	if assigned_jobs_total <= max_assignable:
		return

	var overflow: int = assigned_jobs_total - max_assignable
	var job_order: Array[String] = DataLoader.get_job_order()
	# 从后面的岗位开始回收人数，可以尽量保留前序岗位的基础生存产出。
	for index: int in range(job_order.size() - 1, -1, -1):
		if overflow <= 0:
			break
		var job_id: String = job_order[index]
		var current: int = int(job_assignments.get(job_id, 0))
		if current <= 0:
			continue
		var removed: int = min(current, overflow)
		job_assignments[job_id] = current - removed
		overflow -= removed

	_refresh_assigned_jobs_total()
	print("[GameState] clamp_job_assignments source=%s max_assignable=%d total=%d assignments=%s" % [
		source,
		max_assignable,
		assigned_jobs_total,
		str(job_assignments)
	])
