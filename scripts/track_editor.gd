extends Node

const TrackFromJson = preload("res://scripts/track_from_json.gd")

var points_data: Array = []
var json_path: String = ""
var track_root: Node
var road_mesh: MeshInstance3D
var indicators: Node3D

var selected_index: int = -1
var influence_range: int = 4
var edit_mode: bool = false
var _cooldown: float = 0.0

func _ready():
	# Connect to tree signal to detect scene changes
	get_tree().node_added.connect(_on_node_added)
	_refresh_from_scene()

func _on_node_added(node):
	if node.get_parent() == get_tree().root and node.name != "GameManager":
		_refresh_from_scene.call_deferred()

func _refresh_from_scene():
	track_root = get_tree().current_scene
	if not track_root: return
	
	if not track_root.has_meta("points_data"):
		# Smart Search: Try to find JSON by scene name
		var guess_name = track_root.name.to_lower().replace("_track", "")
		var guess_path = "res://assets/tracks/%s_processed.json" % guess_name
		
		if FileAccess.file_exists(guess_path):
			print("Editor: Metadata missing, but found matching JSON at %s. Loading..." % guess_path)
			_load_json_manually(guess_path)
		else:
			if "track" in track_root.name.to_lower():
				print("Editor: Scene '%s' is missing metadata and no JSON found at %s." % [track_root.name, guess_path])
			return
	else:
		points_data = track_root.get_meta("points_data")
		json_path = track_root.get_meta("json_path", "")
	
	road_mesh = track_root.find_child("RoadMesh", true, false)
	_setup_indicators()
	selected_index = -1
	print("Editor: SUCCESSFULLY synced to '%s'. Press Ctrl+E to edit." % track_root.name)

func _load_json_manually(path: String):
	var file = FileAccess.open(path, FileAccess.READ)
	if not file: return
	
	var data = JSON.parse_string(file.get_as_text())
	if not data: return
	
	json_path = path
	points_data = data.get("points", [])
	
	# Apply the same coordinate fixes as the loader
	for p in points_data:
		p.x = -p.x
		p.tx = -p.tx
		
	# Handle reverse/offset if present in JSON
	if data.get("reverseDirection", false):
		points_data.reverse()
		for p in points_data:
			p.tx = -p.tx; p.ty = -p.ty; p.tz = -p.tz

	var start_ratio = data.get("startPositionRatio", 0.0)
	if start_ratio != 0.0:
		var n = points_data.size()
		var offset = int(round(start_ratio * n)) % n
		if offset > 0:
			points_data = points_data.slice(offset) + points_data.slice(0, offset)
		elif offset < 0:
			points_data = points_data.slice(n + offset) + points_data.slice(0, n + offset)
	
	# Store it so we don't have to reload again
	track_root.set_meta("json_path", json_path)
	track_root.set_meta("points_data", points_data)

func _setup_indicators():
	if indicators:
		indicators.queue_free()
	
	indicators = Node3D.new()
	indicators.name = "EditorIndicators"
	add_child(indicators)
	
	# Create a shared mesh for efficiency
	var sphere = SphereMesh.new()
	sphere.radius = 0.3
	sphere.height = 0.6
	
	# Show ALL points for maximum precision
	for i in range(0, points_data.size()):
		var p = points_data[i]
		var mi = MeshInstance3D.new()
		mi.mesh = sphere
		
		var mat = StandardMaterial3D.new()
		mat.albedo_color = Color.GREEN
		mat.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
		mat.no_depth_test = true # See through track
		mi.material_override = mat
		
		mi.position = Vector3(p.x, p.y + 1.5, p.z)
		mi.set_meta("index", i)
		indicators.add_child(mi)
	
	indicators.visible = edit_mode

