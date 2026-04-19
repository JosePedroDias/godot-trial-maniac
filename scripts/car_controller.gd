extends RigidBody3D

@export_group("Suspension")
@export var suspension_rest_dist: float = 0.5
@export var spring_strength: float = 300.0
@export var spring_damping: float = 15.0
@export var wheel_radius: float = 0.3

@export_group("Engine")
@export var engine_power: float = 2000.0
@export var braking_power: float = 1000.0
@export var max_speed: float = 100.0

@export_group("Steering")
@export var steering_angle: float = 30.0
@export var steering_speed: float = 5.0
@export var grip: float = 5.0

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
	engine_input = Input.get_axis("ui_down", "ui_up")
	steering_input = lerp(steering_input, Input.get_axis("ui_right", "ui_left"), steering_speed * delta)
	
	for i in range(raycasts.size()):
		var ray = raycasts[i]
		var wheel = wheels[i]
		
		if ray.is_colliding():
			var hit_point = ray.get_collision_point()
			var hit_normal = ray.get_collision_normal()
			var dist = (ray.global_position - hit_point).length()
			
			# 1. Suspension Force
			var compression = (suspension_rest_dist + wheel_radius) - dist
			if compression > 0:
				var wheel_velocity = linear_velocity + angular_velocity.cross(ray.global_position - global_position)
				var upward_vel = hit_normal.dot(wheel_velocity)
				var spring_force = compression * spring_strength
				var damping_force = upward_vel * spring_damping
				var total_force = (spring_force - damping_force) * hit_normal
				
				apply_force(total_force, ray.global_position - global_position)
				
				# 2. Steering & Grip
				var wheel_basis = ray.global_basis
				if i < 2: # Front wheels
					wheel_basis = wheel_basis.rotated(Vector3.UP, steering_input * deg_to_rad(steering_angle))
				
				var forward_dir = wheel_basis.z
				var right_dir = wheel_basis.x
				
				# Acceleration
				if engine_input != 0:
					var accel_force = forward_dir * engine_input * engine_power
					apply_force(accel_force, ray.global_position - global_position)
				
				# Grip (lateral friction)
				var lateral_vel = right_dir.dot(wheel_velocity)
				var grip_force = -right_dir * lateral_vel * grip * mass
				apply_force(grip_force, ray.global_position - global_position)
				
				# Visual wheel update
				wheel.global_position = hit_point + hit_normal * wheel_radius
				# Align cylinder (Y-axis) with lateral axis (X-axis)
				wheel.global_basis = wheel_basis.rotated(wheel_basis.z, PI/2.0)
			else:
				# Wheel in air
				wheel.position.y = -suspension_rest_dist
		else:
			# Wheel in air
			wheel.position.y = -suspension_rest_dist

	# Air control
	if !is_any_wheel_touching():
		var air_torque = Vector3.ZERO
		air_torque.x = Input.get_axis("ui_up", "ui_down") * 10.0
		air_torque.y = Input.get_axis("ui_left", "ui_right") * 10.0
		apply_torque(global_basis * air_torque * mass)

func is_any_wheel_touching() -> bool:
	for ray in raycasts:
		if ray.is_colliding(): return true
	return false
