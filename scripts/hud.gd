extends CanvasLayer

@onready var timer_label = $Control/TimerLabel
@onready var finish_label = $Control/FinishLabel

func _ready():
	var gm = get_node_or_null("/root/GameManager")
	if gm:
		gm.time_updated.connect(_on_time_updated)
		gm.state_changed.connect(_on_state_changed)
	finish_label.hide()

func _on_time_updated(time):
	var gm = get_node_or_null("/root/GameManager")
	if gm:
		timer_label.text = gm.format_time(time)

func _on_state_changed(state):
	var gm = get_node_or_null("/root/GameManager")
	if gm:
		if state == gm.RaceState.FINISHED:
			finish_label.text = "Finished!\nTime: " + gm.format_time(gm.race_time) + "\nBest: " + gm.format_time(gm.best_time)
			finish_label.show()
		elif state == gm.RaceState.PRE_START:
			finish_label.hide()
			timer_label.text = "00:00.000"

func _process(_delta):
	var gm = get_node_or_null("/root/GameManager")
	if not gm: return
	
	# Handle raw keys for specific requirements
	if Input.is_key_label_pressed(KEY_1) and _just_pressed_key(KEY_1):
		gm.toggle_sfx()
		
	if Input.is_key_label_pressed(KEY_T) and _just_pressed_key(KEY_T):
		gm.reset_race()

	if Input.is_action_just_pressed("ui_cancel"):
		get_tree().quit()

var _key_states = {}
func _just_pressed_key(key):
	var cur = Input.is_key_label_pressed(key)
	var prev = _key_states.get(key, false)
	_key_states[key] = cur
	return cur and not prev
