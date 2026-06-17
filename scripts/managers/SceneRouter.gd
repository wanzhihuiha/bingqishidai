extends Node

const MAIN_MENU_SCENE: String = "res://scenes/menu/MainMenu.tscn"
const SHELTER_SCENE: String = "res://scenes/shelter/ShelterView.tscn"
const WORLD_MAP_SCENE: String = "res://scenes/world/WorldMapView.tscn"
const RESULT_SCENE: String = "res://scenes/ui/ResultView.tscn"


# 作用：切换到主菜单场景。
# 参数：无。
# 返回：无。执行后会请求 Godot 场景树加载主菜单。
func go_to_main_menu() -> void:
	_change_scene(MAIN_MENU_SCENE, "main_menu")


# 作用：切换到避难所主界面。
# 参数：无。
# 返回：无。执行后会请求 Godot 场景树加载避难所场景。
func go_to_shelter() -> void:
	_change_scene(SHELTER_SCENE, "shelter")


# 作用：切换到冰原地图界面。
# 参数：无。
# 返回：无。执行后会请求 Godot 场景树加载地图场景。
func go_to_world_map() -> void:
	_change_scene(WORLD_MAP_SCENE, "world_map")


# 作用：切换到结算界面。
# 参数：无。
# 返回：无。执行后会请求 Godot 场景树加载胜负结算场景。
func go_to_result() -> void:
	_change_scene(RESULT_SCENE, "result")


# 作用：统一执行场景切换，并在失败时输出错误日志。
# 参数：scene_path 是目标场景资源路径；route_name 是便于日志识别的路由名称。
# 返回：无。失败时不会抛出异常，只会通过 push_error 输出错误。
func _change_scene(scene_path: String, route_name: String) -> void:
	print("[SceneRouter] change_scene route=%s path=%s" % [route_name, scene_path])
	var error_code: int = get_tree().change_scene_to_file(scene_path)
	if error_code != OK:
		push_error("[SceneRouter] failed to change scene: %s, error=%d" % [scene_path, error_code])
