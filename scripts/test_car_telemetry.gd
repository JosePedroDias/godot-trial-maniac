extends SceneTree

func _init():
	var args = OS.get_cmdline_args()
	var track_scene_path = "res://scenes/australia_track.tscn"
	
	print("Loading track: ", track_scene_path)
	var scene = load(track_scene_path).instantiate()
	root.add_child(scene)
	
	var car = scene.find_child("Car", true, false)
	if not car:
		# Maybe it's named differently or is a child of a child
		for child in scene.get_children():
			if child.name.contains("Car"):
				car = child
				break
	
	if not car:
		print("Error: Car not found in scene. Scene structure:")
		scene.print_tree_pretty()
		quit()
		return

	var gm = root.get_node("GameManager")
	
	# Override inputs via GameManager to ensure they aren't overwritten in car._physics_process
	var override_input = func(val):
		gm.throttle = {"is_kb": true, "key": KEY_UP} # Mock
		# We can't easily mock Input.is_key_pressed in Godot script easily without low level hacks,
		# but we can modify the car controller to accept an override or just modify the gm values.
		# Let's just set the engine_input AFTER it's calculated in car controller by 
		# running our logic in a script attached to the car or similar.
		pass

	# Wait for a few frames to ensure things are settled
	for j in range(5):
		await physics_frame
	
	# Override inputs
	var telemetry = []
	var sim_frames = 600 # 10 seconds at 60fps
	
	print("Starting simulation (Full Throttle)...")
	car.input_override = true
	
	for i in range(sim_frames):
		# FORCE engine_input every frame. 
		# Since we are running in the same thread, if we do it after physics_frame, 
		# it might be too late for the NEXT frame.
		# Best is to use a signal or just set it and call _physics_process manually 
		# if we want full control, but that's messy.
		
		# Let's use a trick: set engine_input and steering_input
		car.engine_input = 1.0
		car.steering_input = 0.0
		
		# Wait for one physics frame
		await physics_frame
		
		# Capture state
		var speed_kmh = car.linear_velocity.length() * 3.6
		var height = car.global_position.y
		var pitch = car.global_transform.basis.get_euler().x
		var contact_count = 0
		for rc in car.raycasts:
			if rc.is_colliding(): contact_count += 1
		
		telemetry.append({
			"frame": i,
			"speed": speed_kmh,
			"gear": car.current_gear,
			"rpm": car.current_rpm,
			"y": height,
			"pitch": pitch,
			"on_ground": car.on_ground
		})
		
		if i % 60 == 0:
			print("Frame ", i, ": Speed=", int(speed_kmh), " KM/H, Gear=", car.current_gear, " Y=", snapped(height, 0.1))
		
		# If the car is clearly flying away, stop
		if height > 10.0:
			print("CAR LIFTED OFF at frame ", i)
			break

	var f = FileAccess.open("res://telemetry_results.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(telemetry, "  "))
	print("Telemetry saved to telemetry_results.json")
	
	quit()
