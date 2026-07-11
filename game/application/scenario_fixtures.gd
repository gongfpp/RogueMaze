class_name ScenarioFixtures
extends RefCounted


static func all() -> Array[Dictionary]:
	return [
		{
			"id": &"flat_success",
			"title": "三张直路抵达终点",
			"board_size": Vector2i(4, 1),
			"start": {"road_id": RoadCatalog.STRAIGHT, "position": Vector2i(0, 0)},
			"finish": Vector2i(3, 0),
			"deck": {"cards": [RoadCatalog.STRAIGHT]},
			"placements": [
				{"position": Vector2i(1, 0)},
				{"position": Vector2i(2, 0)},
				{"position": Vector2i(3, 0)},
			],
			"expected": {"outcome": RunSimulator.WIN, "turn": 3},
		},
		{
			"id": &"climb_success",
			"title": "用两张坡道爬到上一层",
			"board_size": Vector2i(3, 2),
			"start": {"road_id": RoadCatalog.STRAIGHT, "position": Vector2i(0, 1)},
			"finish": Vector2i(2, 0),
			"deck": {
				"cards": [RoadCatalog.UP_RAMP, RoadCatalog.UP_RAMP, RoadCatalog.STRAIGHT],
			},
			"placements": [
				{"position": Vector2i(1, 1)},
				{"position": Vector2i(1, 0), "quarter_turns": 2},
				{"position": Vector2i(2, 0)},
			],
			"expected": {"outcome": RunSimulator.WIN, "turn": 3},
		},
		{
			"id": &"broken_failure",
			"title": "竖直道路挡住水平出口",
			"board_size": Vector2i(3, 2),
			"start": {"road_id": RoadCatalog.STRAIGHT, "position": Vector2i(0, 0)},
			"finish": Vector2i(2, 0),
			"deck": {"cards": [RoadCatalog.STRAIGHT]},
			"placements": [{"position": Vector2i(1, 0), "quarter_turns": 1}],
			"expected": {
				"outcome": RunSimulator.PLACEMENT_FAILED,
				"reason": BoardState.PORT_MISMATCH,
				"turn": 1,
			},
		},
	]
