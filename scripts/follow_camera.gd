extends Camera3D

enum Mode { FOLLOW, FAR, TOP_FIXED }
@export var mode: Mode = Mode.FOLLOW
@export var target_path: NodePath
@onready var target = get_node_or_null(target_path)

var _target_pos: Vector3
var _target_rot: Basis
var _fixed_center: Vector3 = Vector3.ZERO
var _calculated_center: bool = false

func _ready():
	if not target:
		target = get_parent().get_node_or_null("Car")

func toggle_mode():
	mode = (mode + 1) % 3 as Mode
	print("Camera Mode: ", Mode.keys()[mode])

func _process(delta):
	if not is_instance_valid(target):
		target = get_parent().get_node_or_null("Car")
		if not target: return

	match mode:
		Mode.FOLLOW:
			_follow_logic(delta, 5.0, 2.5, 8.0)
		Mode.FAR:
			_follow_logic(delta, 12.0, 6.0, 4.0)
		Mode.TOP_FIXED:
			_top_fixed_logic(delta)

func _follow_logic(delta, distance, height, smoothness):
	var target_pos = target.global_transform.origin
	# In this project, +Z is forward for the car
	var forward = target.global_transform.basis.z
	
	var desired_pos = target_pos - forward * distance + Vector3.UP * height
	global_position = global_position.lerp(desired_pos, smoothness * delta)
	
	# Look at a point slightly ahead of the car
	var look_target = target_pos + forward * 4.0
	var new_transform = transform.looking_at(look_target, Vector3.UP)
	global_basis = global_basis.slerp(new_transform.basis, smoothness * delta)

func _top_fixed_logic(delta):
	if not _calculated_center:
		_calculate_track_center()
	
	# Stay high up at center, look at car
	# Adjust height based on track size if possible, or just keep it very high
	var desired_pos = _fixed_center + Vector3.UP * 250.0 
	global_position = global_position.lerp(desired_pos, 2.0 * delta)
	
	var new_transform = transform.looking_at(target.global_position, Vector3.UP)
	global_basis = global_basis.slerp(new_transform.basis, 5.0 * delta)

func _calculate_track_center():
	var track_node = get_parent().get_node_or_null("Track")
	if track_node:
		var center = Vector3.ZERO
		var count = 0
		# Average the positions of all road blocks/meshes
		for child in track_node.get_children():
			if child is MeshInstance3D:
				center += child.global_position
				count += 1
		
		if count > 0:
			_fixed_center = center / count
			_calculated_center = true
		else:
			_fixed_center = target.global_position
	else:
		_fixed_center = target.global_position
