extends StaticBody3D

enum BlockType { STRAIGHT, START, FINISH, BOOSTER, RAMP, CURVE_TIGHT, CURVE_WIDE, STRAIGHT_LONG, CURVE_EXTRA_WIDE, SIDE_PIPE_LEFT, SIDE_PIPE_RIGHT, STRAIGHT_LONG_WO_WALLS, LOOP_360, LOOP_90 }

@export var type: BlockType = BlockType.STRAIGHT

func is_sticky() -> bool:
	return type == BlockType.SIDE_PIPE_LEFT or type == BlockType.SIDE_PIPE_RIGHT or \
		   type == BlockType.LOOP_360 or type == BlockType.LOOP_90
