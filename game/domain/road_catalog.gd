class_name RoadCatalog
extends RefCounted

const STRAIGHT: StringName = &"straight"
const UP_RAMP: StringName = &"up_ramp"
const DOWN_RAMP: StringName = &"down_ramp"
const TURN: StringName = &"turn"
const BRIDGE: StringName = &"bridge"

const ALL_IDS: Array[StringName] = [STRAIGHT, UP_RAMP, DOWN_RAMP, TURN, BRIDGE]


static func get_definition(road_id: StringName) -> RoadDefinition:
	match road_id:
		STRAIGHT:
			return RoadDefinition.new(STRAIGHT, [DirectionRules.Value.LEFT, DirectionRules.Value.RIGHT])
		UP_RAMP:
			return RoadDefinition.new(UP_RAMP, [DirectionRules.Value.LEFT, DirectionRules.Value.UP])
		DOWN_RAMP:
			return RoadDefinition.new(DOWN_RAMP, [DirectionRules.Value.LEFT, DirectionRules.Value.DOWN])
		TURN:
			return RoadDefinition.new(TURN, [DirectionRules.Value.UP, DirectionRules.Value.RIGHT])
		BRIDGE:
			return RoadDefinition.new(
				BRIDGE,
				[DirectionRules.Value.LEFT, DirectionRules.Value.RIGHT],
				[&"bridge"],
			)
		_:
			return null
