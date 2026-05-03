extends StaticBody3D

enum BlockType { STRAIGHT, START, FINISH, BOOSTER, RAMP, CURVE_TIGHT, CURVE_WIDE, STRAIGHT_LONG, CURVE_EXTRA_WIDE, SIDE_PIPE, STRAIGHT_LONG_WO_WALLS, LOOP_360, LOOP_90, START_FINISH }

@export var type: BlockType = BlockType.STRAIGHT

func _ready():
	if type == BlockType.START or type == BlockType.FINISH or type == BlockType.START_FINISH:
		var area = get_node_or_null("Gate/DetectionArea")
		if area:
			area.body_entered.connect(_on_gate_body_entered)

func _on_gate_body_entered(body):
	if body.name == "Car":
		if GameManager:
			if type == BlockType.START:
				GameManager.start_race()
			elif type == BlockType.FINISH:
				GameManager.finish_race(false)
			elif type == BlockType.START_FINISH:
				if GameManager.current_state == GameManager.RaceState.PRE_START:
					GameManager.start_race()
				elif GameManager.current_state == GameManager.RaceState.RACING:
					GameManager.finish_race(true)

func is_sticky() -> bool:
	return type == BlockType.SIDE_PIPE or \
		   type == BlockType.LOOP_360 or type == BlockType.LOOP_90
