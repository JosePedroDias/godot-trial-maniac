extends Camera3D

@export var target_path: NodePath
@export var offset: Vector3 = Vector3(0, 2, -5)
@export var lerp_speed: float = 5.0

var target: Node3D

func _ready():
	if target_path:
		target = get_node(target_path)

func _physics_process(delta):
	if target:
		var target_pos = target.global_position + target.global_basis * offset
		global_position = global_position.lerp(target_pos, lerp_speed * delta)
		look_at(target.global_position + target.global_basis.z * 2.0)
