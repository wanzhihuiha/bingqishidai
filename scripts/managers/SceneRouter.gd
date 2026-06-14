extends Node

const MAIN_MENU_SCENE: String = "res://scenes/menu/MainMenu.tscn"
const SHELTER_SCENE: String = "res://scenes/shelter/ShelterView.tscn"
const WORLD_MAP_SCENE: String = "res://scenes/world/WorldMapView.tscn"
const RESULT_SCENE: String = "res://scenes/ui/ResultView.tscn"


func go_to_main_menu() -> void:
	_change_scene(MAIN_MENU_SCENE, "main_menu")


func go_to_shelter() -> void:
	_change_scene(SHELTER_SCENE, "shelter")


func go_to_world_map() -> void:
	_change_scene(WORLD_MAP_SCENE, "world_map")


func go_to_result() -> void:
	_change_scene(RESULT_SCENE, "result")


func _change_scene(scene_path: String, route_name: String) -> void:
	print("[SceneRouter] change_scene route=%s path=%s" % [route_name, scene_path])
	var error_code: int = get_tree().change_scene_to_file(scene_path)
	if error_code != OK:
		push_error("[SceneRouter] failed to change scene: %s, error=%d" % [scene_path, error_code])
