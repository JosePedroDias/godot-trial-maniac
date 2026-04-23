extends Node

enum RaceState { PRE_START, RACING, FINISHED, BINDING }

var current_state = RaceState.PRE_START
var start_time = 0.0
var race_time = 0.0
var best_time = 0.0
var sfx_enabled = true
var ghost_enabled = true

var tracks = [
	"res://scenes/track_12345.tscn",
	"res://scenes/track_54321.tscn",
	"res://scenes/track_98765.tscn",
	"res://scenes/continuos_track_111.tscn",
	"res://scenes/continuos_track_222.tscn",
	"res://scenes/continuos_track_333.tscn"
]
var current_track_index = 0
var highscores = {} 
const SAVE_PATH = "user://game_data.json"

# Input Assignments v3 - Extended for Keyboard
var steer_left = {"dev": -1, "axis": 0, "sign": -1, "btn": -1, "is_btn": false, "snap": 0.0, "key": KEY_LEFT, "is_kb": true}
var steer_right = {"dev": -1, "axis": 0, "sign": 1, "btn": -1, "is_btn": false, "snap": 0.0, "key": KEY_RIGHT, "is_kb": true}
var throttle = {"dev": -1, "axis": 5, "sign": 1, "btn": -1, "is_btn": false, "snap": 0.0, "key": KEY_UP, "is_kb": true}
var brake = {"dev": -1, "axis": 4, "sign": 1, "btn": -1, "is_btn": false, "snap": 0.0, "key": KEY_DOWN, "is_kb": true}

signal state_changed(new_state)
signal time_updated(new_time)
signal speed_updated(new_speed)
signal record_updated(record_time)
signal sfx_toggled(is_enabled)
signal ghost_toggled(is_enabled)
signal binding_step_changed(step_text)

var _current_run_ghost: Array = []
var _best_ghost_data: Array = []
var _ghost_actor = null

var _binding_step = -1 # -1: Choice (K/J)
var _binding_mode = 0 # 0: Keyboard, 1: Joypad
var _binding_steps = ["STEER LEFT", "STEER RIGHT", "THROTTLE", "BRAKE"]
var _bind_substate = 0 # 0: Prep/Snapshot, 1: Listen, 2: Release, 3: Delay
var _step_snapshots = {} 
var _bound_device = -1
var _bound_idx = -1
var _bound_is_btn = false
var _substate_timer = 0.0
var _key_states = {}

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
	_load_data()
	current_state = RaceState.PRE_START
	# Use call_deferred to ensure the scene tree is fully loaded
	_init_scene.call_deferred()

func _init_scene():
	if get_tree().current_scene:
		_setup_ghost_actor()
		var scene_path = get_tree().current_scene.scene_file_path
		var idx = tracks.find(scene_path)
		if idx != -1:
			current_track_index = idx
			best_time = float(highscores.get(scene_path, 600.0))
			_load_ghost(scene_path)
			get_tree().create_timer(0.1).timeout.connect(_emit_initial_record)
		_update_window_title()

func _update_window_title():
	var scene_path = tracks[current_track_index]
	var track_name = scene_path.get_file().get_basename()
	DisplayServer.window_set_title("Godot Trial Maniac - " + track_name)

func _setup_ghost_actor():
	if _ghost_actor: 
		_ghost_actor.queue_free()
		_ghost_actor = null
		
	var car_scene = load("res://scenes/car.tscn").instantiate()
	_ghost_actor = Node3D.new()
	_ghost_actor.name = "GhostCar"
	_ghost_actor.set_script(load("res://scripts/ghost_car.gd"))
	
	var wheels_to_copy = ["WheelFL", "WheelFR", "WheelRL", "WheelRR"]
	var ghost_wheels = []
	
	for child in car_scene.get_children():
		if child is MeshInstance3D or child is Node3D:
			if not (child is CollisionShape3D or child is RayCast3D):
				var duplicate = child.duplicate()
				_ghost_actor.add_child(duplicate)
				if wheels_to_copy.has(child.name):
					ghost_wheels.append(duplicate)
	
	car_scene.free()
	get_tree().current_scene.add_child(_ghost_actor)
	_ghost_actor.visible = false
	_ghost_actor.set_meta("wheels", ghost_wheels)

