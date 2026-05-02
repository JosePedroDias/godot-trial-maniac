extends "res://scripts/car_physics_base.gd"

# We mirror the exports here if we want them to be easily tweakable per strategy
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
	# Pull inputs/state from car
	var throttle_input = car.throttle_input
	var brake_input = car.brake_input
	var steering_input = car.steering_input
	
	# Ground Detection
	var ray_hits = 0
	var avg_normal = Vector3.ZERO
	var avg_dist = 0.0
	
	for ray in car._raycasts:
		if ray.is_colliding():
			ray_hits += 1
			avg_normal += ray.get_collision_normal()
			avg_dist += (ray.global_position - ray.get_collision_point()).length()
	
	car.is_on_ground = ray_hits > 0
	car.on_ground = car.is_on_ground
	
	if car.is_on_ground:
		car.ground_normal = (avg_normal / ray_hits).normalized()
		var target_dist = avg_dist / ray_hits
		
		var speed_cur = car.linear_velocity.length()
		var speed_kmh = speed_cur * 3.6
		var forward_v = car.global_basis.z.dot(car.linear_velocity)
		
		if brake_input > 0.1 and forward_v > 1.0:
			car.is_braking = true
		
		# 1. Suspension
		var error = suspension_rest_dist - target_dist
		var spring_f = error * spring_strength
		var upward_v = car.linear_velocity.dot(car.global_basis.y)
		var damping_f = upward_v * spring_damping
		car.apply_central_force(car.global_basis.y * (spring_f - damping_f) * car.mass)
		
		# 2. Aero Downforce
		car.apply_central_force(-car.global_basis.y * speed_cur * speed_cur * aero_downforce)
		
		# 3. Alignment
		var curr_up = car.global_basis.y
		var tilt_axis = curr_up.cross(car.ground_normal)
		var tilt_angle = curr_up.angle_to(car.ground_normal)
		if tilt_angle > 0.01:
			car.apply_torque(tilt_axis * tilt_angle * 1000.0)
		
		# 4. Acceleration / Braking
		if throttle_input > 0 and speed_kmh < max_speed:
			car.apply_central_force(car.global_basis.z * throttle_input * engine_power)
		
		if brake_input > 0:
			if forward_v > 1.0:
				car.apply_central_force(-car.global_basis.z * brake_input * brake_force)
			else:
				car.apply_central_force(-car.global_basis.z * brake_input * reverse_force)
		
		# 5. Steering & Grip
		var steer_rad = deg_to_rad(steering_angle) * steering_input
		
		for i in range(4):
			var ray = car._raycasts[i]
			if not ray.is_colliding(): continue
			
			var w_basis = car.global_basis
			if i < 2: # Front wheels
				w_basis = w_basis.rotated(car.global_basis.y, steer_rad)
			
			var wheel_pos = ray.global_position - car.global_position
			var v_at_w = car.linear_velocity + car.angular_velocity.cross(wheel_pos)
			
			# Lateral force (Grip)
			var lat_v = w_basis.x.dot(v_at_w)
			car.apply_force(-w_basis.x * lat_v * car.mass * grip * 0.25, wheel_pos)
			
			if i < 2 and abs(lat_v) > 5.0:
				car.is_skidding = true

func update_wheels(delta: float, steering_input: float, wheel_rot: float):
	for i in range(car._wheels.size()):
		var wheel = car._wheels[i]
		var ray = car._raycasts[i]
		
		if i < 2:
			wheel.rotation.y = steering_input * deg_to_rad(steering_angle)
		
		if ray.is_colliding():
			var hit_pt = ray.get_collision_point()
			wheel.global_position = hit_pt + car.ground_normal * wheel_radius
		else:
			wheel.position.y = lerp(wheel.position.y, -suspension_rest_dist, delta * 5.0)
		
		var mesh = wheel.get_child(0) if wheel.get_child_count() > 0 else null
		if mesh:
			mesh.rotation.x = wheel_rot
