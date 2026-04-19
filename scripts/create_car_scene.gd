extends SceneTree

func _init():
	var car = RigidBody3D.new()
	car.name = "Car"
	car.mass = 1500.0
	car.center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	car.center_of_mass = Vector3(0, -0.2, 0) # Low center of mass for stability
	car.set_script(load("res://scripts/car_controller.gd"))
	
	var body_mesh = MeshInstance3D.new()
	body_mesh.name = "BodyMesh"
	var box = BoxMesh.new()
	box.size = Vector3(1.2, 0.4, 2.5)
	body_mesh.mesh = box
	car.add_child(body_mesh)
	body_mesh.owner = car
	
	var col = CollisionShape3D.new()
	col.name = "CollisionShape3D"
	var shape = BoxShape3D.new()
	shape.size = Vector3(1.2, 0.4, 2.5)
	col.shape = shape
	car.add_child(col)
	col.owner = car
	
	var wheel_mesh = CylinderMesh.new()
	wheel_mesh.top_radius = 0.3
	wheel_mesh.bottom_radius = 0.3
	wheel_mesh.height = 0.2
	
	var positions = {
		"FL": Vector3(-0.7, 0, 1.0),
		"FR": Vector3(0.7, 0, 1.0),
		"RL": Vector3(-0.7, 0, -1.0),
		"RR": Vector3(0.7, 0, -1.0)
	}
	
	for key in positions.keys():
		var pos = positions[key]
		
		var ray = RayCast3D.new()
		ray.name = "RayCast" + key
		ray.position = pos
		car.add_child(ray)
		ray.owner = car
		
		var wheel = MeshInstance3D.new()
		wheel.name = "Wheel" + key
		wheel.mesh = wheel_mesh
		wheel.rotation_degrees = Vector3(0, 0, 90)
		car.add_child(wheel)
		wheel.owner = car
	
	var packed_scene = PackedScene.new()
	packed_scene.pack(car)
	ResourceSaver.save(packed_scene, "res://scenes/car.tscn")
	print("Successfully created res://scenes/car.tscn")
	
	quit()
