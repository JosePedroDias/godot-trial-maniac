extends Node

const MeshTurtle = preload("res://scripts/mesh_turtle.gd")

const ROAD_WIDTH = 16.0
const KERB_WIDTH = 1.8
const GRASS_WIDTH = 10.0

func generate_from_json(json_path: String, car_path: String = "res://scenes/mania_car.tscn") -> String:
	var file = FileAccess.open(json_path, FileAccess.READ)
	if not file:
		print("Error opening file: ", json_path)
		return ""
	
	var json_text = file.get_as_text()
	var data = JSON.parse_string(json_text)
	if not data:
		print("Error parsing JSON: ", json_path)
		return ""
	
	var track_name = data.get("track_name", "custom_track")
	var points_data = data.get("points", [])

	# fix coords
	for p in points_data:
		p.x = -p.x
		p.tx = -p.tx

		#p.z = -p.z
		#p.tz = -p.tz
	
	# Handle optional transformations
	if data.get("reverseDirection", false):
		points_data.reverse()
		# Flip tangents because direction is reversed
		for p in points_data:
			p.tx = -p.tx
			p.ty = -p.ty
			p.tz = -p.tz

	var start_ratio = data.get("startPositionRatio", 0.0)
	if start_ratio != 0.0:
		var n = points_data.size()
		var offset = int(round(start_ratio * n)) % n
		if offset > 0:
			points_data = points_data.slice(offset) + points_data.slice(0, offset)
		elif offset < 0:
			points_data = points_data.slice(n + offset) + points_data.slice(0, n + offset)

	print("Generating F1 track: ", track_name, " with ", points_data.size(), " points")

	# Load base track and instantiate
	var base_scene = load("res://scenes/base_track.tscn")
	var track_root = base_scene.instantiate()
	track_root.name = track_name

	# Replace the car instance with the selected car
	var old_car = track_root.get_node("Car")
	var car_parent = old_car.get_parent()
	
	var selected_car_scene = load(car_path)
	var car = selected_car_scene.instantiate()
	car.name = "Car"
	car_parent.remove_child(old_car)
	old_car.free()
	car_parent.add_child(car)
	car.owner = track_root

	# Update camera target
	var camera = track_root.get_node("FollowCamera")
	if camera:
		camera.target_path = camera.get_path_to(car)

	# Prepare MeshTurtle
	var turtle = MeshTurtle.new()
	var profile_res = MeshTurtle.create_f1_profile(ROAD_WIDTH, KERB_WIDTH, GRASS_WIDTH)
	
	var update_kerb_color = func(dist: float):
		var is_red = int(dist / 1.0) % 2 == 0
		var kerb_col = Color.RED if is_red else Color.WHITE
		var colors = profile_res.colors.duplicate()
		colors[2] = kerb_col
		colors[3] = kerb_col
		colors[6] = kerb_col
		colors[7] = kerb_col
		turtle.set_profile(profile_res.points, colors)

	# 1. Setup Starting Area & Car
	var point_count = points_data.size()
	var get_p = func(idx: int): 
		return points_data[(idx + point_count) % point_count]
	
	# Place a single COMBINED Start/Finish Gate at index 0
	var p0 = points_data[0]
	var gate_pos = Vector3(p0.x, p0.y, p0.z)
	var gate_tangent = Vector3(p0.tx, p0.ty, p0.tz)
	
	var gate_scene = load("res://scenes/blocks/RoadlessStart.tscn")
	var gate_block = gate_scene.instantiate()
	track_root.add_child(gate_block)
	gate_block.owner = track_root
	gate_block.transform = Transform3D(Basis.looking_at(-gate_tangent, Vector3.UP), gate_pos)
	# Set to combined type (13 is START_FINISH in our enum)
	gate_block.type = 13 
	
	# Car Position: ~20m behind gate (Index -4 if 5m spacing)
	var car_idx = -4
	var cp = get_p.call(car_idx)
	var car_pos = Vector3(cp.x, cp.y + 1.0, cp.z)
	var car_tangent = Vector3(cp.tx, cp.ty, cp.tz)
	car.transform = Transform3D(Basis.looking_at(-car_tangent, Vector3.UP), car_pos)

	# 2. Add platform behind gate
	turtle.transform = gate_block.transform
	update_kerb_color.call(0.0)
	turtle.push_state()
	turtle.turn_left(180)
	turtle.move_and_extrude(25.0) # Longer platform to ensure car is covered
	turtle.stop_extrusion()
	turtle.pop_state()
	
	# 3. Main extrusion loop
	var prev_pos = Vector3(points_data[0].x, points_data[0].y, points_data[0].z)
	var total_dist = 0.0
	
	for i in range(points_data.size()):
		var p_data = points_data[i]
		var curr_pos = Vector3(p_data.x, p_data.y, p_data.z)
		var curr_tangent = Vector3(p_data.tx, p_data.ty, p_data.tz)
		
		turtle.transform = Transform3D(Basis.looking_at(-curr_tangent, Vector3.UP), curr_pos)
		var d = curr_pos.distance_to(prev_pos)
		total_dist += d
		turtle._total_dist = total_dist
		
		update_kerb_color.call(total_dist)
		turtle.add_slice()
		prev_pos = curr_pos

	# 4. Close the loop
	var last_p_data = points_data[0]
	turtle.transform = Transform3D(Basis.looking_at(-Vector3(last_p_data.tx, last_p_data.ty, last_p_data.tz), Vector3.UP), Vector3(last_p_data.x, last_p_data.y, last_p_data.z))
	update_kerb_color.call(total_dist + prev_pos.distance_to(Vector3(last_p_data.x, last_p_data.y, last_p_data.z)))
	turtle.add_slice()

	# NEW: Smoothing pass to fix intersections/folds
	turtle.smooth_mesh(3)

	# 5. Commit Mesh and Add to Scene
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
	mat.vertex_color_use_as_albedo = true
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
	var output_path = "res://scenes/%s_track.tscn" % track_name
	ResourceSaver.save(scene, output_path)
	print("Track saved with single Start/Finish: ", output_path)
	
	track_root.free()
	return output_path
