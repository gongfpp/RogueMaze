class_name ContentRegistry
extends RefCounted

const DEFAULT_PATH := "res://game/content/data/gameplay.json"
const SCHEMA_VERSION := 1
const BOARD_SIZE := Vector2i(8, 5)

var roads: Dictionary = {}
var nodes: Array[Dictionary] = []
var starter_deck: Array[StringName] = []
var errors: Array[String] = []

static var _default_registry


static func default_registry() -> ContentRegistry:
	if _default_registry == null:
		_default_registry = load_file(DEFAULT_PATH)
		assert(_default_registry.is_valid(), "Default gameplay content is invalid: %s" % "; ".join(_default_registry.errors))
	return _default_registry


static func load_file(path: String) -> ContentRegistry:
	var registry := ContentRegistry.new()
	if not FileAccess.file_exists(path):
		registry.errors.append("Content file not found: %s" % path)
		return registry
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		registry.errors.append("Content file could not be opened: %s" % path)
		return registry
	var parser := JSON.new()
	var parse_error := parser.parse(file.get_as_text())
	if parse_error != OK:
		registry.errors.append("Invalid JSON at line %d: %s" % [parser.get_error_line(), parser.get_error_message()])
		return registry
	return from_data(parser.data, registry)


static func from_data(data: Variant, registry: ContentRegistry = null) -> ContentRegistry:
	var result := registry if registry != null else ContentRegistry.new()
	if not data is Dictionary:
		result.errors.append("Content root must be an object")
		return result
	result._read(data)
	return result


func is_valid() -> bool:
	return errors.is_empty()


func road_definition(road_id: StringName) -> RoadDefinition:
	if not roads.has(road_id):
		return null
	var record: Dictionary = roads[road_id]
	return RoadDefinition.new(road_id, record.ports, record.keywords)


func road_label(road_id: StringName) -> String:
	return roads.get(road_id, {}).get("label", String(road_id).to_upper())


func node(node_index: int) -> Dictionary:
	if node_index < 0 or node_index >= nodes.size():
		return {}
	return nodes[node_index]


func _read(data: Dictionary) -> void:
	if data.get("schema_version") != SCHEMA_VERSION:
		errors.append("Unsupported schema_version; expected %d" % SCHEMA_VERSION)
	_read_roads(data.get("roads", []))
	var expedition: Variant = data.get("expedition", {})
	if not expedition is Dictionary:
		errors.append("expedition must be an object")
		return
	_read_starter_deck(expedition.get("starter_deck", []))
	_read_nodes(expedition.get("nodes", []))


func _read_roads(records: Variant) -> void:
	if not records is Array or records.is_empty():
		errors.append("roads must be a non-empty array")
		return
	for value in records:
		if not value is Dictionary:
			errors.append("Every road must be an object")
			continue
		var road_id := StringName(String(value.get("id", "")))
		if road_id == &"":
			errors.append("Road id cannot be empty")
			continue
		if roads.has(road_id):
			errors.append("Duplicate road id: %s" % road_id)
			continue
		var ports := _parse_ports(value.get("ports", []), road_id)
		var keywords: Array[StringName] = []
		var raw_keywords: Variant = value.get("keywords", [])
		if raw_keywords is Array:
			for keyword in raw_keywords:
				keywords.append(StringName(String(keyword)))
		else:
			errors.append("Road %s keywords must be an array" % road_id)
		roads[road_id] = {
			"label": String(value.get("label", String(road_id).to_upper())),
			"ports": ports,
			"keywords": keywords,
			"rarity": StringName(String(value.get("rarity", "COMMON"))),
		}


func _parse_ports(values: Variant, road_id: StringName) -> Array[int]:
	var result: Array[int] = []
	if not values is Array or values.size() < 2:
		errors.append("Road %s needs at least two ports" % road_id)
		return result
	for value in values:
		var direction := _direction_from_name(String(value))
		if direction < 0:
			errors.append("Road %s has unknown direction: %s" % [road_id, value])
		elif direction in result:
			errors.append("Road %s repeats direction: %s" % [road_id, value])
		else:
			result.append(direction)
	return result


func _read_starter_deck(values: Variant) -> void:
	if not values is Array or values.is_empty():
		errors.append("starter_deck must be a non-empty array")
		return
	for value in values:
		var road_id := StringName(String(value))
		if not roads.has(road_id):
			errors.append("starter_deck references unknown road: %s" % road_id)
		else:
			starter_deck.append(road_id)


func _read_nodes(values: Variant) -> void:
	if not values is Array or values.is_empty():
		errors.append("nodes must be a non-empty array")
		return
	var ids: Array[StringName] = []
	for value in values:
		if not value is Dictionary:
			errors.append("Every node must be an object")
			continue
		var node_id := StringName(String(value.get("id", "")))
		if node_id == &"" or node_id in ids:
			errors.append("Node id must be non-empty and unique: %s" % node_id)
			continue
		ids.append(node_id)
		var hazards := _parse_hazards(value.get("hazards", []), node_id)
		var rewards: Array[StringName] = []
		var raw_rewards: Variant = value.get("reward_pool", [])
		if not raw_rewards is Array:
			errors.append("Node %s reward_pool must be an array" % node_id)
		else:
			for reward in raw_rewards:
				var road_id := StringName(String(reward))
				if not roads.has(road_id):
					errors.append("Node %s rewards unknown road: %s" % [node_id, road_id])
				else:
					rewards.append(road_id)
		nodes.append({
			"id": node_id,
			"title": String(value.get("title", String(node_id).to_upper())),
			"hazards": hazards,
			"reward_pool": rewards,
		})
	for index in maxi(0, nodes.size() - 1):
		if nodes[index].reward_pool.is_empty():
			errors.append("Non-final node %s needs a reward_pool" % nodes[index].id)


func _parse_hazards(values: Variant, node_id: StringName) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not values is Array:
		errors.append("Node %s hazards must be an array" % node_id)
		return result
	for value in values:
		if not value is Dictionary:
			errors.append("Node %s has a non-object hazard" % node_id)
			continue
		var type := StringName(String(value.get("type", "")))
		var raw_position: Variant = value.get("position", [])
		if type not in [&"SPIKES", &"FALLING_ROCK"]:
			errors.append("Node %s has unknown hazard: %s" % [node_id, type])
			continue
		if not raw_position is Array or raw_position.size() != 2:
			errors.append("Node %s hazard position must be [x, y]" % node_id)
			continue
		var position := Vector2i(int(raw_position[0]), int(raw_position[1]))
		if position.x < 0 or position.x >= BOARD_SIZE.x or position.y < 0 or position.y >= BOARD_SIZE.y:
			errors.append("Node %s hazard is outside the board: %s" % [node_id, position])
			continue
		var hazard := {"type": type, "position": position}
		if type == &"SPIKES":
			hazard.damage = maxi(1, int(value.get("damage", 1)))
		else:
			hazard.timer = maxf(0.1, float(value.get("timer", 8.0)))
		result.append(hazard)
	return result


func _direction_from_name(value: String) -> int:
	match value.to_upper():
		"UP": return DirectionRules.Value.UP
		"RIGHT": return DirectionRules.Value.RIGHT
		"DOWN": return DirectionRules.Value.DOWN
		"LEFT": return DirectionRules.Value.LEFT
		_: return -1
