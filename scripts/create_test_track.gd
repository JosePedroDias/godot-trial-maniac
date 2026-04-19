extends SceneTree

func _init():
	var root = Node3D.new()
	root.name = "Main"
	
	var env = WorldEnvironment.new()
	env.name = "WorldEnvironment"
	var sky = Sky.new()
	var sky_mat = PhysicalSkyMaterial.new()
	sky.sky_material = sky_mat
	var env_res = Environment.new()
	env_res.background_mode = Environment.BG_SKY
	env_res.sky = sky
	env_res.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.environment = env_res
	root.add_child(env)
	env.owner = root
	
	var sun = DirectionalLight3D.new()
	sun.name = "Sun"
	sun.transform = Transform3D(Basis(Vector3.RIGHT, deg_to_rad(-45)).rotated(Vector3.UP, deg_to_rad(45)), Vector3.ZERO)
	sun.shadow_enabled = true
	root.add_child(sun)
	sun.owner = root
	
	var gridmap = GridMap.new()
	gridmap.name = "TrackGridMap"
	gridmap.mesh_library = load("res://assets/tracks/track_library.tres")
	gridmap.cell_size = Vector3(2, 0.2, 2) # Adjusted height to match road block
	root.add_child(gridmap)
	gridmap.owner = root
	
	var straight_id = gridmap.mesh_library.find_item_by_name("RoadStraight")
	
	# Create a simple loop
	for x in range(-10, 11):
		gridmap.set_cell_item(Vector3i(x, 0, -10), straight_id)
		gridmap.set_cell_item(Vector3i(x, 0, 10), straight_id)
	for z in range(-10, 11):
		gridmap.set_cell_item(Vector3i(-10, 0, z), straight_id)
		gridmap.set_cell_item(Vector3i(10, 0, z), straight_id)
	
	# Start Line
	var start_scene = load("res://scenes/start_line.tscn")
	var start = start_scene.instantiate()
	start.position = Vector3(0, 0.5, -10)
	start.is_start_line = true
	root.add_child(start)
	start.owner = root
	
	# Finish Line
	var finish_scene = load("res://scenes/finish_line.tscn")
	var finish = finish_scene.instantiate()
	finish.position = Vector3(4, 0.5, -10)
	finish.is_start_line = false
	root.add_child(finish)
	finish.owner = root
	
	# Add the car
	var car_scene = load("res://scenes/car.tscn")
	var car = car_scene.instantiate()
	car.name = "Car"
	car.position = Vector3(-5, 1, -10)
	car.rotation_degrees = Vector3(0, 90, 0) # Face towards +X
	root.add_child(car)
	car.owner = root
	
	# Add the camera
	var camera = Camera3D.new()
	camera.name = "FollowCamera"
	camera.set_script(load("res://scripts/follow_camera.gd"))
	camera.target_path = NodePath("../Car")
	root.add_child(camera)
	camera.owner = root
	
	# Add HUD
	var hud_scene = load("res://scenes/hud.tscn")
	var hud = hud_scene.instantiate()
	root.add_child(hud)
	hud.owner = root
	
	var packed_scene = PackedScene.new()
	packed_scene.pack(root)
	ResourceSaver.save(packed_scene, "res://scenes/main.tscn")
	print("Successfully created complete res://scenes/main.tscn")
	
	quit()
