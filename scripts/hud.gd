extends CanvasLayer

@onready var timer_label = $Control/TimerLabel
@onready var finish_label = $Control/FinishLabel
@onready var speed_label = $Control/SpeedLabel
@onready var record_label = $Control/RecordLabel
@onready var binding_label = $Control/BindingLabel

var map_points: Array[Vector2] = []
var map_mode = 0 # 0: Hidden, 1: Full, 2: Zoomed
var car_node: Node3D = null
var current_gear: int = 1
var current_speed: float = 0.0

func _ready():
	if GameManager:
		GameManager.time_updated.connect(_on_time_updated)
		GameManager.state_changed.connect(_on_state_changed)
		GameManager.speed_updated.connect(_on_speed_updated)
		GameManager.gear_updated.connect(_on_gear_updated)
		GameManager.record_updated.connect(_on_record_updated)
		GameManager.binding_step_changed.connect(_on_binding_step_changed)
		GameManager.map_mode_changed.connect(_on_map_mode_changed)
		_on_map_mode_changed(GameManager.map_mode)
	finish_label.hide()
	binding_label.hide()
	
	# Create a dedicated Control for map drawing
	var map_control = Control.new()
	map_control.name = "MapControl"
	map_control.clip_contents = true
	$Control.add_child(map_control)
	map_control.position = Vector2(20, 20)
	map_control.size = Vector2(300, 300)
	map_control.draw.connect(_draw_map.bind(map_control))

func _on_map_mode_changed(new_mode):
	map_mode = new_mode
	if map_mode != 0 and map_points.is_empty():
		_extract_track_points()
	var map_ctrl = $Control.get_node_or_null("MapControl")
	if map_ctrl: map_ctrl.queue_redraw()

func _on_binding_step_changed(step_text):
	if step_text == "":
		binding_label.hide()
	else:
		binding_label.text = step_text
		binding_label.show()

func _on_record_updated(record):
	if not is_inside_tree(): return
	if GameManager:
		var track_name = "UNKNOWN"
		if get_tree().current_scene:
			var scene_path = get_tree().current_scene.scene_file_path
			if scene_path != "":
				track_name = scene_path.get_file().get_basename().replace("_track", "").to_upper().replace("_", " ")
			else:
				track_name = get_tree().current_scene.name.to_upper().replace("_", " ")
		
		record_label.text = "BEST: " + GameManager.format_time(record) + "\n" + track_name

func _on_gear_updated(gear):
	current_gear = gear
	_update_speed_label()

func _on_speed_updated(speed):
	current_speed = speed
	_update_speed_label()

func _update_speed_label():
	speed_label.text = str(int(current_speed)) + " KM/H\nGEAR " + str(current_gear)

func _on_time_updated(time):
	if not is_inside_tree(): return
	if GameManager:
		timer_label.text = GameManager.format_time(time)

func _on_state_changed(state):
	if not is_inside_tree(): return
	if GameManager:
		if state == GameManager.RaceState.FINISHED:
			var is_new_record = GameManager.time_diff < 0
			var record_text = "Finished!"
			if is_new_record:
				record_text = "NEW RECORD! " + GameManager.format_diff(GameManager.time_diff)
			
			finish_label.text = record_text + "\nTime: " + GameManager.format_time(GameManager.race_time) + "\nBest: " + GameManager.format_time(GameManager.best_time)
			finish_label.show()
		elif state == GameManager.RaceState.PRE_START:
			finish_label.hide()
			timer_label.text = "00:00.000"

