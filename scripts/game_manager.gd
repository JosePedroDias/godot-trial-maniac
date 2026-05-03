extends Node

enum RaceState { PRE_START, RACING, FINISHED, BINDING }

var current_state = RaceState.PRE_START
var current_time = 0.0
var race_time = 0.0
var time_diff = 0.0
var best_time = 600.0
var current_track_index = 0
var map_mode = 2 # 0: Off, 1: Full, 2: Small

# Control Config (Defaults)
var steer_left = {"dev": -1, "axis": 0, "sign": -1, "btn": -1, "is_btn": false, "snap": 0.0, "key": KEY_LEFT, "is_kb": true}
var steer_right = {"dev": -1, "axis": 0, "sign": 1, "btn": -1, "is_btn": false, "snap": 0.0, "key": KEY_RIGHT, "is_kb": true}
var throttle = {"dev": -1, "axis": 5, "sign": 1, "btn": -1, "is_btn": false, "snap": 0.0, "key": KEY_UP, "is_kb": true}
var brake = {"dev": -1, "axis": 4, "sign": 1, "btn": -1, "is_btn": false, "snap": 0.0, "key": KEY_DOWN, "is_kb": true}

signal state_changed(new_state)
signal time_updated(new_time)
signal speed_updated(speed)
signal gear_updated(gear)
signal record_updated(record_time)
signal map_mode_changed(new_mode)
signal sfx_toggled(is_enabled)
signal ghost_toggled(is_enabled)
signal binding_step_changed(step_text)

var tracks = [
	"res://scenes/australia_track.tscn",
	"res://scenes/china_track.tscn",
	"res://scenes/japan_track.tscn",
	"res://scenes/usa_miami_track.tscn",
	"res://scenes/canada_track.tscn",
	"res://scenes/monaco_track.tscn",
	"res://scenes/spain_barcelona_track.tscn",
	"res://scenes/austria_track.tscn",
	"res://scenes/great_britain_track.tscn",
	"res://scenes/belgium_track.tscn",
	"res://scenes/hungary_track.tscn",
	"res://scenes/netherlands_track.tscn",
	"res://scenes/italy_monza_track.tscn",
	"res://scenes/spain_madrid_track.tscn",
	"res://scenes/azerbaijan_track.tscn",
	"res://scenes/singapore_track.tscn",
	"res://scenes/usa_cota_track.tscn",
	"res://scenes/mexico_track.tscn",
	"res://scenes/brazil_track.tscn",
	"res://scenes/usa_las_vegas_track.tscn",
	"res://scenes/qatar_track.tscn",
	"res://scenes/abu_dhabi_track.tscn",
]

var highscores = {}
var sfx_enabled: bool = true
var ghost_enabled: bool = true
var telemetry_enabled: bool = false
var current_telemetry: Array = []

var _current_run_ghost = []
var _best_ghost_data = []
var _ghost_actor: Node3D = null
var _last_initialized_scene_path: String = ""
var _initial_car_transform: Transform3D = Transform3D()

var _binding_steps = ["STEER LEFT", "STEER RIGHT", "THROTTLE", "BRAKE"]
var _bind_substate = 0 
var _step_snapshots = {} 
var _substate_timer = 0.0
var _binding_wait_for_release = false

func _exit_tree():
	_current_run_ghost.clear()
	_best_ghost_data.clear()
	if _ghost_actor:
		_ghost_actor.queue_free()

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
	_load_data()
	current_state = RaceState.PRE_START
	
	if "--telemetry" in OS.get_cmdline_args():
		telemetry_enabled = true
		print("TELEMETRY ENABLED")
	
	get_tree().node_added.connect(_on_node_added)
	_init_scene.call_deferred()
	
	var editor = Node.new()
	editor.name = "TrackEditor"
	editor.set_script(load("res://scripts/track_editor.gd"))
	add_child(editor)

func _on_node_added(node):
	if node.get_parent() == get_tree().root and node.name != "GameManager":
		_init_scene.call_deferred()

func _init_scene():
	var scene = get_tree().current_scene
	if not scene: return
	if _last_initialized_scene_path == scene.scene_file_path and scene.scene_file_path != "":
		return
	_last_initialized_scene_path = scene.scene_file_path if scene.scene_file_path else ""

	var scene_path = scene.scene_file_path
	if not scene_path: return

	print("Initializing scene: ", scene.name)
	_replace_car_at_runtime()
	
	var idx = tracks.find(scene_path)
	if idx != -1:
		current_track_index = idx
		best_time = float(highscores.get(scene_path, 600.0))
		_load_ghost(scene_path)
		_setup_ghost_actor()
		get_tree().create_timer(0.1).timeout.connect(_emit_initial_record)
	
	_update_window_title()

