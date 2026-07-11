class_name RoadCatalog
extends RefCounted

const STRAIGHT: StringName = &"straight"
const UP_RAMP: StringName = &"up_ramp"
const DOWN_RAMP: StringName = &"down_ramp"
const TURN: StringName = &"turn"
const BRIDGE: StringName = &"bridge"

const ALL_IDS: Array[StringName] = [STRAIGHT, UP_RAMP, DOWN_RAMP, TURN, BRIDGE]


static func get_definition(road_id: StringName) -> RoadDefinition:
	return ContentRegistry.default_registry().road_definition(road_id)


static func get_label(road_id: StringName) -> String:
	return ContentRegistry.default_registry().road_label(road_id)
