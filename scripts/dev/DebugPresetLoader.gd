extends RefCounted

const DEBUG_PRESETS_PATH: String = "res://data/debug_presets.json"
const VALID_SCENES: Array[String] = ["main_menu", "shelter", "world_map", "result"]
const BEACON_KEYS: Array[String] = ["is_contacted", "intel_count", "repair_progress", "is_signal_sent"]
const REGION_OWNERS: Array[String] = ["player", "neutral", "enemy", "contested"]

var preset_items_by_id: Dictionary = {}
var preset_order: Array[String] = []
var last_errors: Array[String] = []


# 作用：创建加载器后立即读取一次调试预设，供调试面板和执行器复用。
# 参数：无。
# 返回：无。
func _init() -> void:
	reload()


# 作用：重新读取并校验调试预设文件。
# 参数：无。
# 返回：成功读到至少一个合法预设返回 true。
func reload() -> bool:
	preset_items_by_id = {}
	preset_order = []
	last_errors = []

	var data: Dictionary = _load_json_dictionary(DEBUG_PRESETS_PATH)
	if data.is_empty():
		_push_error("调试预设文件为空或读取失败：%s" % DEBUG_PRESETS_PATH)
		return false

	if int(data.get("schema_version", 0)) != 1:
		_push_error("调试预设 schema_version 缺失或不是 1。")
		return false

	var raw_items: Variant = data.get("items", [])
	if typeof(raw_items) != TYPE_ARRAY:
		_push_error("调试预设根节点 items 不是数组。")
		return false

	var items: Array = raw_items as Array
	for item_value: Variant in items:
		if typeof(item_value) != TYPE_DICTIONARY:
			_push_error("调试预设项不是 Dictionary。")
			continue

		var preset: Dictionary = item_value as Dictionary
		var preset_id: String = str(preset.get("id", ""))
		if preset_id.is_empty():
			_push_error("存在缺少 id 的调试预设。")
			continue
		if preset_items_by_id.has(preset_id):
			_push_error("调试预设 id 重复：%s" % preset_id)
			continue
		if not _validate_preset(preset):
			continue

		preset_items_by_id[preset_id] = preset.duplicate(true)
		preset_order.append(preset_id)

	return not preset_order.is_empty()


# 作用：返回调试预设列表，供调试面板渲染。
# 参数：无。
# 返回：按文件顺序排列的预设数组。
func get_preset_list() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for preset_id: String in preset_order:
		var preset: Dictionary = preset_items_by_id.get(preset_id, {}) as Dictionary
		if preset.is_empty():
			continue
		result.append(preset.duplicate(true))
	return result


# 作用：按 id 获取单个调试预设。
# 参数：preset_id 是预设 id。
# 返回：预设 Dictionary；找不到时返回空字典。
func get_preset_by_id(preset_id: String) -> Dictionary:
	var preset: Dictionary = preset_items_by_id.get(preset_id, {}) as Dictionary
	return preset.duplicate(true)


# 作用：返回最近一次加载时记录的错误列表。
# 参数：无。
# 返回：字符串数组。
func get_last_errors() -> Array[String]:
	return last_errors.duplicate()


# 作用：校验单个调试预设结构。
# 参数：preset 是待校验的预设 Dictionary。
# 返回：合法返回 true，否则返回 false。
func _validate_preset(preset: Dictionary) -> bool:
	var preset_id: String = str(preset.get("id", ""))
	var name: String = str(preset.get("name", ""))
	var description: String = str(preset.get("description", ""))
	var target_scene: String = str(preset.get("target_scene", ""))
	if name.is_empty():
		_push_error("调试预设缺少 name：%s" % preset_id)
		return false
	if description.is_empty():
		_push_error("调试预设缺少 description：%s" % preset_id)
		return false
	if not target_scene.is_empty() and not VALID_SCENES.has(target_scene):
		_push_error("调试预设 target_scene 不合法：%s -> %s" % [preset_id, target_scene])
		return false

	var raw_actions: Variant = preset.get("actions", [])
	if typeof(raw_actions) != TYPE_ARRAY:
		_push_error("调试预设 actions 不是数组：%s" % preset_id)
		return false

	var actions: Array = raw_actions as Array
	if actions.is_empty():
		_push_error("调试预设 actions 为空：%s" % preset_id)
		return false

	for action_value: Variant in actions:
		if typeof(action_value) != TYPE_DICTIONARY:
			_push_error("调试预设动作不是 Dictionary：%s" % preset_id)
			return false
		var action: Dictionary = action_value as Dictionary
		if not _validate_action(preset_id, action):
			return false

	return true


