class_name RoadDefinition
extends RefCounted

var id: StringName
var base_ports: Array[int]
var keywords: Array[StringName]


func _init(
	p_id: StringName,
	p_base_ports: Array,
	p_keywords: Array = [],
) -> void:
	id = p_id
	base_ports.assign(p_base_ports)
	keywords.assign(p_keywords)


func rotated_ports(quarter_turns: int = 0) -> Array[int]:
	var result: Array[int] = []
	for port in base_ports:
		result.append(DirectionRules.rotate(port, quarter_turns))
	return result
