extends Node

const MeshTurtle = preload("res://scripts/mesh_turtle.gd")

const ROAD_WIDTH = 8.0
const ROAD_THICKNESS = 0.4
const WALL_HEIGHT = 0.25
const STEP_LENGTH = 6.0

var centerline_points: Array[Vector3] = []
var rng = RandomNumberGenerator.new()

func generate(seed_val: int = -1, max_steps: int = 100) -> String:
	if seed_val == -1:
		seed_val = Time.get_ticks_msec()
	rng.seed = seed_val
	print("Generating flowing continuous track with seed: ", seed_val)

	centerline_points.clear()

	# Load base track and instantiate
	var base_scene = load("res://scenes/base_track.tscn")
	var track_root = base_scene.instantiate()
	track_root.name = "TrackScene"

	# Prepare MeshTurtle
	var turtle = MeshTurtle.new()
	turtle.set_profile(MeshTurtle.create_road_profile(ROAD_WIDTH, ROAD_THICKNESS, WALL_HEIGHT))
	
	# Prepare Start Area
	var car = track_root.get_node("Car")
	car.owner = track_root
	
	# 1. Place RoadlessStart Block
	var start_scene = load("res://scenes/blocks/RoadlessStart.tscn")
	var start_block = start_scene.instantiate()
	track_root.add_child(start_block)
	start_block.owner = track_root
	start_block.transform = turtle.get_transform()
	
	# 2. Setup Starting forbidden zone
	centerline_points.append(turtle.get_position()) 
	
	# Platform behind start
	turtle.push_state()
	turtle.turn_left(180)
	for i in range(5):
		turtle.move_forward(4.0)
		centerline_points.append(turtle.get_position())
	turtle.pop_state()
	
	# Actually extrude platform
	turtle.push_state()
	turtle.turn_left(180)
	turtle.move_and_extrude(20.0)
	turtle.stop_extrusion() # BREAK CONNECTION here
	turtle.pop_state()
	
	# Position Car on platform (y=1.0 to be safe)
	# Platform is 20m long, extruded from (0,0,0) towards +Z (due to 180 turn)
	# So platform ends at Z=20.
	var car_basis = Basis().rotated(Vector3.UP, PI) # Facing -Z (towards the track)
	car.transform = Transform3D(car_basis, Vector3(0, 1.0, 15.0))
	
	# 3. Main Organic Generation Loop
	var steps_placed = 0
	var attempts = 0
	
	var cur_yaw = 0.0
	var cur_pitch = 0.0
	var cur_roll = 0.0
	
	var tgt_yaw = 0.0
	var tgt_pitch = 0.0
	var tgt_roll = 0.0
	
	var timer = 0
	
	while steps_placed < max_steps and attempts < 2000:
		if timer <= 0:
			# Subtler targets to prevent spiraling
			tgt_yaw = rng.randf_range(-3.5, 3.5)
			if rng.randf() < 0.4: tgt_yaw = 0.0
			
			var h = turtle.get_position().y
			if h < -5.0: tgt_pitch = rng.randf_range(1.0, 2.5)
			elif h > 8.0: tgt_pitch = rng.randf_range(-2.5, -1.0)
			else:
				tgt_pitch = rng.randf_range(-2.0, 2.0)
				if rng.randf() < 0.6: tgt_pitch = 0.0
			
			tgt_roll = rng.randf_range(-3.0, 3.0)
			if rng.randf() < 0.7: tgt_roll = 0.0
			
			timer = rng.randi_range(8, 16)
		
		# Slower, steadier transitions
		cur_yaw = lerp(cur_yaw, tgt_yaw, 0.06)
		cur_pitch = lerp(cur_pitch, tgt_pitch, 0.08)
		cur_roll = lerp(cur_roll, tgt_roll, 0.06)
		
		# RELAXED STRAIGHTENING: Constantly pull towards level/forward (Reduced by 33%)
		cur_yaw = lerp(cur_yaw, 0.0, 0.013)
		cur_pitch = lerp(cur_pitch, 0.0, 0.013)
		cur_roll = lerp(cur_roll, 0.0, 0.033)
		
		# Predict next point
		turtle.push_state()
		turtle.turn_left(cur_yaw)
		turtle.turn_up(cur_pitch)
		turtle.roll(cur_roll)
		turtle.move_forward(STEP_LENGTH)
		var next_p = turtle.get_position()
		var next_basis = turtle.get_transform().basis
		turtle.pop_state()
		
		# Constraints (Tighten to ~25 degrees)
		var too_steep = next_basis.y.dot(Vector3.UP) < 0.90
		
		# Collision
		var collision = false
		if not too_steep:
			for i in range(centerline_points.size()):
				if i > centerline_points.size() - 15: continue
				if next_p.distance_to(centerline_points[i]) < ROAD_WIDTH * 1.8:
					collision = true
					break
		
		if not collision and not too_steep:
			turtle.smooth_step(cur_yaw, cur_pitch, cur_roll, STEP_LENGTH, 6)
			centerline_points.append(turtle.get_position())
			steps_placed += 1
			timer -= 1
			attempts = 0
		else:
			# Recover
			tgt_yaw = -cur_yaw * 1.2
			tgt_pitch = -cur_pitch * 0.5
			tgt_roll = -cur_roll
			timer = 12
			attempts += 1
			
	# 4. Place RoadlessFinish Block
	var finish_scene = load("res://scenes/blocks/RoadlessFinish.tscn")
	var finish_block = finish_scene.instantiate()
	track_root.add_child(finish_block)
	finish_block.owner = track_root
	finish_block.transform = turtle.get_transform()
	
	turtle.move_and_extrude(4.0)
	
	# Commit Mesh
	var mesh = turtle.commit_mesh()
	var mesh_instance = MeshInstance3D.new()
	mesh_instance.mesh = mesh
	mesh_instance.name = "RoadMesh"
	
	var static_body = StaticBody3D.new()
	static_body.name = "StaticBody"
	static_body.set_script(load("res://scripts/track_block.gd"))
	static_body.type = 0 # STRAIGHT
	mesh_instance.add_child(static_body)
	
	var collision_shape = CollisionShape3D.new()
	collision_shape.shape = mesh.create_trimesh_shape()
	static_body.add_child(collision_shape)
	
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.15, 0.15, 0.15)
	mesh_instance.material_override = mat
	
	var track_node = track_root.get_node_or_null("Track")
	if not track_node:
		track_node = Node3D.new()
		track_node.name = "Track"
		track_root.add_child(track_node)
		track_node.owner = track_root
	
	track_node.add_child(mesh_instance)
	mesh_instance.owner = track_root
	static_body.owner = track_root
	collision_shape.owner = track_root

	# Save Scene
	var scene = PackedScene.new()
	scene.pack(track_root)
	var path = "res://scenes/continuos_track_%d.tscn" % seed_val
	ResourceSaver.save(scene, path)
	print("Organic continuous track saved: ", path, " (", steps_placed, " steps)")
	
	track_root.free()
	return path
