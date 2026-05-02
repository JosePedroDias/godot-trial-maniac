extends SceneTree

func _init():
	print("Setting up robust WorldBoundary ground for testing...")
	var scene = Node3D.new()
	root.add_child(scene)
	
	var ground = StaticBody3D.new()
	scene.add_child(ground)
	var col = CollisionShape3D.new()
	var shape = WorldBoundaryShape3D.new()
	col.shape = shape
	ground.add_child(col)
	
	print("Instantiating F1 Car...")
	var car = load("res://scenes/f1_2026_car.tscn").instantiate()
	car.name = "Car"
	scene.add_child(car)
	
	# Wait for physics
	for i in range(60): await physics_frame
	
	print("Car found: ", car.name)
	car.input_override = true
	car.settle_timer = 0.0
	car.global_position = Vector3(0, 2, 0) 
	car.linear_velocity = Vector3.ZERO
	car.settle_timer = 0.0

	print("Waiting for settling...")
	for j in range(200):
		await physics_frame
		if car.on_ground: break
	
	var telemetry = []
	print("Starting simulation (Acceleration -> Hard Turn at 250kmh)...")
	
	var test_state = "ACCEL"
	
	for i in range(1200): # 20 seconds
		var speed_kmh = car.linear_velocity.length() * 3.6
		
		# Test Logic: Accel to 250, then turn
		if test_state == "ACCEL":
			car.throttle_input = 1.0
			car.brake_input = 0.0
			car.steering_input = 0.0
			if speed_kmh > 250.0:
				test_state = "TURN"
				print("Reached 250kmh at frame ", i, ". Initiating hard turn.")
		elif test_state == "TURN":
			car.throttle_input = 0.5 
			car.brake_input = 0.0
			car.steering_input = 0.5 # Hard left
		
		await physics_frame
		
		var yaw_vel = car.angular_velocity.y
		telemetry.append({
			"f": i, 
			"s": speed_kmh, 
			"y": car.global_position.y, 
			"yaw_v": yaw_vel,
			"state": test_state
		})
		
		if i % 60 == 0:
			print("F", i, ": ", int(speed_kmh), "kmh, YawVel=", snapped(yaw_vel, 0.1), " OG=", car.on_ground)

		if car.global_position.y > 10.0 or car.global_position.y < -5.0:
			print("CAR LOST STABILITY at frame ", i)
			break

	var f = FileAccess.open("res://telemetry_results.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(telemetry))
	print("Telemetry saved.")
	quit()
