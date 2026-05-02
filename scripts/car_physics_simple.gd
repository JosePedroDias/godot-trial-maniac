extends "res://scripts/car_physics_base.gd"

var engine_power: float
var brake_force: float
var max_speed: float
var reverse_force: float
var steering_angle: float
var grip: float
var suspension_rest_dist: float
var spring_strength: float
var spring_damping: float
var wheel_radius: float
var aero_downforce: float

func apply_physics(delta: float):
	# Simplified model: center-based forces
	var ray_hits = 0
	for ray in car._raycasts:
		if ray.is_colliding(): ray_hits += 1
	car.is_on_ground = ray_hits > 0
	car.on_ground = car.is_on_ground
	
	if car.is_on_ground:
		var speed_kmh = car.linear_velocity.length() * 3.6
		var forward_v = car.global_basis.z.dot(car.linear_velocity)
		
		# Linear Acceleration
		if car.throttle_input > 0 and speed_kmh < max_speed:
			car.apply_central_force(car.global_basis.z * car.throttle_input * engine_power)
		
		# Linear Steering
		if abs(forward_v) > 1.0:
			# Use a mass-scaled torque that is strong enough to rotate the car
			var steer_torque = car.steering_input * car.mass * 50.0
			car.apply_torque(car.global_basis.y * steer_torque)
		
		# Simple Grip (Stronger to make it feel on rails)
		# We use a very high multiplier for grip in SIMPLE mode
		var lat_v = car.global_basis.x.dot(car.linear_velocity)
		car.apply_central_force(-car.global_basis.x * lat_v * car.mass * 15.0)
		
		if abs(lat_v) > 10.0: car.is_skidding = true

func update_wheels(delta: float, steering_input: float, wheel_rot: float):
	# Just rotate visuals
	for i in range(car._wheels.size()):
		var wheel = car._wheels[i]
		if i < 2:
			wheel.rotation.y = steering_input * deg_to_rad(steering_angle)
		var mesh = wheel.get_child(0) if wheel.get_child_count() > 0 else null
		if mesh:
			mesh.rotation.x = wheel_rot
