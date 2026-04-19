extends StaticBody3D

enum BlockType { STRAIGHT, START, FINISH, BOOSTER, RAMP, CURVE }

@export var type: BlockType = BlockType.STRAIGHT
