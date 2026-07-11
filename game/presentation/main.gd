extends Control

@onready var result_label: Label = %ResultLabel
@onready var run_button: Button = %RunButton


func _ready() -> void:
	run_button.pressed.connect(_run_rule_demo)


func _run_rule_demo() -> void:
	var lines: Array[String] = []
	for scenario in ScenarioFixtures.all():
		var result := RunSimulator.simulate(scenario)
		var suffix := ""
		if not String(result.reason).is_empty():
			suffix = " · %s" % result.reason
		lines.append("%s：%s（第 %d 回合）%s" % [
			scenario.title,
			result.outcome,
			result.turn,
			suffix,
		])
	result_label.text = "\n".join(lines)
