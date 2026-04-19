extends StaticBody3D

enum BlockType { STRAIGHT, START, FINISH, BOOSTER, RAMP, CURVE_TIGHT, CURVE_WIDE, STRAIGHT_LONG, CURVE_EXTRA_WIDE }

@export var type: BlockType = BlockType.STRAIGHT