func _process(delta):
	_cooldown -= delta
	
	if Input.is_key_pressed(KEY_E) and Input.is_key_pressed(KEY_CTRL) and _cooldown <= 0:
		if not track_root or not track_root.has_meta("points_data"):
			_refresh_from_scene()
			if not track_root or not track_root.has_meta("points_data"):
				print("Editor: Current scene is not an editable track.")
				_cooldown = 1.0
				return

		edit_mode = !edit_mode
		_cooldown = 0.5
		if indicators:
			indicators.visible = edit_mode
		print("Edit Mode: ", "ON" if edit_mode else "OFF")
		if not edit_mode:
			# Update metadata in case we want to re-run from current state
			track_root.set_meta("points_data", points_data)

	if not edit_mode or not indicators:
		return

	_update_selection()
	_handle_input(delta)

func _update_selection():
	var car = track_root.get_node_or_null("Car")
	if not car: return
	
	var car_pos = car.global_position
	var min_dist = 1e10
	var new_idx = -1
	
	# Find closest point among ALL points (not just indicators)
	for i in range(points_data.size()):
		var p = points_data[i]
		var d = car_pos.distance_to(Vector3(p.x, p.y, p.z))
		if d < min_dist:
			min_dist = d
			new_idx = i
			
	if new_idx != selected_index:
		selected_index = new_idx
		_highlight_indicators(selected_index)

func _highlight_indicators(idx: int):
	if idx < 0: return
	var total = points_data.size()
	for child in indicators.get_children():
		var child_idx = child.get_meta("index", -1)
		
		# Circular distance
		var dist = abs(child_idx - idx)
		if dist > total / 2:
			dist = total - dist
			
		var mat = child.material_override as StandardMaterial3D
		if dist <= influence_range:
			mat.albedo_color = Color.RED
			child.scale = Vector3.ONE * 1.5
		else:
			mat.albedo_color = Color.GREEN
			child.scale = Vector3.ONE

func _handle_input(delta):
	# Adjust influence range
	if Input.is_key_pressed(KEY_BRACKETLEFT) and _cooldown <= 0:
		influence_range = max(1, influence_range - 1)
		_cooldown = 0.1
		_highlight_indicators(selected_index)
		print("Editor: Influence Range = ", influence_range)
	if Input.is_key_pressed(KEY_BRACKETRIGHT) and _cooldown <= 0:
		influence_range = min(200, influence_range + 1)
		_cooldown = 0.1
		_highlight_indicators(selected_index)
		print("Editor: Influence Range = ", influence_range)

	# Average out height
	if Input.is_key_pressed(KEY_V) and _cooldown <= 0:
		_average_out_height(selected_index, influence_range)
		_cooldown = 0.3

	var change = 0.0
	var speed = 5.0 # meters per second
	if Input.is_key_pressed(KEY_PAGEUP): change = speed * delta
	if Input.is_key_pressed(KEY_PAGEDOWN): change = -speed * delta
	
	if change != 0.0:
		if Input.is_key_pressed(KEY_SHIFT):
			_apply_height_change_smooth(selected_index, change)
		else:
			_apply_height_change(selected_index, change)
		_refresh_track()

	if Input.is_key_pressed(KEY_S) and Input.is_key_pressed(KEY_CTRL) and _cooldown <= 0:
		_save_to_json()
		_cooldown = 1.0
	
	if Input.is_key_pressed(KEY_Q) and _cooldown <= 0:
		_rewind_car(2.0)
		_cooldown = 0.5

func _rewind_car(seconds: float):
	if not GameManager: return
	var target_tr = GameManager.get_rewind_transform(seconds)
	var car = track_root.get_node_or_null("Car")
	if car and car.has_method("reset_to_start"):
		car.reset_to_start(target_tr)
		GameManager.pop_rewind_frames(seconds)
		print("Editor: Rewound car by %.1f seconds and truncated history" % seconds)

