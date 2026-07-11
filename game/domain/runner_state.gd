class_name RunnerState
extends RefCounted

const RUNNING: StringName = &"RUNNING"
const WAITING: StringName = &"WAITING"
const FAILED: StringName = &"FAILED"
const REACHED: StringName = &"REACHED"

var current_position: Vector2i
var previous_position: Vector2i
var has_previous := false
var target_position: Vector2i
var has_target := false
var progress := 0.0
var speed_cells_per_second: float
var blocked_grace_seconds: float
var blocked_remaining: float
var status: StringName = WAITING
var entered_cell := false
var last_entered_position: Vector2i


func _init(
	start_position: Vector2i,
	speed: float = 0.65,
	blocked_grace: float = 1.75,
) -> void:
	current_position = start_position
	speed_cells_per_second = speed
	blocked_grace_seconds = blocked_grace
	blocked_remaining = blocked_grace


func update(delta: float, board: BoardState, finish: Vector2i) -> void:
	entered_cell = false
	if status == FAILED or status == REACHED:
		return
	if current_position == finish:
		status = REACHED
		return

	if not has_target:
		var next := _find_next(board)
		if next.ok:
			target_position = next.position
			has_target = true
			status = RUNNING
		else:
			status = WAITING
			blocked_remaining -= delta
			if blocked_remaining <= 0.0:
				status = FAILED
			return

	progress += speed_cells_per_second * delta
	if progress < 1.0:
		return

	previous_position = current_position
	has_previous = true
	current_position = target_position
	last_entered_position = current_position
	entered_cell = true
	has_target = false
	progress = 0.0
	blocked_remaining = blocked_grace_seconds
	if current_position == finish:
		status = REACHED


func display_position() -> Vector2:
	if not has_target:
		return Vector2(current_position)
	return Vector2(current_position).lerp(Vector2(target_position), progress)


func _find_next(board: BoardState) -> Dictionary:
	var current := board.road_at(current_position)
	if current.is_empty():
		return {"ok": false}

	var preferred_directions: Array[int] = [
		DirectionRules.Value.RIGHT,
		DirectionRules.Value.UP,
		DirectionRules.Value.DOWN,
		DirectionRules.Value.LEFT,
	]
	for direction in preferred_directions:
		if not current.ports.has(direction):
			continue
		var candidate := current_position + DirectionRules.vector(direction)
		if has_previous and candidate == previous_position:
			continue
		var neighbor := board.road_at(candidate)
		if neighbor.is_empty():
			continue
		if neighbor.ports.has(DirectionRules.opposite(direction)):
			return {"ok": true, "position": candidate}
	return {"ok": false}
