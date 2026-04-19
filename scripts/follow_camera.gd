extends Camera3D

@export var target_path: NodePath
@export var offset: Vector3 = Vector3(0, 2, -5)
@export var lerp_speed: float = 5.0

var target: Node3D
var smoothed_basis: Basis

func _ready():
	if target_path:
		target = get_node(target_path)
		smoothed_basis = target.global_basis

func _physics_process(delta):
	if target:
		# Smoothly interpolate the basis to filter out physics jitter
		# This prevents the camera from twitching when the car is moving slowly or resting
		smoothed_basis = smoothed_basis.slerp(target.global_basis, 10.0 * delta)
		
		var target_pos = target.global_position + smoothed_basis * offset
		global_position = global_position.lerp(target_pos, lerp_speed * delta)
		
		# Look further ahead to stabilize the rotation
		var look_target = target.global_position + smoothed_basis.z * 5.0
		look_at(look_target)
