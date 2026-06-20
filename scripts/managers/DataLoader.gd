extends Node

const RESOURCES_PATH: String = "res://data/resources.json"
const SURVIVORS_PATH: String = "res://data/survivors.json"
const JOBS_PATH: String = "res://data/jobs.json"
const BUILDINGS_PATH: String = "res://data/buildings.json"
const HEROES_PATH: String = "res://data/heroes.json"
const SQUADS_PATH: String = "res://data/squads.json"
const QUESTS_PATH: String = "res://data/quests.json"
const REGIONS_PATH: String = "res://data/regions.json"
const EVENTS_PATH: String = "res://data/events.json"

var resource_configs: Dictionary = {}
var resource_order: Array[String] = []
var survivor_config: Dictionary = {}
var job_configs: Dictionary = {}
var job_order: Array[String] = []
var building_configs: Dictionary = {}
var building_order: Array[String] = []
var hero_configs: Dictionary = {}
var hero_order: Array[String] = []
var squad_configs: Dictionary = {}
var squad_order: Array[String] = []
var quest_configs: Dictionary = {}
var quest_order: Array[String] = []
var region_configs: Dictionary = {}
var event_configs: Dictionary = {}
var event_order: Array[String] = []


# 作用：Godot 自动回调；DataLoader 作为 Autoload 加载完成后，立即读取所有 JSON 配置。
# 参数：无。
# 返回：无。执行后会填充本脚本中的各类配置缓存。
func _ready() -> void:
	load_all()


# 作用：集中加载资源、幸存者、岗位、建筑、任务、区域和事件配置。
# 参数：无。
# 返回：无。读取结果会保存在本管理器的缓存变量中，供其他脚本查询。
func load_all() -> void:
	resource_configs = _load_resource_configs()
	survivor_config = _load_survivor_config()
	job_configs = _load_job_configs()
	building_configs = _load_building_configs()
	hero_configs = _load_hero_configs()
	squad_configs = _load_squad_configs()
	quest_configs = _load_quest_configs()
	region_configs = _load_region_configs()
	event_configs = _load_event_configs()
	print("[DataLoader] load_all resources=%d survivor_config=%s jobs=%d buildings=%d heroes=%d squads=%d quests=%d events=%d" % [
		resource_configs.size(),
		str(not survivor_config.is_empty()),
		job_configs.size(),
		building_configs.size(),
		hero_configs.size(),
		squad_configs.size(),
		quest_configs.size(),
		event_configs.size()
	])


# 作用：获取所有资源配置的深拷贝，避免调用方直接改到缓存。
# 参数：无。
# 返回：资源 id 到资源配置 Dictionary 的映射。
func get_resource_configs() -> Dictionary:
	return resource_configs.duplicate(true)


# 作用：获取资源显示顺序。
# 参数：无。
# 返回：按 JSON 顺序整理好的资源 id 数组。
func get_resource_order() -> Array[String]:
	return resource_order.duplicate()


# 作用：按资源 id 获取单个资源配置。
# 参数：resource_id 是资源 id，例如 wood、food、coal。
# 返回：资源配置 Dictionary；找不到时返回空字典。
func get_resource_config(resource_id: String) -> Dictionary:
	var config: Dictionary = resource_configs.get(resource_id, {}) as Dictionary
	return config.duplicate(true)


# 作用：获取新游戏初始幸存者人数配置。
# 参数：无。
# 返回：包含 healthy、light_wound、heavy_wound、dead 等状态人数的 Dictionary。
func get_survivor_initial_counts() -> Dictionary:
	var counts: Dictionary = survivor_config.get("initial_counts", {}) as Dictionary
	return counts.duplicate(true)


# 作用：获取轻伤幸存者的产出倍率。
# 参数：无。
# 返回：浮点数倍率；配置缺失时默认 0.5。
func get_wounded_output_modifier() -> float:
	return float(survivor_config.get("wounded_output_modifier", 0.5))


# 作用：获取所有岗位配置的深拷贝。
# 参数：无。
# 返回：岗位 id 到岗位配置 Dictionary 的映射。
func get_job_configs() -> Dictionary:
	return job_configs.duplicate(true)


# 作用：获取岗位显示和分配顺序。
# 参数：无。
# 返回：岗位 id 数组。
func get_job_order() -> Array[String]:
	return job_order.duplicate()


