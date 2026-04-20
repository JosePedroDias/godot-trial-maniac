extends Node

enum RaceState { PRE_START, RACING, FINISHED, BINDING }

var current_state = RaceState.PRE_START
var start_time = 0.0
var race_time = 0.0
var best_time = 0.0
var sfx_enabled = true
var ghost_enabled = true

var tracks = ["res://scenes/track1.tscn", "res://scenes/track2.tscn"]
var current_track_index = 0
var highscores = {} 
const SAVE_PATH = "user://game_data.json"

# Input Assignments v3
var steer_left = {"dev": -1, "axis": 0, "sign": -1, "btn": -1, "is_btn": false, "snap": 0.0}
var steer_right = {"dev": -1, "axis": 0, "sign": 1, "btn": -1, "is_btn": false, "snap": 0.0}
var throttle = {"dev": -1, "axis": 5, "sign": 1, "btn": -1, "is_btn": false, "snap": 0.0}
var brake = {"dev": -1, "axis": 4, "sign": 1, "btn": -1, "is_btn": false, "snap": 0.0}

signal state_changed(new_state)
signal time_updated(new_time)
signal speed_updated(new_speed)
signal record_updated(record_time)
signal sfx_toggled(is_enabled)
signal ghost_toggled(is_enabled)
signal binding_step_changed(step_text)

var _current_run_ghost: Array[Transform3D] = []
var _best_ghost_data: Array[Transform3D] = []
var _ghost_actor = null

var _binding_step = 0
var _binding_steps = ["STEER LEFT", "STEER RIGHT", "THROTTLE", "BRAKE"]
var _bind_substate = 0 # 0: Prep/Snapshot, 1: Listen, 2: Release, 3: Delay
var _step_snapshots = {} 
var _bound_device = -1
var _bound_idx = -1
var _bound_is_btn = false
var _substate_timer = 0.0
var _key_states = {}

func _ready():
	_load_data()
	current_state = RaceState.PRE_START
	if get_tree().current_scene:
		_setup_ghost_actor()
		var scene_path = get_tree().current_scene.scene_file_path
		var idx = tracks.find(scene_path)
		if idx != -1:
			current_track_index = idx
			best_time = float(highscores.get(scene_path, 600.0))
			_load_ghost(scene_path)
			get_tree().create_timer(0.1).timeout.connect(_emit_initial_record)

func _setup_ghost_actor():
	if _ghost_actor: 
		_ghost_actor.queue_free()
		_ghost_actor = null
		
	var car_scene = load("res://scenes/car.tscn").instantiate()
	_ghost_actor = Node3D.new()
	_ghost_actor.name = "GhostCar"
	_ghost_actor.set_script(load("res://scripts/ghost_car.gd"))
	
	for child in car_scene.get_children():
		if child is MeshInstance3D or child is Node3D:
			if not (child is CollisionShape3D or child is RayCast3D):
				var duplicate = child.duplicate()
				_ghost_actor.add_child(duplicate)
	
	car_scene.free()
	get_tree().current_scene.add_child(_ghost_actor)
	_ghost_actor.visible = false

func start_race():
	_current_run_ghost.clear()
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
	get_tree().change_scene_to_file(next_path)

func reset_race():
	current_state = RaceState.PRE_START
	race_time = 0.0
	state_changed.emit(current_state)
	get_tree().reload_current_scene()

func start_binding():
	current_state = RaceState.BINDING
	_binding_step = 0
	_bind_substate = 0
	_substate_timer = 0.0
	state_changed.emit(current_state)

func _process(delta):
	if current_state == RaceState.RACING:
		race_time = (Time.get_ticks_msec() / 1000.0) - start_time
		time_updated.emit(race_time)
		var car = get_tree().current_scene.get_node_or_null("Car")
		if car:
			_current_run_ghost.append(car.global_transform)
	
	if current_state == RaceState.BINDING:
		_process_binding_logic(delta)
	
	_handle_global_input()

func _process_binding_logic(delta):
	_substate_timer -= delta
	match _bind_substate:
		0: # RELEASE ALL / PREP
			binding_step_changed.emit("RELEASE ALL")
			if _is_everything_neutral():
				_take_global_snapshot()
				_bind_substate = 1
				binding_step_changed.emit(_binding_steps[_binding_step])
		1: # LISTEN
			for d in Input.get_connected_joypads():
				for a in range(8):
					var snap = _step_snapshots.get(d, {}).get(a, 0.0)
					var diff = Input.get_joy_axis(d, a) - snap
					if abs(diff) > 0.75:
						_apply_step_data({"dev": d, "axis": a, "sign": 1 if diff > 0 else -1, "btn": -1, "is_btn": false, "snap": snap})
						_start_release_phase(d, a, false)
						return
				for b in range(16):
					if Input.is_joy_button_pressed(d, b):
						_apply_step_data({"dev": d, "axis": -1, "sign": 1, "btn": b, "is_btn": true, "snap": 0.0})
						_start_release_phase(d, b, true)
						return
		2: # RELEASE TARGET
			binding_step_changed.emit("RELEASE...")
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
				if _binding_step < _binding_steps.size(): _bind_substate = 0
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

func _apply_step_data(data):
	match _binding_step:
		0: steer_left = data
		1: steer_right = data
		2: throttle = data
		3: brake = data

func _handle_global_input():
	if current_state == RaceState.BINDING:
		if Input.is_key_pressed(KEY_ESCAPE):
			current_state = RaceState.PRE_START
			binding_step_changed.emit("")
			state_changed.emit(current_state)
		return

	if Input.is_action_just_pressed("restart"): reset_race()
	if Input.is_key_pressed(KEY_1) and not _key_states.get(KEY_1, false): toggle_sfx()
	_key_states[KEY_1] = Input.is_key_pressed(KEY_1)
	if Input.is_action_just_pressed("next_track"): next_track()
	if Input.is_key_pressed(KEY_3) and not _key_states.get(KEY_3, false): start_binding()
	_key_states[KEY_3] = Input.is_key_pressed(KEY_3)
	if Input.is_key_pressed(KEY_4) and not _key_states.get(KEY_4, false): toggle_ghost()
	_key_states[KEY_4] = Input.is_key_pressed(KEY_4)
	if Input.is_key_pressed(KEY_0) and not _key_states.get(KEY_0, false): _toggle_fullscreen()
	_key_states[KEY_0] = Input.is_key_pressed(KEY_0)
	if Input.is_action_just_pressed("ui_cancel"): get_tree().quit()

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
