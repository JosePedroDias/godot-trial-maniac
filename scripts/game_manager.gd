extends Node

enum RaceState { PRE_START, RACING, FINISHED }

var current_state = RaceState.PRE_START
var start_time = 0.0
var race_time = 0.0
var best_time = 0.0

signal state_changed(new_state)
signal time_updated(new_time)

func _ready():
	start_race()

func start_race():
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

func reset_race():
	current_state = RaceState.PRE_START
	race_time = 0.0
	state_changed.emit(current_state)
	get_tree().reload_current_scene()

func _process(_delta):
	if current_state == RaceState.RACING:
		race_time = (Time.get_ticks_msec() / 1000.0) - start_time
		time_updated.emit(race_time)

func format_time(time_seconds: float) -> String:
	var minutes = int(time_seconds / 60)
	var seconds = int(time_seconds) % 60
	var msec = int((time_seconds - int(time_seconds)) * 1000)
	return "%02d:%02d.%03d" % [minutes, seconds, msec]
