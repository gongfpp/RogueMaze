class_name PersistenceService
extends RefCounted

const SETTINGS_VERSION := 1
const PROGRESS_VERSION := 1

var settings_path: String
var progress_path: String
var settings: Dictionary
var progress: Dictionary


func _init(
	p_settings_path: String = "user://settings.json",
	p_progress_path: String = "user://progress.json",
) -> void:
	settings_path = p_settings_path
	progress_path = p_progress_path
	settings = default_settings()
	progress = default_progress()


static func default_settings() -> Dictionary:
	return {
		"version": SETTINGS_VERSION,
		"sfx_enabled": true,
		"reduced_motion": false,
	}


static func default_progress() -> Dictionary:
	return {
		"version": PROGRESS_VERSION,
		"expeditions_won": 0,
		"best_node": 0,
		"unlocked_roads": [String(RoadCatalog.STRAIGHT), String(RoadCatalog.UP_RAMP), String(RoadCatalog.DOWN_RAMP)],
	}


func load_all() -> void:
	settings = sanitize_settings(_load_json(settings_path))
	progress = sanitize_progress(_load_json(progress_path))


func save_settings() -> bool:
	settings = sanitize_settings(settings)
	return _save_json_atomic(settings_path, settings)


func save_progress() -> bool:
	progress = sanitize_progress(progress)
	return _save_json_atomic(progress_path, progress)


func save_all() -> bool:
	var settings_saved := save_settings()
	var progress_saved := save_progress()
	return settings_saved and progress_saved


func record_node_cleared(node_number: int) -> bool:
	progress.best_node = maxi(progress.best_node, clampi(node_number, 0, GameSession.NODE_COUNT))
	return save_progress()


func record_expedition_win() -> bool:
	progress.expeditions_won += 1
	progress.best_node = GameSession.NODE_COUNT
	return save_progress()


static func sanitize_settings(data: Variant) -> Dictionary:
	var result := default_settings()
	if data is not Dictionary:
		return result
	var sfx_value: Variant = data.get("sfx_enabled", result.sfx_enabled)
	if sfx_value is bool:
		result.sfx_enabled = sfx_value
	var motion_value: Variant = data.get("reduced_motion", result.reduced_motion)
	if motion_value is bool:
		result.reduced_motion = motion_value
	return result


static func sanitize_progress(data: Variant) -> Dictionary:
	var result := default_progress()
	if data is not Dictionary:
		return result
	var wins: Variant = data.get("expeditions_won", 0)
	if wins is float or wins is int:
		result.expeditions_won = maxi(0, int(wins))
	var best: Variant = data.get("best_node", 0)
	if best is float or best is int:
		result.best_node = clampi(int(best), 0, GameSession.NODE_COUNT)
	var unlocked: Variant = data.get("unlocked_roads", result.unlocked_roads)
	if unlocked is Array:
		var valid_ids: Array[String] = []
		for road_id in unlocked:
			var candidate := StringName(String(road_id))
			if candidate in RoadCatalog.ALL_IDS and String(candidate) not in valid_ids:
				valid_ids.append(String(candidate))
		if not valid_ids.is_empty():
			result.unlocked_roads = valid_ids
	return result


func _load_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return null
	var text := file.get_as_text()
	file.close()
	var json := JSON.new()
	if json.parse(text) != OK:
		return null
	return json.data


func _save_json_atomic(path: String, data: Dictionary) -> bool:
	var absolute_target := ProjectSettings.globalize_path(path)
	var absolute_temp := absolute_target + ".tmp"
	var absolute_backup := absolute_target + ".bak"
	var directory := absolute_target.get_base_dir()
	if DirAccess.make_dir_recursive_absolute(directory) != OK:
		return false

	var file := FileAccess.open(absolute_temp, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(data, "\t"))
	file.flush()
	file.close()

	if FileAccess.file_exists(absolute_backup):
		DirAccess.remove_absolute(absolute_backup)
	if FileAccess.file_exists(absolute_target):
		if DirAccess.rename_absolute(absolute_target, absolute_backup) != OK:
			DirAccess.remove_absolute(absolute_temp)
			return false
	if DirAccess.rename_absolute(absolute_temp, absolute_target) != OK:
		if FileAccess.file_exists(absolute_backup):
			DirAccess.rename_absolute(absolute_backup, absolute_target)
		return false
	if FileAccess.file_exists(absolute_backup):
		DirAccess.remove_absolute(absolute_backup)
	return true