func _average_out_height(idx: int, radius: int):
	if idx < 0: return
	var n = points_data.size()
	
	var start_idx = (idx - radius + n) % n
	var end_idx = (idx + radius + n) % n
	
	var start_y = points_data[start_idx].y
	var end_y = points_data[end_idx].y
	
	var total_steps = radius * 2
	for i in range(total_steps + 1):
		var target_idx = (start_idx + i) % n
		var t = float(i) / float(total_steps)
		points_data[target_idx].y = lerp(start_y, end_y, t)
	
	_refresh_track()
	
	# Bump car up to avoid clipping
	var car = track_root.get_node_or_null("Car")
	if car:
		car.global_position.y += 1.0
		
	print("Editor: Smoothed %d points via LERP from %.2f to %.2f" % [total_steps + 1, start_y, end_y])

func _apply_height_change(idx: int, amount: float):
	if idx >= 0 and idx < points_data.size():
		points_data[idx].y += amount

func _apply_height_change_smooth(idx: int, amount: float):
	var radius = influence_range
	for i in range(-radius, radius + 1):
		var target_idx = (idx + i + points_data.size()) % points_data.size()
		var falloff = 1.0 - (abs(i) / float(radius))
		# Use a cosine falloff for smoother curves
		falloff = (cos(PI * (1.0 - falloff)) + 1.0) / 2.0
		points_data[target_idx].y += amount * falloff

func _recalculate_tangents():
	var n = points_data.size()
	if n < 2: return
	
	for i in range(n):
		var p_prev = points_data[(i - 1 + n) % n]
		var p_next = points_data[(i + 1) % n]
		
		var v_prev = Vector3(p_prev.x, p_prev.y, p_prev.z)
		var v_next = Vector3(p_next.x, p_next.y, p_next.z)
		
		var tangent = (v_next - v_prev).normalized()
		
		points_data[i].tx = tangent.x
		points_data[i].ty = tangent.y
		points_data[i].tz = tangent.z

func _refresh_track():
	_recalculate_tangents()
	if not road_mesh: 
		road_mesh = track_root.find_child("RoadMesh", true, false)
		if not road_mesh: return
	
	var new_road_mesh_instance = TrackFromJson.build_track_mesh(points_data)
	var parent = road_mesh.get_parent()
	
	var old_mesh = road_mesh
	parent.add_child(new_road_mesh_instance)
	new_road_mesh_instance.name = "RoadMesh"
	new_road_mesh_instance.owner = track_root
	# Set owner for children (collision, etc)
	for child in new_road_mesh_instance.get_children():
		child.owner = track_root
		for gchild in child.get_children():
			gchild.owner = track_root
			
	road_mesh = new_road_mesh_instance
	old_mesh.queue_free()
	
	# Update indicators positions
	for child in indicators.get_children():
		var child_idx = child.get_meta("index", -1)
		var p = points_data[child_idx]
		child.position = Vector3(p.x, p.y + 1.5, p.z)

func _save_to_json():
	if json_path == "":
		print("Editor: No json_path to save to.")
		return
	
	# Read original file to preserve other fields
	var json_text = FileAccess.get_file_as_string(json_path)
	var data = JSON.parse_string(json_text)
	if not data:
		data = {}
	
	# Reset transformation flags because the saved points are already processed
	data["reverseDirection"] = false
	data["startPositionRatio"] = 0.0
	
	# Update points, flipping coords back
	var saved_points = []
	for p in points_data:
		var sp = p.duplicate()
		sp.x = -sp.x
		sp.tx = -sp.tx
		saved_points.append(sp)
		
	data["points"] = saved_points
	
	var save_file = FileAccess.open(json_path, FileAccess.WRITE)
	if save_file:
		save_file.store_string(JSON.stringify(data, "  "))
		save_file.close()
		print("Editor: SUCCESSFULLY SAVED to ", json_path)
		
		# Generate the .tscn file from the new JSON
		var gen = TrackFromJson.new()
		var output = gen.generate_from_json(json_path)
		if output:
			print("Editor: SUCCESSFULLY REGENERATED track scene: ", output)
		else:
			print("Editor: FAILED TO REGENERATE track scene.")
		gen.queue_free()
	else:
		print("Editor: FAILED TO SAVE to ", json_path)