# 作用：按岗位 id 获取岗位配置。
# 参数：job_id 是岗位 id，例如 worker、hunter、cook。
# 返回：岗位配置 Dictionary；找不到时返回空字典。
func get_job_config(job_id: String) -> Dictionary:
	var config: Dictionary = job_configs.get(job_id, {}) as Dictionary
	return config.duplicate(true)


# 作用：获取所有建筑配置的深拷贝。
# 参数：无。
# 返回：建筑 id 到建筑配置 Dictionary 的映射。
func get_building_configs() -> Dictionary:
	return building_configs.duplicate(true)


# 作用：获取建筑显示顺序。
# 参数：无。
# 返回：建筑 id 数组。
func get_building_order() -> Array[String]:
	return building_order.duplicate()


# 作用：按建筑 id 获取建筑配置。
# 参数：building_id 是建筑 id，例如 furnace、kitchen。
# 返回：建筑配置 Dictionary；找不到时返回空字典。
func get_building_config(building_id: String) -> Dictionary:
	var config: Dictionary = building_configs.get(building_id, {}) as Dictionary
	return config.duplicate(true)


# 作用：获取所有英雄配置的深拷贝。
# 参数：无。
# 返回：英雄 id 到英雄配置 Dictionary 的映射。
func get_hero_configs() -> Dictionary:
	return hero_configs.duplicate(true)


# 作用：获取英雄显示顺序。
# 参数：无。
# 返回：英雄 id 数组。
func get_hero_order() -> Array[String]:
	return hero_order.duplicate()


# 作用：按英雄 id 获取英雄配置。
# 参数：hero_id 是英雄 id，例如 lin_che。
# 返回：英雄配置 Dictionary；找不到时返回空字典。
func get_hero_config(hero_id: String) -> Dictionary:
	var config: Dictionary = hero_configs.get(hero_id, {}) as Dictionary
	return config.duplicate(true)


# 作用：获取所有小队静态配置的深拷贝。
# 参数：无。
# 返回：小队 id 到小队配置 Dictionary 的映射。
func get_squad_configs() -> Dictionary:
	return squad_configs.duplicate(true)


# 作用：获取小队显示顺序。
# 参数：无。
# 返回：按 JSON 顺序整理好的小队 id 数组。
func get_squad_order() -> Array[String]:
	return squad_order.duplicate()


# 作用：按小队 id 获取单个小队配置。
# 参数：squad_id 是小队 id，例如 pioneer_team。
# 返回：小队配置 Dictionary；找不到时返回空字典。
func get_squad_config(squad_id: String) -> Dictionary:
	var config: Dictionary = squad_configs.get(squad_id, {}) as Dictionary
	return config.duplicate(true)


# 作用：获取所有主线/引导任务配置。
# 参数：无。
# 返回：任务 id 到任务配置 Dictionary 的映射。
func get_quest_configs() -> Dictionary:
	return quest_configs.duplicate(true)


# 作用：获取任务推进顺序。
# 参数：无。
# 返回：任务 id 数组，通常用于确定新游戏的第一个任务。
func get_quest_order() -> Array[String]:
	return quest_order.duplicate()


# 作用：按任务 id 获取任务配置。
# 参数：quest_id 是任务 id。
# 返回：任务配置 Dictionary；找不到时返回空字典。
func get_quest_config(quest_id: String) -> Dictionary:
	var config: Dictionary = quest_configs.get(quest_id, {}) as Dictionary
	return config.duplicate(true)


# 作用：按区域 id 获取冰原区域配置。
# 参数：region_id 是区域 id，例如 a1_broken_pines。
# 返回：区域配置 Dictionary；找不到时返回空字典。
func get_region_config(region_id: String) -> Dictionary:
	var config: Dictionary = region_configs.get(region_id, {}) as Dictionary
	return config.duplicate(true)


# 作用：获取所有冰原区域配置。
# 参数：无。
# 返回：区域 id 到区域配置 Dictionary 的映射。
func get_region_configs() -> Dictionary:
	return region_configs.duplicate(true)


# 作用：获取所有随机事件配置。
# 参数：无。
# 返回：事件 id 到事件配置 Dictionary 的映射。
func get_event_configs() -> Dictionary:
	return event_configs.duplicate(true)


# 作用：获取事件遍历顺序。
# 参数：无。
# 返回：事件 id 数组，用于事件候选筛选。
func get_event_order() -> Array[String]:
	return event_order.duplicate()


# 作用：按事件 id 获取事件配置。
# 参数：event_id 是事件 id。
# 返回：事件配置 Dictionary；找不到时返回空字典。
func get_event_config(event_id: String) -> Dictionary:
	var config: Dictionary = event_configs.get(event_id, {}) as Dictionary
	return config.duplicate(true)


