extends SceneTree

func _init():
	var car = RigidBody3D.new()
	car.name = "Car"
	car.mass = 800.0 
	car.center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	car.center_of_mass = Vector3(0, -0.4, 0) # Lower center of mass
	car.set_script(load("res://scripts/car_controller.gd"))
	
	# Dimensions
	var wheelbase = 3.4
	var track_width = 1.9
	var h_wb = wheelbase / 2.0
	var h_tw = track_width / 2.0
	
	# Set F1 specific physics overrides if desired
	car.set("aero_downforce", 8.0)
	car.set("max_speed", 180.0) # F1 is faster
	
	# Body Mesh
	var body_gen = load("res://scripts/create_f1_2026_mesh.gd").new()
	var body_mesh_inst = MeshInstance3D.new()
	body_mesh_inst.mesh = body_gen.create_mesh()
	body_mesh_inst.name = "F1BodyMesh"
	car.add_child(body_mesh_inst)
	
	# Collision - centered low
	var col = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = Vector3(1.8, 0.4, 4.8)
	col.shape = shape
	col.position = Vector3(0, 0.1, 0)
	car.add_child(col)
	
	# Wheels and Raycasts
	var positions = {
		"FL": Vector3(-h_tw, 0.1, h_wb),
		"FR": Vector3(h_tw, 0.1, h_wb),
		"RL": Vector3(-h_tw, 0.1, -h_wb),
		"RR": Vector3(h_tw, 0.1, -h_wb)
	}
	
	var wheel_mat = StandardMaterial3D.new()
	wheel_mat.albedo_color = Color(0.1, 0.1, 0.1)
	var wheel_mesh = CylinderMesh.new()
	wheel_mesh.top_radius = 0.33 
	wheel_mesh.bottom_radius = 0.33
	wheel_mesh.height = 0.3 
	wheel_mesh.material = wheel_mat
	
	for key in positions:
		var pos = positions[key]
		
		var ray = RayCast3D.new()
		ray.name = "RayCast" + key
		ray.position = pos
		ray.target_position = Vector3(0, -1.0, 0) # Longer raycasts
		car.add_child(ray)
		
		var w_inst = MeshInstance3D.new()
		w_inst.name = "Wheel" + key
		w_inst.mesh = wheel_mesh
		w_inst.position = pos
		w_inst.rotation_degrees = Vector3(0, 0, 90)
		car.add_child(w_inst)

	var scene = PackedScene.new()
	for child in car.get_children():
		child.owner = car
		
	scene.pack(car)
	ResourceSaver.save(scene, "res://scenes/f1_2026_car.tscn")
	print("F1 2026 Car scene REGENERATED with improved stability.")
	quit()