func start_race():
	_current_run_ghost.clear()
	if not is_instance_valid(_ghost_actor):
		_setup_ghost_actor()
		_load_ghost(get_tree().current_scene.scene_file_path)
	if _ghost_actor and ghost_enabled:
		_ghost_actor.start_playback(_best_ghost_data)
	var scene_path = get_tree().current_scene.scene_file_path
	best_time = float(highscores.get(scene_path, 600.0))
	record_updated.emit(best_time)
	if current_state != RaceState.RACING:
		current_state = RaceState.RACING
		start_time = Time.get_ticks_msec() / 1000.0
		state_changed.emit(current_state)

func finish_race():
	if current_state == RaceState.RACING:
		current_state = RaceState.FINISHED
		if _ghost_actor: _ghost_actor.is_playing = false
		race_time = (Time.get_ticks_msec() / 1000.0) - start_time
		if race_time < best_time:
			best_time = race_time
			highscores[tracks[current_track_index]] = best_time
			_best_ghost_data = _current_run_ghost.duplicate()
			_save_data()
			_save_ghost(tracks[current_track_index])
			record_updated.emit(best_time)
		state_changed.emit(current_state)
		await get_tree().create_timer(2.0).timeout
		if current_state == RaceState.FINISHED:
			next_track()

func next_track():
	current_track_index = (current_track_index + 1) % tracks.size()
	var next_path = tracks[current_track_index]
	best_time = float(highscores.get(next_path, 600.0))
	current_state = RaceState.PRE_START
	_update_window_title()
	get_tree().change_scene_to_file(next_path)

func reset_race():
	current_state = RaceState.PRE_START
	race_time = 0.0
	state_changed.emit(current_state)
	get_tree().reload_current_scene()

func start_binding():
	current_state = RaceState.BINDING
	_binding_step = -1 # Start with Choice
	_bind_substate = 1
	_substate_timer = 0.0
	state_changed.emit(current_state)
	binding_step_changed.emit("PRESS [K] FOR KEYS OR [J] FOR JOYSTICK")

func _process(delta):
	if current_state == RaceState.RACING:
		race_time = (Time.get_ticks_msec() / 1000.0) - start_time
		time_updated.emit(race_time)
	
	if current_state == RaceState.BINDING:
		_process_binding_logic(delta)
	
	_handle_global_input()

func _physics_process(delta):
	if current_state == RaceState.RACING:
		var car = get_tree().current_scene.get_node_or_null("Car")
		if car:
			var snapshot = {
				"b": car.global_transform,
				"w": [
					car.get_node("WheelFL").transform,
					car.get_node("WheelFR").transform,
					car.get_node("WheelRL").transform,
					car.get_node("WheelRR").transform
				]
			}
			_current_run_ghost.append(snapshot)
	
	_prev_key_states = _key_states.duplicate()