# 作用：从 resources.json 加载资源配置，并建立资源顺序。
# 参数：无。
# 返回：资源 id 到资源配置的 Dictionary；非法条目会被跳过并输出错误。
func _load_resource_configs() -> Dictionary:
	resource_order.clear()
	var data: Dictionary = _load_json_dictionary(RESOURCES_PATH)
	var items: Array = data.get("items", []) as Array
	var result: Dictionary = {}

	# 遍历 JSON 数组时先做类型和 id 校验，避免后续系统拿到脏配置。
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


# 作用：从 survivors.json 加载幸存者初始配置。
# 参数：无。
# 返回：幸存者配置 Dictionary；缺少关键状态时会输出错误但仍返回已读取数据。
func _load_survivor_config() -> Dictionary:
	var data: Dictionary = _load_json_dictionary(SURVIVORS_PATH)
	var counts: Dictionary = data.get("initial_counts", {}) as Dictionary
	var required_states: Array[String] = ["healthy", "light_wound", "heavy_wound", "dead"]

	for state_id: String in required_states:
		if not counts.has(state_id):
			push_error("[DataLoader] survivors initial_counts missing %s" % state_id)

	print("[DataLoader] load_survivors counts=%s" % str(counts))
	return data


# 作用：从 jobs.json 加载岗位配置，并建立岗位顺序。
# 参数：无。
# 返回：岗位 id 到岗位配置的 Dictionary；非法条目会被跳过。
func _load_job_configs() -> Dictionary:
	job_order.clear()
	var data: Dictionary = _load_json_dictionary(JOBS_PATH)
	var items: Array = data.get("items", []) as Array
	var result: Dictionary = {}

	for item_value: Variant in items:
		if typeof(item_value) != TYPE_DICTIONARY:
			push_error("[DataLoader] jobs item is not dictionary")
			continue

		var item: Dictionary = item_value as Dictionary
		var job_id: String = str(item.get("id", ""))
		if job_id.is_empty():
			push_error("[DataLoader] jobs item missing id")
			continue
		if result.has(job_id):
			push_error("[DataLoader] duplicated job id=%s" % job_id)
			continue

		result[job_id] = item.duplicate(true)
		job_order.append(job_id)

	print("[DataLoader] load_jobs count=%d order=%s" % [result.size(), str(job_order)])
	return result


# 作用：从 buildings.json 加载建筑配置，并建立建筑顺序。
# 参数：无。
# 返回：建筑 id 到建筑配置的 Dictionary；非法条目会被跳过。
func _load_building_configs() -> Dictionary:
	building_order.clear()
	var data: Dictionary = _load_json_dictionary(BUILDINGS_PATH)
	var items: Array = data.get("items", []) as Array
	var result: Dictionary = {}

	for item_value: Variant in items:
		if typeof(item_value) != TYPE_DICTIONARY:
			push_error("[DataLoader] buildings item is not dictionary")
			continue

		var item: Dictionary = item_value as Dictionary
		var building_id: String = str(item.get("id", ""))
		if building_id.is_empty():
			push_error("[DataLoader] buildings item missing id")
			continue
		if result.has(building_id):
			push_error("[DataLoader] duplicated building id=%s" % building_id)
			continue

		result[building_id] = item.duplicate(true)
		building_order.append(building_id)

	print("[DataLoader] load_buildings count=%d order=%s" % [result.size(), str(building_order)])
	return result


# 作用：从 heroes.json 加载英雄配置，并建立英雄顺序。
# 参数：无。
# 返回：英雄 id 到英雄配置的 Dictionary；非法条目会被跳过。
func _load_hero_configs() -> Dictionary:
	hero_order.clear()
	var data: Dictionary = _load_json_dictionary(HEROES_PATH)
	var items: Array = data.get("items", []) as Array
	var result: Dictionary = {}

	for item_value: Variant in items:
		if typeof(item_value) != TYPE_DICTIONARY:
			push_error("[DataLoader] heroes item is not dictionary")
			continue

		var item: Dictionary = item_value as Dictionary
		var hero_id: String = str(item.get("id", ""))
		if hero_id.is_empty():
			push_error("[DataLoader] heroes item missing id")
			continue
		if result.has(hero_id):
			push_error("[DataLoader] duplicated hero id=%s" % hero_id)
			continue

		result[hero_id] = item.duplicate(true)
		hero_order.append(hero_id)

	print("[DataLoader] load_heroes count=%d order=%s" % [result.size(), str(hero_order)])
	return result