func _update_window_title():
	if current_track_index >= tracks.size(): return
	var track_name = tracks[current_track_index].get_file().get_basename()
	DisplayServer.window_set_title("Godot Trial Maniac - " + track_name)

func _input(event):
	if event is InputEventKey and event.pressed and not event.is_echo():
		match event.keycode:
			KEY_ESCAPE: get_tree().quit()
			KEY_R: reset_race()
			KEY_1: _prev_track()
			KEY_2: _next_track()
			KEY_3: _start_binding()
			KEY_4: _toggle_ghost()
			KEY_M: _toggle_map()
			KEY_7: _toggle_map()
			KEY_S: _toggle_sfx()
			KEY_C: _toggle_camera()
			KEY_6: _toggle_camera()
			KEY_0: _toggle_fullscreen()
			KEY_X: _clear_current_record()

func _clear_current_record():
	var scene = get_tree().current_scene
	if not scene: return
	var scene_path = scene.scene_file_path
	if not scene_path: return
	
	best_time = 600.0
	_best_ghost_data = []
	highscores[scene_path] = best_time
	
	# Delete ghost file
	var path = "user://" + scene_path.get_file().get_basename() + ".ghost"
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
	
	_save_data()
	record_updated.emit(best_time)
	_setup_ghost_actor()
	print("Cleared record and ghost for: ", scene_path)

func _physics_process(delta):
	var scene = get_tree().current_scene
	if not scene: return
	var car = scene.get_node_or_null("Car")
	if car and (current_state == RaceState.RACING or _is_editor_active()):
		var snapshot = {
			"b": car.global_transform,
			"w": [
				car.get_node("WheelFL").transform,
				car.get_node("WheelFR").transform,
				car.get_node("WheelRL").transform,
				car.get_node("WheelRR").transform
			],
			"a": [
				car.current_rpm,
				abs(car.engine_input),
				car.is_skidding and car.on_ground,
				car.is_braking and car.on_ground
			]
		}
		_current_run_ghost.append(snapshot)
		
		# Keep buffer manageable during long edit sessions (e.g., 30 seconds at 120fps)
		if _is_editor_active() and _current_run_ghost.size() > 3600:
			_current_run_ghost.remove_at(0)

		if current_state == RaceState.RACING and telemetry_enabled:
			current_telemetry.append({
				"t": current_time,
				"s": car.linear_velocity.length() * 3.6,
				"g": car.current_gear,
				"p": car.global_position,
				"og": car.on_ground,
				"steer": car.steering_input,
				"throttle": car.throttle_input,
				"brake": car.brake_input
			})

func _is_editor_active() -> bool:
	var editor = get_node_or_null("TrackEditor")
	return editor and editor.get("edit_mode")

func get_rewind_transform(seconds_back: float) -> Transform3D:
	if _current_run_ghost.is_empty(): return Transform3D()
	# physics_ticks_per_second is 120
	var frames_back = int(seconds_back * 120)
	var idx = max(0, _current_run_ghost.size() - 1 - frames_back)
	return _current_run_ghost[idx]["b"]

func pop_rewind_frames(seconds: float):
	var frames_to_remove = int(seconds * 120)
	if _current_run_ghost.size() <= frames_to_remove:
		_current_run_ghost.clear()
	else:
		_current_run_ghost.resize(_current_run_ghost.size() - frames_to_remove)

func _process(delta):
	if current_state == RaceState.RACING:
		current_time += delta
		time_updated.emit(current_time)
	if current_state == RaceState.BINDING:
		_process_binding_logic(delta)

func start_race():
	current_state = RaceState.RACING
	current_time = 0.0
	_current_run_ghost.clear()
	current_telemetry.clear()
	state_changed.emit(current_state)
	if _ghost_actor and _ghost_actor.has_method("start_playback"):
		_ghost_actor.start_playback(_best_ghost_data)