func _process_binding_logic(delta):
	if _binding_step == -1:
		if Input.is_key_pressed(KEY_K):
			_binding_mode = 0
			_binding_step = 0
			_bind_substate = 1
			binding_step_changed.emit(_binding_steps[_binding_step])
		elif Input.is_key_pressed(KEY_J):
			_binding_mode = 1
			_binding_step = 0
			_bind_substate = 0 # Snapshot first for joypad
			binding_step_changed.emit("RELEASE ALL") # Immediate feedback
		return

	_substate_timer -= delta
	match _bind_substate:
		0: # RELEASE ALL / PREP (Joypad only)
			if _is_everything_neutral():
				_take_global_snapshot()
				_bind_substate = 1
				binding_step_changed.emit(_binding_steps[_binding_step])
		1: # LISTEN
			if _binding_mode == 0: # Keyboard
				# Scan for any key press
				for k in range(KEY_A, KEY_YEN): # General range
					if Input.is_key_pressed(k) and k != KEY_K and k != KEY_J:
						_apply_kb_step_data(k)
						_bind_substate = 3
						_substate_timer = 0.5
						binding_step_changed.emit("OK!")
						return
				# Arrow keys etc
				for k in [KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT, KEY_SPACE, KEY_SHIFT, KEY_CTRL, KEY_ALT]:
					if Input.is_key_pressed(k):
						_apply_kb_step_data(k)
						_bind_substate = 3
						_substate_timer = 0.5
						binding_step_changed.emit("OK!")
						return
			else: # Joypad
				for d in Input.get_connected_joypads():
					for a in range(8):
						var snap = _step_snapshots.get(d, {}).get(a, 0.0)
						var diff = Input.get_joy_axis(d, a) - snap
						if abs(diff) > 0.75:
							_apply_joy_step_data({"dev": d, "axis": a, "sign": 1 if diff > 0 else -1, "btn": -1, "is_btn": false, "snap": snap, "is_kb": false})
							_start_release_phase(d, a, false)
							return
					for b in range(16):
						if Input.is_joy_button_pressed(d, b):
							_apply_joy_step_data({"dev": d, "axis": -1, "sign": 1, "btn": b, "is_btn": true, "snap": 0.0, "is_kb": false})
							_start_release_phase(d, b, true)
							return
		2: # RELEASE TARGET (Joypad only)
			var released = false
			if _bound_is_btn:
				if not Input.is_joy_button_pressed(_bound_device, _bound_idx): released = true
			else:
				var snap = _step_snapshots.get(_bound_device, {}).get(_bound_idx, 0.0)
				if abs(Input.get_joy_axis(_bound_device, _bound_idx) - snap) < 0.2: released = true
			if released:
				_bind_substate = 3
				_substate_timer = 0.8
				binding_step_changed.emit("OK!")
		3: # DELAY
			if _substate_timer <= 0:
				_binding_step += 1
				if _binding_step < _binding_steps.size():
					_bind_substate = 0 if _binding_mode == 1 else 1
					binding_step_changed.emit(_binding_steps[_binding_step])
				else: _complete_binding()

func _complete_binding():
	binding_step_changed.emit("SAVED!")
	current_state = RaceState.PRE_START
	_save_data()
	get_tree().create_timer(1.0).timeout.connect(func(): 
		binding_step_changed.emit("")
		state_changed.emit(current_state)
	)

func _take_global_snapshot():
	_step_snapshots.clear()
	for d in Input.get_connected_joypads():
		var axes = {}
		for a in range(8): axes[a] = Input.get_joy_axis(d, a)
		_step_snapshots[d] = axes

func _is_everything_neutral() -> bool:
	for d in Input.get_connected_joypads():
		for a in range(8):
			if abs(Input.get_joy_axis(d, a)) > 0.2: return false
		for b in range(16):
			if Input.is_joy_button_pressed(d, b): return false
	return true

func _start_release_phase(dev, idx, is_btn):
	_bound_device = dev
	_bound_idx = idx
	_bound_is_btn = is_btn
	_bind_substate = 2
	binding_step_changed.emit("RELEASE...")

func _apply_kb_step_data(keycode):
	var data = {"dev": -1, "axis": -1, "sign": 0, "btn": -1, "is_btn": false, "snap": 0.0, "key": keycode, "is_kb": true}
	match _binding_step:
		0: steer_left = data
		1: steer_right = data
		2: throttle = data
		3: brake = data

func _apply_joy_step_data(data):
	match _binding_step:
		0: steer_left = data
		1: steer_right = data
		2: throttle = data
		3: brake = data

