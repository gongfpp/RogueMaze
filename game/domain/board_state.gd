class_name BoardState
extends RefCounted

const OUT_OF_BOUNDS: StringName = &"OUT_OF_BOUNDS"
const OCCUPIED: StringName = &"OCCUPIED"
const PORT_MISMATCH: StringName = &"PORT_MISMATCH"
const ISOLATED: StringName = &"ISOLATED"

var width: int
var height: int
var roads: Dictionary = {}


func _init(p_width: int, p_height: int) -> void:
	assert(p_width > 0 and p_height > 0, "Board dimensions must be positive")
	width = p_width
	height = p_height


func is_inside(position: Vector2i) -> bool:
	return position.x >= 0 and position.y >= 0 and position.x < width and position.y < height


func road_at(position: Vector2i) -> Dictionary:
	return roads.get(position, {})


func validate_placement(
	definition: RoadDefinition,
	position: Vector2i,
	quarter_turns: int = 0,
	allow_isolated: bool = false,
) -> Dictionary:
	if not is_inside(position):
		return {"ok": false, "reason": OUT_OF_BOUNDS}
	if roads.has(position):
		return {"ok": false, "reason": OCCUPIED}

	var ports := definition.rotated_ports(quarter_turns)
	var matching_connections := 0
	for direction in DirectionRules.ORDER:
		var neighbor_position := position + DirectionRules.vector(direction)
		if not roads.has(neighbor_position):
			continue
		var neighbor: Dictionary = roads[neighbor_position]
		var this_opens := ports.has(direction)
		var neighbor_opens: bool = neighbor.ports.has(DirectionRules.opposite(direction))
		if this_opens != neighbor_opens:
			return {
				"ok": false,
				"reason": PORT_MISMATCH,
				"direction": direction,
				"neighbor_position": neighbor_position,
			}
		if this_opens:
			matching_connections += 1

	if not allow_isolated and matching_connections == 0:
		return {"ok": false, "reason": ISOLATED}
	return {"ok": true, "matching_connections": matching_connections}


func place(
	definition: RoadDefinition,
	position: Vector2i,
	quarter_turns: int = 0,
	allow_isolated: bool = false,
) -> Dictionary:
	var validation := validate_placement(definition, position, quarter_turns, allow_isolated)
	if not validation.ok:
		return validation

	var placed_road := {
		"definition": definition,
		"position": position,
		"quarter_turns": DirectionRules.normalize_quarter_turns(quarter_turns),
		"ports": definition.rotated_ports(quarter_turns),
	}
	roads[position] = placed_road
	return {
		"ok": true,
		"road": placed_road,
		"matching_connections": validation.matching_connections,
	}


func are_connected(start: Vector2i, finish: Vector2i) -> bool:
	if not roads.has(start) or not roads.has(finish):
		return false

	var visited := {start: true}
	var queue: Array[Vector2i] = [start]
	while not queue.is_empty():
		var current_position: Vector2i = queue.pop_front()
		if current_position == finish:
			return true
		var current: Dictionary = roads[current_position]
		for direction in current.ports:
			var neighbor_position := current_position + DirectionRules.vector(direction)
			if not roads.has(neighbor_position):
				continue
			var neighbor: Dictionary = roads[neighbor_position]
			if not neighbor.ports.has(DirectionRules.opposite(direction)):
				continue
			if not visited.has(neighbor_position):
				visited[neighbor_position] = true
				queue.append(neighbor_position)
	return false
