extends Camera3D

@export var target_distance: float = 100.0
@export var min_distance: float = 5.0
@export var max_distance: float = 2000.0
@export var zoom_speed: float = 1.2
@export var rotate_speed: float = 0.005
@export var pan_speed: float = 0.5

var orbit_center: Vector3 = Vector3.ZERO
var rotation_angles: Vector2 = Vector2(-0.5, 0.7) # Elevation, Azimuth

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_update_transform()

func _input(event):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			target_distance /= zoom_speed
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			target_distance *= zoom_speed
		target_distance = clamp(target_distance, min_distance, max_distance)

	if event is InputEventMouseMotion:
		if event.button_mask & MOUSE_BUTTON_MASK_LEFT:
			# Orbit
			rotation_angles.y -= event.relative.x * rotate_speed
			rotation_angles.x -= event.relative.y * rotate_speed
			rotation_angles.x = clamp(rotation_angles.x, -PI/2 + 0.1, PI/2 - 0.1)
		
		elif event.button_mask & MOUSE_BUTTON_MASK_RIGHT:
			# Pan
			var forward = -transform.basis.z.normalized()
			var right = transform.basis.x.normalized()
			var up = transform.basis.y.normalized()
			
			# Project pan onto horizontal plane for more intuitive track navigation
			var pan_vec = (right * -event.relative.x + up * event.relative.y) * pan_speed * (target_distance / 500.0)
			orbit_center += pan_vec

	_update_transform()

func _update_transform():
	var offset = Vector3(
		target_distance * cos(rotation_angles.x) * sin(rotation_angles.y),
		target_distance * sin(rotation_angles.x),
		target_distance * cos(rotation_angles.x) * cos(rotation_angles.y)
	)
	
	global_position = orbit_center + offset
	look_at(orbit_center)

func center_on(aabb: AABB):
	orbit_center = aabb.get_center()
	target_distance = aabb.size.length() * 0.8
	_update_transform()
