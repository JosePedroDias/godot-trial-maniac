extends StaticBody3D

enum BlockType { STRAIGHT, START, FINISH, BOOSTER, RAMP, CURVE_TIGHT, CURVE_WIDE, STRAIGHT_LONG, CURVE_EXTRA_WIDE, SIDE_PIPE, STRAIGHT_LONG_WO_WALLS, LOOP_360, LOOP_90 }

@export var type: BlockType = BlockType.STRAIGHT

func is_sticky() -> bool:
	return type == BlockType.SIDE_PIPE or \
		   type == BlockType.LOOP_360 or type == BlockType.LOOP_90
