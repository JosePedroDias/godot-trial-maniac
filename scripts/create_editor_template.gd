extends SceneTree

func _init():
	var root = Node3D.new()
	root.name = "CustomTrack"
	
	var env = WorldEnvironment.new()
	env.name = "WorldEnvironment"
	var sky = Sky.new()
	var sky_mat = ProceduralSkyMaterial.new()
	sky.sky_material = sky_mat
	var env_res = Environment.new()
	env_res.background_mode = Environment.BG_SKY
	env_res.sky = sky
	env_res.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env_res.tonemap_mode = Environment.TONE_MAPPER_ACES
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
	gridmap.cell_size = Vector3(2, 2, 2)
	gridmap.cell_center_y = false
	root.add_child(gridmap)
	gridmap.owner = root
	
	# Layout one of each block as a palette at Z=5
	var items = gridmap.mesh_library.get_item_list()
	for i in range(items.size()):
		gridmap.set_cell_item(Vector3i(i * 2, 0, 5), items[i])
	
	# Add the car
	var car_scene = load("res://scenes/car.tscn")
	var car = car_scene.instantiate()
	car.name = "Car"
	car.position = Vector3(0, 2, 0)
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
	ResourceSaver.save(packed_scene, "res://scenes/track_editor.tscn")
	print("Successfully created res://scenes/track_editor.tscn")
	
	quit()