func _extract_track_points():
	map_points.clear()
	var scene = get_tree().current_scene
	if not scene: return
	var track_node = scene.get_node_or_null("Track")
	if not track_node: return
	
	for child in track_node.get_children():
		if child is MeshInstance3D and child.mesh:
			var mesh = child.mesh
			if mesh is ArrayMesh:
				var arrays = mesh.surface_get_arrays(0)
				var verts = arrays[Mesh.ARRAY_VERTEX]
				
				# Profile size varies (10-12 points). 
				# Instead of picking one index, average the whole profile slice 
				# to get the exact center.
				var slice_size = 10 
				# Heuristic to detect profile size:
				if verts.size() % 11 == 0: slice_size = 11
				elif verts.size() % 12 == 0: slice_size = 12
				elif verts.size() % 9 == 0: slice_size = 9
				
				for i in range(0, verts.size(), slice_size):
					var avg = Vector3.ZERO
					var count = 0
					for j in range(slice_size):
						if i + j < verts.size():
							avg += verts[i + j]
							count += 1
					if count > 0:
						var v = child.global_transform * (avg / count)
						map_points.append(Vector2(v.x, v.z))
	
	if map_points.is_empty():
		for child in track_node.get_children():
			var v = child.global_position
			map_points.append(Vector2(v.x, v.z))

func _draw_map(c: Control):
	if map_mode == 0 or map_points.is_empty(): return
	
	if not is_instance_valid(car_node):
		car_node = get_tree().current_scene.get_node_or_null("Car")
	if not car_node: return
	
	var car_pos = Vector2(car_node.global_position.x, car_node.global_position.z)
	# In this project, +Z is the car's forward direction.
	# Vector2(x, z) angle is atan2(z, x). 
	var car_dir = Vector2(car_node.global_transform.basis.z.x, car_node.global_transform.basis.z.z).angle()
	
	var center = c.size / 2.0
	
	# Draw background
	c.draw_rect(Rect2(Vector2.ZERO, c.size), Color(0, 0, 0, 0.3))
	
	if map_mode == 1: # FULL
		var min_p = map_points[0]
		var max_p = map_points[0]
		for p in map_points:
			min_p.x = min(min_p.x, p.x)
			min_p.y = min(min_p.y, p.y)
			max_p.x = max(max_p.x, p.x)
			max_p.y = max(max_p.y, p.y)
		
		var track_size = max_p - min_p
		var scale_factor = (c.size.x - 20) / max(track_size.x, track_size.y, 1.0)
		
		var to_map = func(p: Vector2):
			var out = (p - min_p) * scale_factor
			out += (c.size - track_size * scale_factor) / 2.0
			return out
			
		for i in range(map_points.size() - 1):
			c.draw_line(to_map.call(map_points[i]), to_map.call(map_points[i+1]), Color.WHITE, 1.5)
		
		_draw_car_triangle(c, to_map.call(car_pos), car_dir, Color.YELLOW)
		
	elif map_mode == 2: # ZOOMED
		var zoom_scale = 0.6
		# We want car to face "Up" (-Y in screen space).
		# In Godot UI, Y+ is down. atan2(0, -1) = -PI/2.
		# Rotation required to map car_dir to -PI/2 is (-PI/2 - car_dir).
		var rotation_angle = -PI/2.0 - car_dir
		
		var to_map_zoomed = func(p: Vector2):
			var rel = p - car_pos
			return rel.rotated(rotation_angle) * zoom_scale + center
		
		for i in range(map_points.size() - 1):
			var p1 = map_points[i]
			var p2 = map_points[i+1]
			if p1.distance_to(car_pos) < 350 or p2.distance_to(car_pos) < 350:
				c.draw_line(to_map_zoomed.call(p1), to_map_zoomed.call(p2), Color.WHITE, 3.0)
		
		_draw_car_triangle(c, center, -PI/2.0, Color.YELLOW)

func _draw_car_triangle(c: Control, pos: Vector2, angle: float, col: Color):
	var size = 6.0
	var p1 = pos + Vector2(cos(angle), sin(angle)) * size * 1.5
	var p2 = pos + Vector2(cos(angle + 2.4), sin(angle + 2.4)) * size
	var p3 = pos + Vector2(cos(angle - 2.4), sin(angle - 2.4)) * size
	c.draw_colored_polygon(PackedVector2Array([p1, p2, p3]), col)

func _process(_delta):
	if map_mode != 0:
		if map_points.is_empty():
			_extract_track_points()
		var map_ctrl = $Control.get_node_or_null("MapControl")
		if map_ctrl: map_ctrl.queue_redraw()
