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
		var gm = get_node_or_null("/root/GameManager")
		if gm:
			if type == BlockType.START:
				gm.start_race()
			elif type == BlockType.FINISH:
				gm.finish_race(false)
			elif type == BlockType.START_FINISH:
				if gm.current_state == gm.RaceState.PRE_START:
					gm.start_race()
				elif gm.current_state == gm.RaceState.RACING:
					gm.finish_race(true)

func is_sticky() -> bool:
	return type == BlockType.SIDE_PIPE or \
		   type == BlockType.LOOP_360 or type == BlockType.LOOP_90