# 作用：校验单个动作结构和引用目标。
# 参数：preset_id 是所属预设 id；action 是动作 Dictionary。
# 返回：合法返回 true。
func _validate_action(preset_id: String, action: Dictionary) -> bool:
	var action_type: String = str(action.get("action_type", ""))
	if action_type.is_empty():
		_push_error("调试预设动作缺少 action_type：%s" % preset_id)
		return false

	match action_type:
		"start_new_game", "unlock_all_heroes", "clear_all_squads":
			return true
		"set_day":
			return _validate_number_value(preset_id, action_type, action)
		"grant_resources":
			return _validate_dictionary_keys(preset_id, action_type, action, "resource")
		"ensure_building_level":
			return _validate_target_and_number_value(preset_id, action_type, action, "building")
		"grant_equipment":
			return _validate_dictionary_keys(preset_id, action_type, action, "equipment")
		"assign_heroes_to_squad":
			return _validate_assign_action(preset_id, action_type, action)
		"set_region_state":
			return _validate_region_state_action(preset_id, action_type, action)
		"set_weather_pressure":
			return _validate_number_value(preset_id, action_type, action)
		"set_beacon_state":
			return _validate_beacon_state_action(preset_id, action_type, action)
		"go_to_scene":
			return _validate_go_to_scene_action(preset_id, action_type, action)
		_:
			_push_error("存在未识别的调试动作：%s -> %s" % [preset_id, action_type])
			return false


# 作用：校验数值型动作是否带有 value。
# 参数：preset_id 是所属预设；action_type 是动作类型；action 是动作数据。
# 返回：合法返回 true。
func _validate_number_value(preset_id: String, action_type: String, action: Dictionary) -> bool:
	var raw_value: Variant = action.get("value", null)
	if raw_value == null:
		_push_error("调试动作缺少 value：%s -> %s" % [preset_id, action_type])
		return false
	if typeof(raw_value) != TYPE_INT and typeof(raw_value) != TYPE_FLOAT:
		_push_error("调试动作 value 不是数值：%s -> %s" % [preset_id, action_type])
		return false
	return true


# 作用：校验带 target_id 和数值 value 的动作。
# 参数：preset_id 是所属预设；action_type 是动作类型；action 是动作数据；target_kind 是目标类型。
# 返回：合法返回 true。
func _validate_target_and_number_value(preset_id: String, action_type: String, action: Dictionary, target_kind: String) -> bool:
	var target_id: String = str(action.get("target_id", ""))
	if not _validate_target_id(preset_id, action_type, target_id, target_kind):
		return false
	return _validate_number_value(preset_id, action_type, action)


# 作用：校验资源或装备发放动作的 key 是否都存在。
# 参数：preset_id 是所属预设；action_type 是动作类型；action 是动作数据；key_kind 是 key 类型。
# 返回：合法返回 true。
func _validate_dictionary_keys(preset_id: String, action_type: String, action: Dictionary, key_kind: String) -> bool:
	var raw_value: Variant = action.get("value", null)
	if typeof(raw_value) != TYPE_DICTIONARY:
		_push_error("调试动作 value 不是 Dictionary：%s -> %s" % [preset_id, action_type])
		return false

	var value: Dictionary = raw_value as Dictionary
	for key_value: Variant in value.keys():
		var key_id: String = str(key_value)
		if not _validate_target_id(preset_id, action_type, key_id, key_kind):
			return false
		var amount_value: Variant = value.get(key_id, null)
		if typeof(amount_value) != TYPE_INT and typeof(amount_value) != TYPE_FLOAT:
			_push_error("调试动作数量不是数值：%s -> %s -> %s" % [preset_id, action_type, key_id])
			return false
	return true


# 作用：校验小队编成动作。
# 参数：preset_id 是所属预设；action_type 是动作类型；action 是动作数据。
# 返回：合法返回 true。
func _validate_assign_action(preset_id: String, action_type: String, action: Dictionary) -> bool:
	var target_id: String = str(action.get("target_id", ""))
	if not _validate_target_id(preset_id, action_type, target_id, "squad"):
		return false

	var raw_value: Variant = action.get("value", [])
	if typeof(raw_value) != TYPE_ARRAY:
		_push_error("调试编队动作 value 不是数组：%s -> %s" % [preset_id, action_type])
		return false

	var hero_values: Array = raw_value as Array
	if hero_values.is_empty():
		_push_error("调试编队动作英雄列表为空：%s -> %s" % [preset_id, action_type])
		return false

	for hero_value: Variant in hero_values:
		var hero_id: String = str(hero_value)
		if DataLoader.get_hero_config(hero_id).is_empty():
			_push_error("调试编队动作引用了不存在的英雄：%s -> %s -> %s" % [preset_id, action_type, hero_id])
			return false
	return true