func finish_race(is_lap = false):
	race_time = current_time
	time_diff = race_time - best_time
	
	if race_time < best_time:
		best_time = race_time
		highscores[get_tree().current_scene.scene_file_path] = best_time
		_best_ghost_data = _current_run_ghost.duplicate()
		_save_data()
		_save_ghost(get_tree().current_scene.scene_file_path)
		record_updated.emit(best_time)
	
	if is_lap:
		# Restart immediately for next lap
		current_time = 0.0
		_current_run_ghost.clear()
		
		# If we just got our first record, we need to create the ghost actor
		if not _ghost_actor and _best_ghost_data.size() > 0:
			_setup_ghost_actor()
			
		if _ghost_actor and _ghost_actor.has_method("start_playback"):
			_ghost_actor.start_playback(_best_ghost_data)
	else:
		current_state = RaceState.FINISHED
		state_changed.emit(current_state)
		if _ghost_actor: _ghost_actor.stop_playback()
	
	if telemetry_enabled: _save_telemetry()

func format_diff(d):
	var sign_str = "+" if d > 0 else "-"
	var abs_d = abs(d)
	var mins = int(abs_d / 60)
	var secs = int(abs_d) % 60
	var msecs = int((abs_d - int(abs_d)) * 1000)
	if mins > 0:
		return "%s%d:%02d.%03d" % [sign_str, mins, secs, msecs]
	return "%s%d.%03d" % [sign_str, secs, msecs]

func reset_race():
	if telemetry_enabled and current_telemetry.size() > 0:
		_save_telemetry()
	
	var scene = get_tree().current_scene
	if scene:
		var car = scene.get_node_or_null("Car")
		if car and car.has_method("reset_to_start"):
			car.reset_to_start(_initial_car_transform)
		
		if _ghost_actor:
			_ghost_actor.stop_playback()
	
	current_state = RaceState.PRE_START
	current_time = 0.0
	_current_run_ghost.clear()
	current_telemetry.clear()
	state_changed.emit(current_state)
	time_updated.emit(0.0)

func _save_telemetry():
	var f = FileAccess.open("res://gameplay_telemetry.json", FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(current_telemetry))
		print("Telemetry saved.")

func _next_track():
	_last_initialized_scene_path = ""
	current_track_index = (current_track_index + 1) % tracks.size()
	get_tree().change_scene_to_file(tracks[current_track_index])

func _prev_track():
	_last_initialized_scene_path = ""
	current_track_index = (current_track_index - 1 + tracks.size()) % tracks.size()
	get_tree().change_scene_to_file(tracks[current_track_index])

func _toggle_fullscreen():
	var mode = DisplayServer.window_get_mode()
	if mode == DisplayServer.WINDOW_MODE_FULLSCREEN or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)

func _toggle_map():
	map_mode = (map_mode + 1) % 3
	map_mode_changed.emit(map_mode)

func _toggle_sfx():
	sfx_enabled = !sfx_enabled
	sfx_toggled.emit(sfx_enabled)
	_save_data()

func _toggle_ghost():
	ghost_enabled = !ghost_enabled
	ghost_toggled.emit(ghost_enabled)
	if _ghost_actor: _ghost_actor.visible = ghost_enabled
	_save_data()

func _toggle_camera():
	var cam = get_tree().current_scene.find_child("FollowCamera", true, false)
	if cam and cam.has_method("toggle_mode"):
		cam.toggle_mode()
		var mode_name = ["NEAR", "MEDIUM", "FAR", "TRACK VIEW"][cam.mode]
		binding_step_changed.emit("CAM: " + mode_name)
		get_tree().create_timer(1.0).timeout.connect(func(): binding_step_changed.emit(""))

func _replace_car_at_runtime():
	var scene = get_tree().current_scene
	if not scene: return
	var car = scene.get_node_or_null("Car")
	if car:
		_initial_car_transform = car.global_transform
		car.name = "OldCar"
		car.queue_free()
		var f1_car = load("res://scenes/f1_2026_car.tscn").instantiate()
		f1_car.name = "Car"
		scene.add_child(f1_car)
		f1_car.global_transform = _initial_car_transform

func _setup_ghost_actor():
	if _ghost_actor:
		if _ghost_actor.get_parent():
			_ghost_actor.get_parent().remove_child(_ghost_actor)
		_ghost_actor.queue_free()
		_ghost_actor = null
	
	if _best_ghost_data.size() == 0: return
	
	_ghost_actor = load("res://scenes/f1_2026_car.tscn").instantiate()
	_ghost_actor.name = "GhostCar"
	_ghost_actor.set_script(load("res://scripts/ghost_car.gd"))
	_ghost_actor.visible = ghost_enabled
	
	var scene = get_tree().current_scene
	scene.add_child(_ghost_actor)
	
	# Metadata for ghost playback (wheels)
	var wheels = []
	for name in ["WheelFL", "WheelFR", "WheelRL", "WheelRR"]:
		var w = _ghost_actor.get_node_or_null(name)
		if w: wheels.append(w)
	_ghost_actor.set_meta("wheels", wheels)

