extends StaticBody3D

enum SurfaceType { STRAIGHT, START, FINISH, BOOSTER, RAMP, CURVE_TIGHT, CURVE_WIDE, STRAIGHT_LONG, CURVE_EXTRA_WIDE, SIDE_PIPE, STRAIGHT_LONG_WO_WALLS, LOOP_360, LOOP_90, START_FINISH }

@export var type: SurfaceType = SurfaceType.STRAIGHT

func _ready():
	if type == SurfaceType.START or type == SurfaceType.FINISH or type == SurfaceType.START_FINISH:
		var area = get_node_or_null("Gate/DetectionArea")
		if area:
			area.body_entered.connect(_on_gate_body_entered)

func _on_gate_body_entered(body):
	if body.name == "Car":
		if GameManager:
			if type == SurfaceType.START:
				GameManager.start_race()
			elif type == SurfaceType.FINISH:
				GameManager.finish_race(false)
			elif type == SurfaceType.START_FINISH:
				if GameManager.current_state == GameManager.RaceState.PRE_START:
					GameManager.start_race()
				elif GameManager.current_state == GameManager.RaceState.RACING:
					GameManager.finish_race(true)

func is_sticky() -> bool:
	return type == SurfaceType.SIDE_PIPE or \
		   type == SurfaceType.LOOP_360 or type == SurfaceType.LOOP_90
