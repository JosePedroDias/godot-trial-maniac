extends Camera3D

@export var target_path: NodePath
@export var offset: Vector3 = Vector3(0, 2, -5)
@export var lerp_speed: float = 5.0

var target: Node3D
var smoothed_basis: Basis

# Buffer for averaging (2 frames)
var pos_history = []
var basis_history = []

func _ready():
	if target_path:
		target = get_node(target_path)
		smoothed_basis = target.global_basis
		# Initialize history
		for i in range(2):
			pos_history.append(target.global_position)
			basis_history.append(target.global_basis)

func _physics_process(delta):
	if target:
		# 1. Update History (FIFO buffer of size 2)
		pos_history.append(target.global_position)
		basis_history.append(target.global_basis)
		pos_history.pop_front()
		basis_history.pop_front()
		
		# 2. Average the historical data
		var avg_pos = (pos_history[0] + pos_history[1]) / 2.0
		var avg_basis = basis_history[0].slerp(basis_history[1], 0.5)
		
		# 3. Smooth the averaged basis over time
		smoothed_basis = smoothed_basis.slerp(avg_basis, 10.0 * delta)
		
		# 4. Calculate camera target position relative to averaged/smoothed state
		var target_pos = avg_pos + smoothed_basis * offset
		global_position = global_position.lerp(target_pos, lerp_speed * delta)
		
		# 5. Look further ahead to stabilize rotation
		var look_target = avg_pos + smoothed_basis.z * 5.0
		look_at(look_target)
