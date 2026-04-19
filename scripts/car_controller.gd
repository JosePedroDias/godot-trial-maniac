extends RigidBody3D

@export_group("Suspension")
@export var suspension_rest_dist: float = 0.5
@export var spring_strength: float = 50000.0
@export var spring_damping: float = 2000.0
@export var wheel_radius: float = 0.3

@export_group("Engine")
@export var engine_power: float = 20000.0
@export var max_speed: float = 100.0
@export var booster_force: float = 50000.0

@export_group("Steering")
@export var steering_angle: float = 30.0
@export var steering_speed: float = 5.0
@export var grip: float = 20.0

@onready var raycasts = [
	$RayCastFL, $RayCastFR, $RayCastRL, $RayCastRR
]
@onready var wheels = [
	$WheelFL, $WheelFR, $WheelRL, $WheelRR
]

var steering_input = 0.0
var engine_input = 0.0

func _ready():
	# Set up raycasts
	for ray in raycasts:
		ray.target_position = Vector3(0, -(suspension_rest_dist + wheel_radius), 0)
		ray.add_exception(self)

func _physics_process(delta):
	# Out of bounds check
	if global_position.y < -20.0:
		var gm = get_node_or_null("/root/GameManager")
		if gm:
			gm.reset_race()
		return

	engine_input = Input.get_axis("ui_down", "ui_up")
	steering_input = lerp(steering_input, Input.get_axis("ui_right", "ui_left"), steering_speed * delta)
	
	var on_ground = false
	
	for i in range(raycasts.size()):
		var ray = raycasts[i]
		var wheel = wheels[i]
		
		wheel.position.x = ray.position.x
		wheel.position.z = ray.position.z
		
		if ray.is_colliding():
			on_ground = true
			var collider = ray.get_collider()
			var hit_point = ray.get_collision_point()
			var hit_normal = ray.get_collision_normal()
			var dist = (ray.global_position - hit_point).length()
			
			# Block Detection
			if collider.has_method("get_script") and collider.get_script() and collider.get_script().get_path() == "res://scripts/track_block.gd":
				_check_track_block(collider)
			
			# 1. Suspension
			var compression = (suspension_rest_dist + wheel_radius) - dist
			if compression > 0:
				var wheel_velocity = linear_velocity + angular_velocity.cross(ray.global_position - global_position)
				var upward_vel = hit_normal.dot(wheel_velocity)
				var spring_force = compression * spring_strength
				var damping_force = upward_vel * spring_damping
				var total_force = (spring_force - damping_force) * hit_normal
				apply_force(total_force, ray.global_position - global_position)
				
				# 2. Driving
				var wheel_basis = ray.global_basis
				if i < 2:
					wheel_basis = wheel_basis.rotated(global_basis.y, steering_input * deg_to_rad(steering_angle))
				
				var forward_dir = wheel_basis.z
				var right_dir = wheel_basis.x
				
				if abs(engine_input) > 0.05:
					var accel_force = forward_dir * engine_input * engine_power
					apply_force(accel_force, ray.global_position - global_position)
				
				var lateral_vel = right_dir.dot(wheel_velocity)
				var grip_force = -right_dir * lateral_vel * grip * mass
				apply_force(grip_force, ray.global_position - global_position)
				
				wheel.global_position = hit_point + hit_normal * wheel_radius
				wheel.global_basis = wheel_basis.rotated(wheel_basis.z, PI/2.0)
			else:
				wheel.position.y = -suspension_rest_dist
		else:
			wheel.position.y = -suspension_rest_dist
			var wheel_basis = ray.global_basis
			if i < 2:
				wheel_basis = wheel_basis.rotated(global_basis.y, steering_input * deg_to_rad(steering_angle))
			wheel.global_basis = wheel_basis.rotated(wheel_basis.z, PI/2.0)

	if !on_ground:
		var air_torque = Vector3.ZERO
		air_torque.x = Input.get_axis("ui_up", "ui_down") * 15.0
		air_torque.y = Input.get_axis("ui_left", "ui_right") * 15.0
		apply_torque(global_basis * air_torque * mass)

func _check_track_block(block):
	var gm = get_node_or_null("/root/GameManager")
	# BlockType.START = 1, FINISH = 2, BOOSTER = 3
	match block.type:
		1: # START
			if gm: gm.start_race()
		2: # FINISH
			if gm: gm.finish_race()
		3: # BOOSTER
			apply_central_force(global_basis.z * booster_force)
