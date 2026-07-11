class_name CardState
extends RefCounted

const MAX_LEVEL := 2

var instance_id: int
var road_id: StringName
var level: int


func _init(p_instance_id: int, p_road_id: StringName, p_level: int = 1) -> void:
	assert(p_instance_id > 0, "Card instance id must be positive")
	assert(RoadCatalog.get_definition(p_road_id) != null, "Card must reference a known road")
	instance_id = p_instance_id
	road_id = p_road_id
	level = clampi(p_level, 1, MAX_LEVEL)


func can_upgrade() -> bool:
	return level < MAX_LEVEL


func upgrade() -> bool:
	if not can_upgrade():
		return false
	level += 1
	return true


func level_suffix() -> String:
	return "+" if level > 1 else ""
