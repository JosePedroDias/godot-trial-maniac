extends SceneTree

func _init():
	var root = Node3D.new()
	root.name = "Track1"
	
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
	
	var track_node = Node3D.new()
	track_node.name = "Track"
	root.add_child(track_node)
	track_node.owner = root
	
	# Place some blocks manually to show it works
	var straight_scene = load("res://scenes/blocks/RoadStraight.tscn")
	var start_scene = load("res://scenes/blocks/RoadStart.tscn")
	var finish_scene = load("res://scenes/blocks/RoadFinish.tscn")
	var booster_scene = load("res://scenes/blocks/RoadBooster.tscn")
	
	var blocks = [
		{"scene": straight_scene, "pos": Vector3(-4, 0, 0)},
		{"scene": start_scene, "pos": Vector3(-2, 0, 0)},
		{"scene": straight_scene, "pos": Vector3(0, 0, 0)},
		{"scene": booster_scene, "pos": Vector3(2, 0, 0)},
		{"scene": straight_scene, "pos": Vector3(4, 0, 0)},
		{"scene": finish_scene, "pos": Vector3(6, 0, 0)},
	]
	
	for b in blocks:
		var instance = b.scene.instantiate()
		instance.position = b.pos
		track_node.add_child(instance)
		instance.owner = root
	
	# Add the car
	var car_scene = load("res://scenes/car.tscn")
	var car = car_scene.instantiate()
	car.name = "Car"
	car.position = Vector3(-4, 1, 0)
	car.rotation_degrees = Vector3(0, 90, 0)
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
	ResourceSaver.save(packed_scene, "res://scenes/track1.tscn")
	print("Successfully created res://scenes/track1.tscn")
	
	quit()
