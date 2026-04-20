extends Node

enum RaceState { PRE_START, RACING, FINISHED, BINDING }

var current_state = RaceState.PRE_START
var start_time = 0.0
var race_time = 0.0
var best_time = 0.0
var sfx_enabled = true

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
signal binding_step_changed(step_text)

var _binding_step = 0
var _binding_steps = ["STEER LEFT", "STEER RIGHT", "THROTTLE", "BRAKE"]

# 0: Wait for Silence, 1: Listen for Motion, 2: Wait for Release
var _bind_substate = 0
var _resting_snapshots = {} 
var _captured_input = null

func start_binding():
	current_state = RaceState.BINDING
	_binding_step = 0
	_bind_substate = 0
	state_changed.emit(current_state)
	print("Binding started. Phase: Wait for Silence")

func _process(delta):
	if current_state == RaceState.RACING:
		race_time = (Time.get_ticks_msec() / 1000.0) - start_time
		time_updated.emit(race_time)
	
	if current_state == RaceState.BINDING:
		_process_binding_machine()
	
	_handle_global_input()

func _process_binding_machine():
	match _bind_substate:
		0: # WAIT FOR TOTAL SILENCE
			binding_step_changed.emit("RELEASE ALL")
			if _is_all_neutral_global():
				_take_resting_snapshot()
				_bind_substate = 1
				binding_step_changed.emit(_binding_steps[_binding_step])
				print("Step ", _binding_step, ": Snapshot taken. Listening...")

		1: # LISTEN FOR MOTION
			var input = _get_active_input()
			if input:
				_apply_step_data(input)
				_captured_input = input
				_bind_substate = 2
				binding_step_changed.emit("RELEASE")
				print("Captured: ", input)

		2: # WAIT FOR RELEASE OF CAPTURED INPUT
			if _is_input_neutral(_captured_input):
				_binding_step += 1
				if _binding_step < _binding_steps.size():
					_bind_substate = 0 # Next step, start with silence check
				else:
					_complete_binding()

func _is_all_neutral_global() -> bool:
	for d in Input.get_connected_joypads():
		for a in range(8):
			if abs(Input.get_joy_axis(d, a)) > 0.2: return false
		for b in range(16):
			if Input.is_joy_button_pressed(d, b): return false
	return true

func _take_resting_snapshot():
	_resting_snapshots.clear()
	for d in Input.get_connected_joypads():
		var axes = {}
		for a in range(8): axes[a] = Input.get_joy_axis(d, a)
		_resting_snapshots[d] = axes

func _get_active_input():
	for d in Input.get_connected_joypads():
		for a in range(8):
			var rest = _resting_snapshots.get(d, {}).get(a, 0.0)
			var cur = Input.get_joy_axis(d, a)
			var diff = cur - rest
			if abs(diff) > 0.7:
				return {
					"dev": d, "axis": a, "sign": 1 if diff > 0 else -1, 
					"btn": -1, "is_btn": false, "snap": rest
				}
		for b in range(16):
			if Input.is_joy_button_pressed(d, b):
				return {"dev": d, "axis": -1, "sign": 1, "btn": b, "is_btn": true, "snap": 0.0}
	return null

func _is_input_neutral(input) -> bool:
	if input.is_btn:
		return not Input.is_joy_button_pressed(input.dev, input.btn)
	else:
		var rest = _resting_snapshots.get(input.dev, {}).get(input.axis, 0.0)
		var cur = Input.get_joy_axis(input.dev, input.axis)
		return abs(cur - rest) < 0.2

func _apply_step_data(data):
	match _binding_step:
		0: steer_left = data
		1: steer_right = data
		2: throttle = data
		3: brake = data

func _complete_binding():
	binding_step_changed.emit("SAVED!")
	current_state = RaceState.PRE_START
	_save_data()
	get_tree().create_timer(1.0).timeout.connect(func(): 
		binding_step_changed.emit("")
		state_changed.emit(current_state)
	)

func _ready():
	_load_data()
	current_state = RaceState.PRE_START
	if get_tree().current_scene:
		var scene_path = get_tree().current_scene.scene_file_path
		var idx = tracks.find(scene_path)
		if idx != -1:
			current_track_index = idx
			best_time = float(highscores.get(scene_path, 600.0))
			get_tree().create_timer(0.1).timeout.connect(_emit_initial_record)

func _emit_initial_record():
	record_updated.emit(best_time)

func start_race():
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
		race_time = (Time.get_ticks_msec() / 1000.0) - start_time
		if race_time < best_time:
			best_time = race_time
			highscores[tracks[current_track_index]] = best_time
			_save_data()
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

func toggle_sfx():
	sfx_enabled = !sfx_enabled
	sfx_toggled.emit(sfx_enabled)
	return sfx_enabled

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
		if not highscores.has(track):
			highscores[track] = 600.0

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
	if Input.is_key_pressed(KEY_0) and not _key_states.get(KEY_0, false): _toggle_fullscreen()
	_key_states[KEY_0] = Input.is_key_pressed(KEY_0)
	if Input.is_action_just_pressed("ui_cancel"): get_tree().quit()

var _key_states = {}

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