# 作用：校验区域状态动作。
# 参数：preset_id 是所属预设；action_type 是动作类型；action 是动作数据。
# 返回：合法返回 true。
func _validate_region_state_action(preset_id: String, action_type: String, action: Dictionary) -> bool:
	var target_id: String = str(action.get("target_id", ""))
	if not _validate_target_id(preset_id, action_type, target_id, "region"):
		return false

	var raw_value: Variant = action.get("value", {})
	if typeof(raw_value) != TYPE_DICTIONARY:
		_push_error("区域状态动作 value 不是 Dictionary：%s -> %s" % [preset_id, action_type])
		return false

	var value: Dictionary = raw_value as Dictionary
	if value.has("owner"):
		var owner: String = str(value.get("owner", ""))
		if not REGION_OWNERS.has(owner):
			_push_error("区域状态 owner 不合法：%s -> %s -> %s" % [preset_id, action_type, owner])
			return false
	if value.has("danger_level"):
		var raw_danger: Variant = value.get("danger_level", null)
		if typeof(raw_danger) != TYPE_INT and typeof(raw_danger) != TYPE_FLOAT:
			_push_error("区域状态 danger_level 不是数值：%s -> %s" % [preset_id, action_type])
			return false
	if value.has("is_scouted") and typeof(value.get("is_scouted", null)) != TYPE_BOOL:
		_push_error("区域状态 is_scouted 不是 bool：%s -> %s" % [preset_id, action_type])
		return false
	return true


# 作用：校验信标状态动作。
# 参数：preset_id 是所属预设；action_type 是动作类型；action 是动作数据。
# 返回：合法返回 true。
func _validate_beacon_state_action(preset_id: String, action_type: String, action: Dictionary) -> bool:
	var raw_value: Variant = action.get("value", {})
	if typeof(raw_value) != TYPE_DICTIONARY:
		_push_error("信标状态动作 value 不是 Dictionary：%s -> %s" % [preset_id, action_type])
		return false

	var value: Dictionary = raw_value as Dictionary
	for key_value: Variant in value.keys():
		var key: String = str(key_value)
		if not BEACON_KEYS.has(key):
			_push_error("信标状态动作包含未知 key：%s -> %s -> %s" % [preset_id, action_type, key])
			return false
	return true


# 作用：校验跳场景动作。
# 参数：preset_id 是所属预设；action_type 是动作类型；action 是动作数据。
# 返回：合法返回 true。
func _validate_go_to_scene_action(preset_id: String, action_type: String, action: Dictionary) -> bool:
	var target_scene: String = str(action.get("value", ""))
	if not VALID_SCENES.has(target_scene):
		_push_error("调试跳场景动作 value 不合法：%s -> %s -> %s" % [preset_id, action_type, target_scene])
		return false
	return true


# 作用：校验 target_id 是否能在现有正式数据里找到。
# 参数：preset_id 是所属预设；action_type 是动作类型；target_id 是目标 id；target_kind 是目标类型。
# 返回：存在返回 true。
func _validate_target_id(preset_id: String, action_type: String, target_id: String, target_kind: String) -> bool:
	if target_id.is_empty():
		_push_error("调试动作缺少 target_id：%s -> %s" % [preset_id, action_type])
		return false

	match target_kind:
		"resource":
			if DataLoader.get_resource_config(target_id).is_empty():
				_push_error("调试动作引用了不存在的资源：%s -> %s -> %s" % [preset_id, action_type, target_id])
				return false
		"building":
			if DataLoader.get_building_config(target_id).is_empty():
				_push_error("调试动作引用了不存在的建筑：%s -> %s -> %s" % [preset_id, action_type, target_id])
				return false
		"equipment":
			if DataLoader.get_equipment_config(target_id).is_empty():
				_push_error("调试动作引用了不存在的装备：%s -> %s -> %s" % [preset_id, action_type, target_id])
				return false
		"squad":
			if DataLoader.get_squad_config(target_id).is_empty():
				_push_error("调试动作引用了不存在的小队：%s -> %s -> %s" % [preset_id, action_type, target_id])
				return false
		"region":
			if DataLoader.get_region_config(target_id).is_empty():
				_push_error("调试动作引用了不存在的区域：%s -> %s -> %s" % [preset_id, action_type, target_id])
				return false
		_:
			_push_error("调试动作包含未知 target_kind：%s -> %s -> %s" % [preset_id, action_type, target_kind])
			return false

	return true


# 作用：读取 JSON 文件为 Dictionary。
# 参数：path 是资源路径。
# 返回：读取成功返回 Dictionary，否则返回空字典。
func _load_json_dictionary(path: String) -> Dictionary:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var text: String = file.get_as_text()
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	return parsed as Dictionary


# 作用：统一记录调试预设加载错误并输出到 Godot 调试台。
# 参数：message 是错误文本。
# 返回：无。
func _push_error(message: String) -> void:
	last_errors.append(message)
	push_error("[DebugPresetLoader] %s" % message)