# 作用：从 squads.json 加载小队配置，并建立小队顺序。
# 参数：无。
# 返回：小队 id 到小队配置的 Dictionary；非法条目会被跳过。
func _load_squad_configs() -> Dictionary:
	squad_order.clear()
	var data: Dictionary = _load_json_dictionary(SQUADS_PATH)
	var items: Array = data.get("items", []) as Array
	var result: Dictionary = {}

	for item_value: Variant in items:
		if typeof(item_value) != TYPE_DICTIONARY:
			push_error("[DataLoader] squads item is not dictionary")
			continue

		var item: Dictionary = item_value as Dictionary
		var squad_id: String = str(item.get("id", ""))
		if squad_id.is_empty():
			push_error("[DataLoader] squads item missing id")
			continue
		if result.has(squad_id):
			push_error("[DataLoader] duplicated squad id=%s" % squad_id)
			continue

		result[squad_id] = item.duplicate(true)
		squad_order.append(squad_id)

	print("[DataLoader] load_squads count=%d order=%s" % [result.size(), str(squad_order)])
	return result


# 作用：从 quests.json 加载主线/引导任务配置，并建立任务顺序。
# 参数：无。
# 返回：任务 id 到任务配置的 Dictionary；非法条目会被跳过。
func _load_quest_configs() -> Dictionary:
	quest_order.clear()
	var data: Dictionary = _load_json_dictionary(QUESTS_PATH)
	var items: Array = data.get("items", []) as Array
	var result: Dictionary = {}

	for item_value: Variant in items:
		if typeof(item_value) != TYPE_DICTIONARY:
			push_error("[DataLoader] quests item is not dictionary")
			continue

		var item: Dictionary = item_value as Dictionary
		var quest_id: String = str(item.get("id", ""))
		if quest_id.is_empty():
			push_error("[DataLoader] quests item missing id")
			continue
		if result.has(quest_id):
			push_error("[DataLoader] duplicated quest id=%s" % quest_id)
			continue

		result[quest_id] = item.duplicate(true)
		quest_order.append(quest_id)

	print("[DataLoader] load_quests count=%d order=%s" % [result.size(), str(quest_order)])
	return result


# 作用：从 regions.json 加载冰原地图区域配置。
# 参数：无。
# 返回：区域 id 到区域配置的 Dictionary；非法条目会被跳过。
func _load_region_configs() -> Dictionary:
	var data: Dictionary = _load_json_dictionary(REGIONS_PATH)
	var items: Array = data.get("items", []) as Array
	var result: Dictionary = {}

	for item_value: Variant in items:
		if typeof(item_value) != TYPE_DICTIONARY:
			push_error("[DataLoader] regions item is not dictionary")
			continue

		var item: Dictionary = item_value as Dictionary
		var region_id: String = str(item.get("id", ""))
		if region_id.is_empty():
			push_error("[DataLoader] regions item missing id")
			continue
		if result.has(region_id):
			push_error("[DataLoader] duplicated region id=%s" % region_id)
			continue

		result[region_id] = item.duplicate(true)

	print("[DataLoader] load_regions count=%d" % result.size())
	return result


# 作用：从 events.json 加载随机事件配置，并建立事件顺序。
# 参数：无。
# 返回：事件 id 到事件配置的 Dictionary；非法条目会被跳过。
func _load_event_configs() -> Dictionary:
	event_order.clear()
	var data: Dictionary = _load_json_dictionary(EVENTS_PATH)
	var items: Array = data.get("items", []) as Array
	var result: Dictionary = {}

	for item_value: Variant in items:
		if typeof(item_value) != TYPE_DICTIONARY:
			push_error("[DataLoader] events item is not dictionary")
			continue

		var item: Dictionary = item_value as Dictionary
		var event_id: String = str(item.get("id", ""))
		if event_id.is_empty():
			push_error("[DataLoader] events item missing id")
			continue
		if result.has(event_id):
			push_error("[DataLoader] duplicated event id=%s" % event_id)
			continue

		result[event_id] = item.duplicate(true)
		event_order.append(event_id)

	print("[DataLoader] load_events count=%d order=%s" % [result.size(), str(event_order)])
	return result


# 作用：读取指定 JSON 文件并解析为 Dictionary。
# 参数：path 是 Godot 资源路径，例如 res://data/resources.json。
# 返回：解析成功返回 Dictionary；文件打不开或不是 JSON 对象时返回空字典。
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
