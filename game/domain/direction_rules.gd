class_name DirectionRules
extends RefCounted

enum Value {
	LEFT,
	UP,
	RIGHT,
	DOWN,
}

const ORDER: Array[int] = [Value.LEFT, Value.UP, Value.RIGHT, Value.DOWN]
const VECTORS := {
	Value.LEFT: Vector2i.LEFT,
	Value.UP: Vector2i.UP,
	Value.RIGHT: Vector2i.RIGHT,
	Value.DOWN: Vector2i.DOWN,
}

static func normalize_quarter_turns(quarter_turns: int) -> int:
	return posmod(quarter_turns, 4)


static func rotate(direction: int, quarter_turns: int) -> int:
	var start_index := ORDER.find(direction)
	assert(start_index >= 0, "Unknown direction: %s" % direction)
	return ORDER[(start_index + normalize_quarter_turns(quarter_turns)) % ORDER.size()]


static func opposite(direction: int) -> int:
	return rotate(direction, 2)


static func vector(direction: int) -> Vector2i:
	assert(VECTORS.has(direction), "Unknown direction: %s" % direction)
	return VECTORS[direction]
