extends Camera3D

enum Mode { FOLLOW_NEAR, FOLLOW_MEDIUM, FOLLOW_FAR, FIXED_TOP }
@export var mode: Mode = Mode.FOLLOW_MEDIUM
@export var target_path: NodePath
@onready var target = get_node_or_null(target_path)

var _target_pos: Vector3
var _target_rot: Basis
var _fixed_center: Vector3 = Vector3.ZERO
var _calculated_center: bool = false

func _ready():
	if not target:
		var p = get_parent()
		if p: target = p.get_node_or_null("Car")

func toggle_mode():
	mode = (mode + 1) % len(Mode) as Mode
	print("Camera Mode: ", Mode.keys()[mode])

var _smooth_forward: Vector3 = Vector3.FORWARD

func _process(delta):
	if not is_instance_valid(target):
		var p = get_parent()
		if p: target = p.get_node_or_null("Car")
		if not target: return

	match mode:
		# (delta, distance, height, pos_smooth, rot_smooth):
		Mode.FOLLOW_NEAR:
			_follow_logic(delta, 5.0, 4.0, 4.0, 36.0)
		Mode.FOLLOW_MEDIUM:
			_follow_logic(delta, 10.0, 9.0, 2.0, 24.0)
		Mode.FOLLOW_FAR:
			_follow_logic(delta, 25.0, 20.0, 1.0, 12.0)
		Mode.FIXED_TOP:
			_fixed_logic(delta)

func _follow_logic(delta, distance, height, pos_smooth, rot_smooth):
	var target_pos = target.global_transform.origin
	var car_fwd = target.global_transform.basis.z
	
	# Use velocity to help guide the camera direction if moving fast enough
	# This makes the camera follow the 'path' rather than every tiny steering wiggle
	var velocity = Vector3.ZERO
	if target is RigidBody3D:
		velocity = target.linear_velocity
	
	var vel_fwd = velocity.normalized()
	var speed = velocity.length()
	
	# Blend car orientation and velocity direction
	var target_fwd = car_fwd
	if speed > 5.0:
		var vel_factor = clamp((speed - 5.0) / 20.0, 0.0, 0.7)
		target_fwd = car_fwd.lerp(vel_fwd, vel_factor).normalized()
	
	# Smoothly update the camera's internal forward vector
	_smooth_forward = _smooth_forward.lerp(target_fwd, rot_smooth * delta).normalized()
	
	var desired_pos = target_pos - _smooth_forward * distance + Vector3.UP * height
	global_position = global_position.lerp(desired_pos, pos_smooth * delta)
	
	# Look at a point slightly ahead of the car using the smooth forward
	var look_target = target_pos + _smooth_forward * 4.0
	var new_transform = transform.looking_at(look_target, Vector3.UP)
	global_basis = global_basis.slerp(new_transform.basis, rot_smooth * delta)

func _fixed_logic(delta):
	if not _calculated_center:
		_calculate_track_center()
	
	# Stay high up at center, look at car
	# Adjust height based on track size if possible, or just keep it very high
	var desired_pos = _fixed_center + Vector3.UP * 60.0 
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