func _handle_global_input():
	# Update key states regardless of BINDING state to prevent stuck keys
	_key_states[KEY_1] = Input.is_key_pressed(KEY_1)
	_key_states[KEY_3] = Input.is_key_pressed(KEY_3)
	_key_states[KEY_4] = Input.is_key_pressed(KEY_4)
	_key_states[KEY_0] = Input.is_key_pressed(KEY_0)

	if current_state == RaceState.BINDING:
		if Input.is_key_pressed(KEY_ESCAPE):
			current_state = RaceState.PRE_START
			binding_step_changed.emit("")
			state_changed.emit(current_state)
		return

	if Input.is_action_just_pressed("restart"): reset_race()
	
	if Input.is_key_pressed(KEY_1) and not _get_prev_key_state(KEY_1): toggle_sfx()
	if Input.is_action_just_pressed("next_track"): next_track()
	if Input.is_key_pressed(KEY_3) and not _get_prev_key_state(KEY_3): start_binding()
	if Input.is_key_pressed(KEY_4) and not _get_prev_key_state(KEY_4): toggle_ghost()
	if Input.is_key_pressed(KEY_0) and not _get_prev_key_state(KEY_0): _toggle_fullscreen()
	
	if Input.is_key_pressed(KEY_9) and not _get_prev_key_state(KEY_9): reset_all_data()
	_key_states[KEY_9] = Input.is_key_pressed(KEY_9)
	
	if Input.is_action_just_pressed("ui_cancel"): get_tree().quit()

func reset_all_data():
	highscores.clear()
	for track in tracks:
		highscores[track] = 600.0
		var path = "user://ghost_" + track.get_file().get_basename() + ".res"
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
	
	_best_ghost_data = []
	best_time = 600.0
	_save_data()
	
	if _ghost_actor:
		_ghost_actor.stop_playback()
	
	record_updated.emit(best_time)
	print("ALL DATA RESET")

# Helper to check previous frame state BEFORE it was updated in this frame
var _prev_key_states = {}
func _get_prev_key_state(key) -> bool:
	return _prev_key_states.get(key, false)

func _process_prev_states():
	_prev_key_states = _key_states.duplicate()

# Call this at the end of process or use a custom system
# For simplicity, I'll integrate it into _handle_global_input's end

func toggle_sfx():
	sfx_enabled = !sfx_enabled
	sfx_toggled.emit(sfx_enabled)
	return sfx_enabled

func toggle_ghost():
	ghost_enabled = !ghost_enabled
	if _ghost_actor: _ghost_actor.visible = ghost_enabled and _ghost_actor.is_playing
	ghost_toggled.emit(ghost_enabled)

func _load_ghost(track_path):
	var path = "user://ghost_" + track_path.get_file().get_basename() + ".res"
	if FileAccess.file_exists(path):
		var res = ResourceLoader.load(path)
		if res and res.get("data"):
			_best_ghost_data = res.data
	else:
		_best_ghost_data = []

func _save_ghost(track_path):
	var path = "user://ghost_" + track_path.get_file().get_basename() + ".res"
	var g = GhostResource.new()
	g.data = _best_ghost_data
	ResourceSaver.save(g, path)

func _load_data():
	if FileAccess.file_exists(SAVE_PATH):
		var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
		var json = JSON.new()
		if json.parse(file.get_as_text()) == OK:
			var data = json.data
			if data is Dictionary:
				if data.has("scores"):
					var scores = data.scores
					for k in scores: highscores[k] = float(scores[k])
				if data.has("input_v3"):
					var input = data.input_v3
					steer_left = input.get("steer_left", steer_left)
					steer_right = input.get("steer_right", steer_right)
					throttle = input.get("throttle", throttle)
					brake = input.get("brake", brake)
	for track in tracks:
		if not highscores.has(track): highscores[track] = 600.0

func _save_data():
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	var data = {
		"scores": highscores,
		"input_v3": {
			"steer_left": steer_left,
			"steer_right": steer_right,
			"throttle": throttle,
			"brake": brake
		}
	}
	file.store_string(JSON.stringify(data))

func _toggle_fullscreen():
	var mode = DisplayServer.window_get_mode()
	if mode == DisplayServer.WINDOW_MODE_FULLSCREEN or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)

func format_time(time_seconds: float) -> String:
	var minutes = int(time_seconds / 60)
	var seconds = int(time_seconds) % 60
	var msec = int((time_seconds - int(time_seconds)) * 1000)
	return "%02d:%02d.%03d" % [minutes, seconds, msec]

func _emit_initial_record():
	record_updated.emit(best_time)
