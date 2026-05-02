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
	var avg_dist = 0.0
	var avg_normal = Vector3.ZERO
	for ray in car._raycasts:
		if ray.is_colliding():
			ray_hits += 1
			avg_dist += (ray.global_position - ray.get_collision_point()).length()
			avg_normal += ray.get_collision_normal()
	
	car.is_on_ground = ray_hits > 0
	car.on_ground = car.is_on_ground
	
	if car.is_on_ground:
		avg_dist /= ray_hits
		avg_normal = avg_normal.normalized()
		var speed_kmh = car.linear_velocity.length() * 3.6
		var forward_v = car.global_basis.z.dot(car.linear_velocity)
		
		# 0. Simple Suspension
		var error = suspension_rest_dist - avg_dist
		if error > 0:
			var spring_f = error * spring_strength
			var upward_v = car.linear_velocity.dot(car.global_basis.y)
			var damping_f = upward_v * spring_damping
			car.apply_central_force(car.global_basis.y * (spring_f - damping_f) * car.mass)
		
		# 1. Alignment (Keep car upright relative to track normal)
		var curr_up = car.global_basis.y
		var tilt_axis = curr_up.cross(avg_normal)
		var tilt_angle = curr_up.angle_to(avg_normal)
		if tilt_angle > 0.01:
			car.apply_torque(tilt_axis * tilt_angle * car.mass * 2.0)
		
		# 2. Linear Acceleration
		if car.throttle_input > 0 and speed_kmh < max_speed:
			car.apply_central_force(car.global_basis.z * car.throttle_input * engine_power)
		
		# 3. Linear Steering & Stability
		# Stability: strongly resist rotation that isn't from steering input
		var local_av = car.global_basis.inverse() * car.angular_velocity
		var yaw_resistance = -local_av.y * car.mass * 5.0
		car.apply_torque(car.global_basis.y * yaw_resistance)
		
		if abs(forward_v) > 1.0:
			var steer_torque = car.steering_input * car.mass * 60.0
			car.apply_torque(car.global_basis.y * steer_torque)
		
		# 4. Simple Grip
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