func _start_binding():
	if current_state == RaceState.BINDING:
		current_state = RaceState.PRE_START
		binding_step_changed.emit("")
	else:
		current_state = RaceState.BINDING
		_bind_substate = 0
		_binding_wait_for_release = true
		binding_step_changed.emit("RELEASE ALL BUTTONS/KEYS...")

func _process_binding_logic(delta):
	if _binding_wait_for_release:
		if _listen_for_input() == null:
			_binding_wait_for_release = false
			binding_step_changed.emit("PRESS ANY KEY/BUTTON FOR: " + _binding_steps[0])
		return

	var step_idx = _bind_substate / 4 
	if step_idx >= _binding_steps.size():
		current_state = RaceState.PRE_START
		binding_step_changed.emit("BINDING COMPLETE")
		_save_data()
		get_tree().create_timer(1.5).timeout.connect(func(): if current_state == RaceState.PRE_START: binding_step_changed.emit(""))
		return
	var sub = _bind_substate % 4
	match sub:
		0: 
			binding_step_changed.emit("BIND " + _binding_steps[step_idx] + ": PRESS KEY/AXIS")
			_bind_substate += 1
		1: 
			var found = _listen_for_input()
			if found:
				_step_snapshots[step_idx] = found
				binding_step_changed.emit("RELEASE...")
				_bind_substate += 1
		2: 
			if not _is_input_active(_step_snapshots[step_idx]):
				_bind_substate += 1
				_substate_timer = 0.5
		3: 
			_substate_timer -= delta
			if _substate_timer <= 0:
				_apply_bind(step_idx, _step_snapshots[step_idx])
				_bind_substate += 1

func _listen_for_input():
	for i in range(512):
		if Input.is_key_pressed(i): return {"is_kb": true, "key": i}
	for d in range(8):
		for b in range(JOY_BUTTON_MAX):
			if Input.is_joy_button_pressed(d, b): return {"dev": d, "btn": b, "is_btn": true}
		for a in range(JOY_AXIS_MAX):
			var v = Input.get_joy_axis(d, a)
			if abs(v) > 0.8: return {"dev": d, "axis": a, "sign": sign(v), "snap": 0.0, "is_btn": false}
	return null

func _is_input_active(data):
	if data.get("is_kb", false): return Input.is_key_pressed(data.key)
	if data.get("is_btn", false): return Input.is_joy_button_pressed(data.dev, data.btn)
	return abs(Input.get_joy_axis(data.dev, data.axis)) > 0.3

func _apply_bind(idx, data):
	match idx:
		0: steer_left = data
		1: steer_right = data
		2: throttle = data
		3: brake = data

func _emit_initial_record():
	record_updated.emit(best_time)

func format_time(t):
	var mins = int(t / 60)
	var secs = int(t) % 60
	var msecs = int((t - int(t)) * 1000)
	return "%02d:%02d.%03d" % [mins, secs, msecs]

func _save_data():
	var f = FileAccess.open("user://save_data.json", FileAccess.WRITE)
	var data = {
		"steer_left": steer_left,
		"steer_right": steer_right,
		"throttle": throttle,
		"brake": brake,
		"highscores": highscores,
		"sfx_enabled": sfx_enabled,
		"ghost_enabled": ghost_enabled
	}
	f.store_string(JSON.stringify(data))

func _load_data():
	if not FileAccess.file_exists("user://save_data.json"): return
	var f = FileAccess.open("user://save_data.json", FileAccess.READ)
	var data = JSON.parse_string(f.get_as_text())
	if data:
		steer_left = data.get("steer_left", steer_left);
		steer_right = data.get("steer_right", steer_right)
		throttle = data.get("throttle", throttle);
		brake = data.get("brake", brake)
		highscores = data.get("highscores", {})
		sfx_enabled = data.get("sfx_enabled", true);
		ghost_enabled = data.get("ghost_enabled", true)

func _save_ghost(scene_path):
	var path = "user://" + scene_path.get_file().get_basename() + ".ghost"
	var f = FileAccess.open(path, FileAccess.WRITE)
	if f: f.store_var(_best_ghost_data)

func _load_ghost(scene_path):
	var path = "user://" + scene_path.get_file().get_basename() + ".ghost"
	if FileAccess.file_exists(path):
		var f = FileAccess.open(path, FileAccess.READ)
		_best_ghost_data = f.get_var()
	else:
		_best_ghost_data = []
