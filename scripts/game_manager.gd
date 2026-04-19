extends Node

enum RaceState { PRE_START, RACING, FINISHED }

var current_state = RaceState.PRE_START
var start_time = 0.0
var race_time = 0.0
var best_time = 0.0
var sfx_enabled = true

var tracks = ["res://scenes/track1.tscn", "res://scenes/track2.tscn"]
var current_track_index = 0

signal state_changed(new_state)
signal time_updated(new_time)
signal speed_updated(new_speed)
signal sfx_toggled(is_enabled)

func _ready():
	current_state = RaceState.PRE_START
	# Sync index with current scene
	if get_tree().current_scene:
		var scene_path = get_tree().current_scene.scene_file_path
		var idx = tracks.find(scene_path)
		if idx != -1:
			current_track_index = idx

func start_race():
	if current_state != RaceState.RACING:
		current_state = RaceState.RACING
		start_time = Time.get_ticks_msec() / 1000.0
		state_changed.emit(current_state)

func finish_race():
	if current_state == RaceState.RACING:
		current_state = RaceState.FINISHED
		race_time = (Time.get_ticks_msec() / 1000.0) - start_time
		if best_time == 0.0 or race_time < best_time:
			best_time = race_time
		state_changed.emit(current_state)
		
		# Wait 2 seconds and go to next track
		await get_tree().create_timer(2.0).timeout
		if current_state == RaceState.FINISHED:
			next_track()

func next_track():
	current_track_index = (current_track_index + 1) % tracks.size()
	best_time = 0.0
	current_state = RaceState.PRE_START
	get_tree().change_scene_to_file(tracks[current_track_index])

func reset_race():
	current_state = RaceState.PRE_START
	race_time = 0.0
	state_changed.emit(current_state)
	get_tree().reload_current_scene()

func toggle_sfx():
	sfx_enabled = !sfx_enabled
	sfx_toggled.emit(sfx_enabled)
	return sfx_enabled

func _process(_delta):
	if current_state == RaceState.RACING:
		race_time = (Time.get_ticks_msec() / 1000.0) - start_time
		time_updated.emit(race_time)
	
	_handle_global_input()

func _handle_global_input():
	if Input.is_key_pressed(KEY_T):
		if not _key_states.get(KEY_T, false):
			reset_race()
		_key_states[KEY_T] = true
	else:
		_key_states[KEY_T] = false

	if Input.is_key_pressed(KEY_1):
		if not _key_states.get(KEY_1, false):
			toggle_sfx()
		_key_states[KEY_1] = true
	else:
		_key_states[KEY_1] = false

	if Input.is_key_pressed(KEY_2):
		if not _key_states.get(KEY_2, false):
			next_track()
		_key_states[KEY_2] = true
	else:
		_key_states[KEY_2] = false

	if Input.is_key_pressed(KEY_0):
		if not _key_states.get(KEY_0, false):
			_toggle_fullscreen()
		_key_states[KEY_0] = true
	else:
		_key_states[KEY_0] = false

	if Input.is_key_pressed(KEY_ESCAPE):
		get_tree().quit()

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
